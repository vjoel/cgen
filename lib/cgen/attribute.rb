module CShadow

  AttributeTypes = []

  # This is the base class for all plug-in attribute classes used with the
  # CShadow module. Each subclass provides information which CShadow uses to
  # manage some of the housekeeping for the attribute:
  #
  # * declaration of the attribute in the shadow struct,
  #
  # * accessor code (which CShadow wraps in methods),
  #
  # * type conversion for the write accessor,
  #
  # * type checking for the write accessor,
  #
  # * the 'mark' function, if the attribute refers to Ruby objects,
  #
  # * the 'free' function, if the attribute refers to C data,
  #
  # * initialization (usually, this is left to the class's #initialize method),
  #
  # * serialization methods for the attribute.(*)
  #
  # (*) For Ruby versions before 1.7, requires a patch using the marshal.patch
  # file (the patch is explained in marshal.txt).
  #
  # The subclass hierarchy has two branches: ObjectAttribute and
  # CNativeAttribute. The former is a reference to a Ruby object (in other
  # words, a struct member of type +VALUE+. The latter has subclasses for
  # various C data types, such as +double+ and <tt>char *</tt>.
  #
  # ==Adding new attribute classes
  #
  # Each attribute class must define a class method called 'match' which returns
  # true if the right hand side of the ':name => ...' expression is recognized
  # as defining an attribute of the class. The class should have an initialize
  # method to supply custom code for readers, writers, type checking, memory
  # management, and serialization. (If serialization methods are omitted, the
  # attribute will be ignored during +dump+/+load+.) The easiest way is to
  # follow the examples. For many purposes, most of the work can be done by
  # subclassing existing classes.
  #
  # The +dump+ and +load+ methods require a bit of explanation. Each attribute
  # provides code to dump and load itself in a very generic way. The dump code
  # must operate on a ruby array called result. It must push _one_ piece of ruby
  # data (which may itself be an array, hash, etc.) onto this array. Similarly,
  # the load code operates on a ruby array called from_array. It must shift
  # _one_ piece of ruby data from this array. (Probably it would have been more
  # efficient to use LIFO rather than FIFO. Oh, well.)
  #
  # ==To do:
  #
  # * Type checking and conversion should to to_str, to_ary, etc. first if
  # appropriate.
  #
  # * Consider changing '[Foo]' to 'shadow(Foo)' and using [Foo, Bar, Baz],
  # [Foo]*20, and [Foo .. Foo] to signify structs, fixed-length arrays, and
  # var-length arrays of (VALUE *) ?
  #
  # * More attribute classes: floats, unsigned, fixed length arrays, bitfields,
  # etc.
  #
  # * substructs?
  #
  # * Make classes more generic, so that there aren't so many classes. (Factory
  # classes, like ArrayAttribute(PointerAttribute(:char)) ?)
  #
  # * Support for #freeze, #taint, etc.
  #
  # ==Limitations:
  #
  # * IntAttribute: No attempt to handle Bignums.
  #
  class Attribute

    def Attribute.inherited subclass
      AttributeTypes << subclass
    end
    
    def Attribute.match decl
      false
    end
    
    attr_reader :var, :cvar, :cdecl,
                :init, :reader, :check, :writer,
                :mark, :free, :dump, :load,
                :persists, :owner_class
    
    def initialize owner_class, var, match, persists = true
      @owner_class = owner_class
      @var, @match = var, match
      @persists = persists
    end
    
    def inspect
      %{<#{self.class} #{@cvar} => #{@cdecl.inspect}>}
    end
  end
  
  # There are two kinds of object attributes. Both refer to Ruby objects and can
  # be typed or untyped. This one is less optimized but cat refer to arbitrary
  # ruby objects.
  #
  # The syntax for adding an object attribute to a class is simple. The
  # following code adds three object attributes, one untyped and two typed:
  #
  #   class A
  #     include CShadow
  #     shadow_attr_accessor :obj => Object, :sym => Symbol, :ary => Array
  #   end
  #
  # (See CShadow for variations on #shadow_attr_accessor.)
  #
  # Assignment to +obj+ performs no type checking. Assignment to +sym+ raises a
  # TypeError unless the object assigned is a +Symbol+ or +nil+. Similarly +ary+
  # must always be an +Array+ or +nil+. Type checking always allows +nil+ in
  # addition to the specified type. In each case, the attribute is initialized
  # to +nil+.
  #
  # The referenced Ruby object is marked to protect it from the garbage
  # collector.
  #
  class ObjectAttribute < Attribute
  
    def ObjectAttribute.match decl
      decl if decl.is_a? Class
    end
    
    def target_class; @class; end
    
    def initialize(*args)
      super
      @class = @match
      
      @cvar = @var
      @cdecl = "VALUE #{@cvar}; // #{@class}"
      
      @init = "shadow->#{@cvar} = Qnil" # otherwise, it's Qfalse == 0
      @reader = "result = shadow->#{@cvar}"
      @writer = "shadow->#{@cvar} = arg"
      @check = @class unless @class == Object
      @mark = "rb_gc_mark(shadow->#{@cvar})"
      
      @dump = "rb_ary_push(result, shadow->#{@cvar})"
      @load = "shadow->#{@cvar} = rb_ary_shift(from_array)"
    end
    
    def inspect
      %{<#{self.class} #{@cvar} => #{@class.inspect}>}
    end
  
  end
  
  # There are two kinds of object attributes. Both refer to Ruby objects and can
  # be typed or untyped. This one is a slightly optimized variation that is
  # restricted to references to other shadow objects.
  #
  # ShadowObjectAttribute is a restricted variant of ObjectAttribute in which
  # the object referred to must belong to a class that includes CShadow. The
  # actual pointer is to the shadow struct itself, rather than a +VALUE+. This
  # difference is transparent to Ruby code. The syntax for this variant differs
  # only in the use of brackets around the type. For example, using the class
  # +A+ defined above:
  #
  #   class B
  #     include CShadow
  #     shadow_attr_accessor :a => [A]
  #
  #     def initialize
  #       self.a = A.new
  #       a.sym = :something
  #     end
  #   end
  #
  # Note that a shadow struct always has a +self+ pointer, so a
  # ShadowObjectAttribute contains essentially the same information as an
  # ObjectAttribute. It is included for situation in which the efficiency of a
  # direct reference to the shadow struct is desirable. Note that only
  # ObjectAttributes can refer to general Ruby objects which may or may not
  # include the CShadow module.
  #
  # The accessors work just as with ObjectAttribute, with type checking
  # performed by the writer. From Ruby, these two kinds of attributes are
  # indistinguishable in all respects except their declaration syntax.
  #
  # The referenced Ruby object is marked to protect it from the garbage
  # collector.
  #
  class ShadowObjectAttribute < Attribute

    def ShadowObjectAttribute.match decl
      decl[0] if decl.is_a? Array and decl.size == 1 and decl[0].is_a? Class
    end
    
    def target_class; @class; end
    
    def initialize(*args)
      super
      @class = @match
      
      ssn = @class.shadow_struct.name
      
      @cvar = @var
      if @class < CShadow
        @cdecl = "struct #{ssn} *#{@cvar}"
      else
        raise ScriptError, "Class #{@class} doesn't include CShadow."
      end
      
      @reader = "result = shadow->#{@cvar} ? shadow->#{@cvar}->self : Qnil"
      @writer = %{
        if (arg != Qnil) {
          Data_Get_Struct(arg, #{ssn}, shadow->#{@cvar});
        } else
          shadow->#{@cvar} = 0;
      }
      @check = @class unless @class == Object
      @mark = %{\
        if (shadow->#{@cvar})
          rb_gc_mark(shadow->#{@cvar}->self);\
      }
      
      @dump =
        "rb_ary_push(result, shadow->#{@cvar} ? shadow->#{@cvar}->self : 0)"
      @load = %{
          tmp = rb_ary_shift(from_array);
          if (tmp) {
            Data_Get_Struct(tmp, #{ssn}, shadow->#{@cvar});
          } else
            shadow->#{@cvar} = 0;
      }
    end
    
    def inspect
      %{<#{self.class} #{@cvar} => [#{@class.inspect}]>}
    end
  end

  # CNativeAttribute and its subclasses handle all but the two special cases
  # described above. The general form for declarations of such attributes is:
  #
  #   shadow_attr_accessor ruby_var => c_declaration
  #
  # where +ruby_var+ is the name (symbol or string) which will access the data
  # from Ruby, and +c_declaration+ is the string used to declare the data. For
  # example:
  #
  #   shadow_attr_accessor :x => "double x", :y => "int yyy"
  #
  # Note that the symbol and C identifier need not be the same.
  #
  # Native attributes fall into two categories: those that embed data within the
  # struct, and those that point to a separately allocated block. Embedded
  # attributes are limited in that they are of fixed size. Pointer attributes do
  # not have this limitation. But programmers should be wary of treating them as
  # separate objects: the lifespan of the referenced data block is the same as
  # the lifespan of the Ruby object. If the Ruby object and its shadow are
  # garbage collected while the data is in use, the data will be freed and no
  # longer valid. 
  #
  # When using a separately allocated data block, it is a good practice is to
  # use "copy" semantics, so that there can be no other references to the data.
  # See CharPointerAttribute, for example. Reading or writing to such an
  # attribute has copy semantics, in the following sense. On assignment, the
  # Ruby string argument is copied into an allocated block; later references to
  # this attribute generate a new Ruby string which is a copy of that array of
  # char.
  #
  # Some CNativeAttribute classes are included for int, long, double, double *,
  # char *, etc.
  #
  # Uninitialized numeric members are 0. Accessors for uninitialized strings
  # return +nil+.
  #
  class CNativeAttribute < Attribute
    
    attr_reader :ctype
  
    @pattern = nil
    
    def CNativeAttribute.match decl
      if decl.is_a? String and @pattern and @pattern =~ decl
        Regexp.last_match
      else
        false
      end
    end
    
    def initialize(*args)
      super
      @cdecl = @match[0]
      @ctype = @match[1]
      @cvar = @match[2]
    end
  
  end
  
  class IntAttribute < CNativeAttribute
    @pattern = /\A(int)\s+(\w+)\z/
    def initialize(*args)
      super
      @reader = "result = INT2NUM(shadow->#{@cvar})"
      @writer = "shadow->#{@cvar} = NUM2INT(arg)"   # type check and conversion
      @dump = "rb_ary_push(result, INT2NUM(shadow->#{@cvar}))"
      @load = "tmp = rb_ary_shift(from_array); shadow->#{@cvar} = NUM2INT(tmp)"
    end
  end
  
  # Does not check for overflow.
  class ShortAttribute < IntAttribute
    @pattern = /\A(short)\s+(\w+)\z/
    def initialize(*args)
      super
      @reader = "result = INT2NUM(shadow->#{@cvar})"
      @writer = "shadow->#{@cvar} = NUM2INT(arg)"   # type check and conversion
      @dump = "rb_ary_push(result, INT2NUM(shadow->#{@cvar}))"
      @load = "tmp = rb_ary_shift(from_array); shadow->#{@cvar} = NUM2INT(tmp)"
    end
  end
  
  class LongAttribute < CNativeAttribute
    @pattern = /\A(long)\s+(\w+)\z/
    def initialize(*args)
      super
      @reader = "result = INT2NUM(shadow->#{@cvar})"
      @writer = "shadow->#{@cvar} = NUM2LONG(arg)"   # type check and conversion
      @dump = "rb_ary_push(result, INT2NUM(shadow->#{@cvar}))"
      @load = "tmp = rb_ary_shift(from_array); shadow->#{@cvar} = NUM2LONG(tmp)"
    end
  end
  
  class DoubleAttribute < CNativeAttribute
    @pattern = /\A(double)\s+(\w+)\z/
    def initialize(*args)
      super
      @reader = "result = rb_float_new(shadow->#{@cvar})"
      @writer = "shadow->#{@cvar} = NUM2DBL(arg)"    # type check and conversion
      @dump = "rb_ary_push(result, rb_float_new(shadow->#{@cvar}))"
      @load = "tmp = rb_ary_shift(from_array); shadow->#{@cvar} = NUM2DBL(tmp)"
    end
  end
  
  class PointerAttribute < CNativeAttribute
    @pattern = nil
    def initialize(*args)
      super
      @free = "free(shadow->#{@cvar})"
    end
  end
  
  # Stores a null-terminated string
  class CharPointerAttribute < PointerAttribute
    @pattern = /\A(char)\s*\*\s*(\w+)\z/
    def initialize(*args)
      super
      @reader =
        "result = shadow->#{@cvar} ? rb_str_new2(shadow->#{@cvar}) : Qnil"
      @writer = %{
        {
          int len;
          char *str;
          
          free(shadow->#{@cvar});

          if (arg == Qnil)
            shadow->#{@cvar} = 0;
          else {
            StringValueCStr(arg);
            len = RSTRING(arg)->len;
            str = RSTRING(arg)->ptr;
            shadow->#{@cvar} = ALLOC_N(char, len + 1);

            if (str)
              memcpy(shadow->#{@cvar}, str, len);

            shadow->#{@cvar}[len] = '\\0';
          }
        }
      }
      @dump = %{
        rb_ary_push(result,
          shadow->#{@cvar} ? rb_str_new2(shadow->#{@cvar}) : 0);
      }
      @load = %{
        {
          VALUE arg = rb_ary_shift(from_array);
          int len;
          char *str;
                    
          if (arg == Qnil)
            shadow->#{@cvar} = 0;
          else {
            len = RSTRING(arg)->len;
            str = RSTRING(arg)->ptr;
            shadow->#{@cvar} = ALLOC_N(char, len + 1);

            if (str)
              memcpy(shadow->#{@cvar}, str, len);

            shadow->#{@cvar}[len] = '\\0';
          }
        }
      }
    end
  end
  
  # can be used for variable length arrays--see examples/matrix.rb.
  class DoublePointerAttribute < PointerAttribute
    @pattern = /\A(double)\s*\*\s*(\w+)\z/
    # can't do anything else in general
  end
  
end
