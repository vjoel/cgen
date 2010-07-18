require "cgen/cgen"
require "cgen/attribute"

# == Overview
#
# CShadow is a way of creating objects which transparently mix C data with Ruby
# data.
#
# The CShadow module is a mix-in which adds a C struct to objects which derive
# from the class which includes it. The data members of the C struct, called
# shadow attributes, may vary in subclasses of this base class. Shadow attrs can
# be added to any class inheriting from the base class, and they will propagate
# along the ordinary ruby inheritance hierarchy. (For now, shadow attributes
# cannot be defined in modules.)
#
# The CShadow module uses CGenerator's structure templates to handle the code
# generation. CGenerator is also useful for inline C definitons of methods that
# operate on shadow attributes.
#
# CShadow cooperates with the CShadow::Attribute subclasses defined in
# attribute.rb to handle the mark and free functions, type checking and
# conversion, serialization, and so on. New attribute types can be added easily.
# 
# ==Usage
#
#   class MyClass
#     include CShadow
#     shadow_attr_accessor :x => "int x" # fox example
#   end
#
# Include CShadow in the base class(es) that need to have shadow attributes. The
# base class is assigned a CGenerator::Library, which can be accessed using
# the base class's #shadow_library method. Each subclass of the base class will
# be associated with a struct defined in this library's .h files.
#
# As usual, the #initialize method of the class will be called when the object
# is created, and the arguments are whatever was passed to #new, including the
# block, if any. You can write your own #initialize method to assign initial
# values to the shadow attrs. (Typically, shadow attrs are initialized by
# default to nil or 0. See attribute.rb.)
#
# The file name of the library is the same as the name of the class which
# includes CShadow, by default, and the library directory is generated in the
# current dir when #commit is called. To change the name, or to use a different
# library:
#
#   shadow_library <Library, Class, or String>
#
# The argument can be another library (instance of CShadow::Library), a class
# which includes CShadow, in which case the library of the class is used, or a
# string, in which case a new library is created. Using this feature, several
# base classes (and their descendants) can be kept in the same library. It is
# not possible to split a tree (a base class which includes CShadow and its
# descendants) into more than one library.
#
# Shadow classes that are placed in the same library can still be put in
# separate C source files, using #shadow_library_file:
#
#   shadow_library_file <CFile or String>
#
# This setting is inherited (and can be overridden) by subclasses of the current
# class. If a class calls both #shadow_library and #shadow_library_file then
# they must be called in that order. Note that anything defined before the
# #shadow_library_file statement will not be placed in the specifed file.
#
# The C include and source files for the current class can be accessed with
# #shadow_library_include_file and #shadow_library_source_file. This is not
# required for normal use.
#
# Behavior at commit time can be controlled by scheduling #before_commit and
# #after_commit procs. These procs are called immediately before and after the
# actual commit, which allows, for example, removing instances that would
# otherwise cause an exception, or creating the instance of a singleton class.
# The #before_commit and #after_commit class methods of CShadow delegate to the
# shadow_library's methods. See CGenerator for details.
#
# ===Struct members
#
# All shadow structs have a +self+ member of type +VALUE+ which points to the
# Ruby object.
#
# The subclass struct inherits members of the base class struct.
#
# There are two types of shadow attributes, declared with #shadow_attr
# and friends:
#
# (1) C data::
#
#   :d => "double d", :x => "char *foo"
#
# (2) Ruby value:
#
#   :str => String, :obj => Object
#
# In addition to shadow attributes, you can declare other struct members using
#
#   shadow_struct.declare ...
#
# as in cgen.
#
# For example, the ruby code:
#
####
#
# produces the following struct defs (as well as some functions):
#
# ===Type checking and conversion
#
# In case (1) (C data attribute), assignments to int and double struct members
# are done with +NUM2INT+ and +NUM2DBL+, which convert between numeric types,
# but raise exceptions for unconvertible types. The <tt>char *</tt> case uses
# StringValue (formerly +rb_str2cstr+), which behaves analogously.
#
# In case (2) (Ruby value attribute) the assigned value must always be a
# descendant of the specified type, except that +nil+ is always accepted. The
# purpose of specifying a class (should also allow type predicate!) is to allow
# C code to assume that certain struct members are present in the shadow struct,
# and so it can be safely cast to the "ancestor" struct.
#
# ===Adding methods
#
# CGenerator provides a general interface to the Ruby-C api. However, for
# simplicity, CShadow defines three methods in the client class for defining
# methods and class methods:
#
# CShadow.define_c_method
# CShadow.define_c_class_method
# CShadow.define_c_function
#
# ===Memory management
#
# Each type of attribute is responsible for managing any required marking of
# referenced Ruby objects or freeing of allocated bocks of memory. See Attribute
# and its subclasses for details.
#
# ===C attribute plug-ins
#
# CShadow's #shadow_attr methods check for one (no more, no less) matching
# attribute class. The details of the matching depend on the attribute class.
# See Attribute for details. Additional attribute classes can easily be added
# simply by subclassing CShadow::Attribute.
#
# ===Namespace usage
#
# TODO: prefix every attribute, method, constant name with "cshadow_"?
#
# ===Using CShadow classes with YAML
#
# CShadow classes can serialize via YAML. Both shadow attributes and ordinary
# ruby instance variables are serialized. No additional attribute code is
# needed, because of the generic load/dump mechanism used in cshadow (attributes
# are pushed into or shifted out of an array, which is passed to or from the
# serialization protocol, either Marshal or YAML). The ordering of shadow
# attributes is preserved when dumping to a YAML string.
#
# The only user requirement is that, before attempting to load shadow class
# instances from YAML string, the shadow class types must be registered with
# YAML. This is simple:
#
# CShadow.allow_yaml
#
# This method may be called before or after committing. Calling this method also
# loads the standard yaml library, if it has not already been loaded.
#
# See examples/yaml.rb
#
# ===Common problems and their solutions
#
# Do you get a NameError because accessor methods are not defined? Make sure you
# commit your class.
#
# You assign to an attribute but it doesn't change? Ruby assumes that, in an
# assignment like "x=1", the left hand side is a local variable. For all writer
# methods, whether Ruby or C attributes, you need to do "self.x=1".
#
# ==Notes
#
# * As with most modules, including CShadow more than once has no effect.
# However, CShadow cannot currently be included in another module.
#
# * In addition to the included examples, the RedShift project uses CShadow
# extensively. See http://rubyforge.org/projects/redshift.
#
# ==Limitations:
#
# * Hash args are ordered unpredictably, so if struct member order is
#   significant (for example, because you want to pass the struct to C code that
#   expects it that way), use a separate declare statement for each member.
#   Also, take note of the self pointer at the beginning of the struct.
#
# * Creating a ruby+shadow object has a bit more time/space overhead than just a
#   C object, so CShadow may not be the best mechansism for managing heap
#   allocated data (for example, if you want lots of 2-element arrays). Also,
#   CShadow objects are fixed in size (though their members can point to other
#   structures).
#
# * CShadow attributes are, of course, not dynamic. They are fixed at the time
#   of #commit. Otherwise, they behave essentially like Ruby attributes, except
#   that they can be accessed only with methods or from C code; they cannot be
#   accessed with the @ notation. Of course, the reader and writer for a shadow
#   attribute can be flagged as protected or private. However, a private writer
#   cannot be used, since by definition private methods can only be called in 
#   the receiverless form.
#
# * CShadow is designed for efficient in-memory structs, not packed,
#   network-ordered data as for example in network protocols. See the
#   bit-struct project for the latter.
#
# ==To do:
#
# * It should be easier to get a handle to entities. Below, shadow_attr has been
#   hacked to return a list of pairs of functions. But it should be easier and
#   more general.
#
# * Optimization: if class A<B, and their free func have the same content, use
#   B's function in A, and don't generate a new function for A. Similarly for 
#   all the other kinds of functions.
#
# * Allow
#
#     shadow_attr "int x", "double y"
#
#   or even
#
#     attr_accessor :a, :b, "int x", "double y"
#
#   and (in cgen)
#
#     declare "int x", "double y"
#
#   The ruby name will be extracted from the string using the matching pattern.
#
# * Generate documentation for the shadow class.
#
# * Change name to CStruct? CStructure?
#
# * Find a way to propagate append_features so that CShadow can be included in
#   modules and modules can contribute shadow_attrs.
#
# * option to omit the "self" pointer, or put it at the end of the struct
#   automatically omit it in a class if no ShadowObjectAttributes point to it?
#
# * shadow_struct_constructor class method to use DATA_WRAP_STRUCT
#
# * Use CNativeAttribute as a default attribute? Or use the attr class hierarchy
#   to supply defaults?
#
module CShadow
  SHADOW_SUFFIX = "_Shadow"
  
  class Library < CGenerator::Library
    def initialize(*args)  # :nodoc:
      super
      
      before_commit do
        @classes_to_commit = []
        ObjectSpace.each_object(CShadowClassMethods) do |cl|
          if cl.shadow_library == self
            @classes_to_commit << cl
          end
        end

        # This is done here, rather than in #inherited, to get around
        # the Ruby bug with names of nested classes. It's ugly...
        ## this may be fixed in 1.7
        # Better: register classes with libraries...
        
        classes = Library.sort_class_tree(@classes_to_commit)
        
        classes.each do |cl|
          cl.fill_in_defs
        end
      end

      after_commit do
        for cl in @classes_to_commit
          cl.protect_shadow_attrs
        end
      end
    end
    
    # Sort a list of classes. Sorting has the following properties:
    #
    # Deterministic -- you get the same output no matter what order the input
    # is in, because we're using #sort_by.
    #
    # Compatible with original order on classes: superclass comes before
    # subclass.
    #
    # Unrelated classes are ordered alphabetically by name
    #
    # Note that
    #
    #   classes.sort {|c,d| (d <=> c) || (c.name <=> d.name)}
    #
    # is wrong.
    #
    def self.sort_class_tree(classes)
      classes.sort_by {|c| c.ancestors.reverse!.map!{|d|d.to_s}}
    end
  end
  
  module CShadowClassMethods
    def new # :nodoc:
      raise Library::CommitError,
        "Cannot create shadow objects before committing library"
    end

    # Primarily for loading yaml data. The hash is of the form
    #
    #   { 'attr' => value, ... }
    #
    # where <tt>attr</tt> is either the name of a shadow attr, or
    # the name (without @) of an attribute.
    #
    # Warning: The hash +h+ is modified.
    def new_from_hash(h)
      obj = allocate

      psa = shadow_attrs.select {|attr| attr.persists}
      shadow_vars = psa.map{|attr|attr.var.to_s}
      from_array = h.values_at(*shadow_vars)
      obj._load_data(from_array)
      shadow_vars.each {|v| h.delete(v) }

      h.each do |ivar, value|
        obj.instance_variable_set("@#{ivar}", value)
      end

      obj
    end
    
    # Return the base class, which is the ancestor which first included
    # CShadow.
    def base_class
      @base_class ||= superclass.base_class
    end

    # If +flag+ is +true+, indicate that the class can persist
    # with Marshal and YAML. This is the default. Otherwise
    # if +flag+ is +false+, the entire object will be dumped as +nil+.
    def persistent flag = true
      unless self == base_class
        raise "Persistence must be selected for the base class, " +
              "#{base_class}, and it applies to the tree of subclasses."
      end
      @persistent = flag
    end
    private :persistent

    def persistent?
      bc = @base_class
      if self == bc
        @persistent
      else
        bc.persistent?
      end
    end

    # Generate code and load the dynamically linked library. No further C attrs
    # or methods can be defined after calling #commit.
    def commit
      shadow_library.commit
    end

    # Returns true if and only if the class haas been committed.
    def committed?
      shadow_library.committed?
    end

    # Register +block+ to be called before the #commit happens.
    def before_commit(&block)
      shadow_library.before_commit(&block)
    end

    # Register +block+ to be called after the #commit happens.
    def after_commit(&block)
      shadow_library.after_commit(&block)
    end

    # Each class which includes the CShadow module has this method to
    # iterate over its shadow attributes.
    #
    # Note that the shadow attributes dynamically include inherited ones.
    # (Dynamically in the sense that subsequent changes to superclasses are
    # automatically reflected.) The order is from root to leaf of the
    # inheritance chain, and within each class in order of definition. (TEST
    # THIS)
    def each_shadow_attr(&bl)
      if superclass.respond_to? :each_shadow_attr
        superclass.each_shadow_attr(&bl)
      end
      @shadow_attrs ||= []
      @shadow_attrs.each(&bl)
    end

    # Returns a proxy Enumerable object referring to the same attributes as
    # #each_shadow_attr. For example:
    #
    # sub_class.shadow_attrs.collect { |attr| attr.var }
    #
    # returns an array of variable names for all attributes of the class.
    def shadow_attrs
      proxy = Object.new.extend Enumerable
      shadow_class = self
      proxy.instance_eval {@target = shadow_class}
      def proxy.each(&bl)
        @target.each_shadow_attr(&bl)
      end
      proxy
    end

    # If +lib+ provided and this class doesn't have a library yet,
    # set the library to +lib+..
    #
    # If +lib+ not proivided, and the class has a library, return it.
    # 
    # If +lib+ not proivided, and the class doesn't have a library,
    # construct a library with a reasonable name, and return it.
    # The name is based on the full path of this class.
    # 
    def shadow_library lib = nil
      bc = base_class
      if self == bc
        if defined?(@shadow_library) and @shadow_library
          if lib
            raise RuntimeError,
                  "Class #{name} is already associated" +
                  " with library #{@shadow_library.name}."
          end
        else
          case lib
          when Library
            @shadow_library = lib
          when Class
            begin
              @shadow_library = lib.shadow_library
            rescue NameError
              raise ScriptError, "#{lib} does not include CShadow."
            end
          when String
            @shadow_library = Library.new(lib)
          when nil
            n = name.dup
            n.gsub!(/_/, '__')
            n.gsub!(/::/, '_') # almost reversible
            @shadow_library = Library.new(n)
          else
            raise ArgumentError,
                  "#{lib} is not a CShadow::Library, String, or Class. " +
                  "Its class is #{lib.class}"
          end
        end
        @shadow_library
      else
        bc.shadow_library lib
      end
    end

    # Set or return the shadow library file.
    def shadow_library_file file = nil
      if defined? @shadow_library_file
        if file
          raise RuntimeError,
                "Cannot assign class #{self} to file #{file.inspect}; class" +
                " is already associated" +
                " with file #{@shadow_library_file[0].name}."
        end
        @shadow_library_file
      elsif file
        case file
        when CGenerator::CFile
          file_name = file.name
        when String
          file_name = file
        else
          raise ArgumentError, "#{file} is not a String or CFile."
        end
        file_name = file_name.sub(/\.[ch]$/, "")
        @shadow_library_file = shadow_library.add_file file_name
      else
        if superclass.respond_to? :shadow_library_file
          superclass.shadow_library_file
        else
          [shadow_library.include_file, shadow_library.source_file]
        end
      end
    end

    # Return the main C include file for the library.
    def shadow_library_include_file
      shadow_library_file[0]
    end

    # Return the main C source file for the library.
    def shadow_library_source_file
      shadow_library_file[1]
    end

    #------------------------
    # :section: Defining methods
    # CGenerator provides a general interface to the Ruby-C api. However, for
    # simplicity, CShadow defines three methods in the client class for defining
    # methods and class methods:
    #------------------------

    # The block is evaluated in a context that allows commands for listing
    # arguments, declarations, C body code, etc. See CGenerator for details.
    # See examples in examples/matrix.rb and examples/complex.rb. The +subclass+
    # argument is optional and allows the template to belong to a subclass of
    # the function template it would normally belong to.
    #
    # In the case of #define_c_method, a pointer to the object's shadow struct
    # is available in the C variable +shadow+.
    #
    def define_c_method name, subclass = CGenerator::Method, &block
      sf = shadow_library_source_file
      m = sf.define_c_method self, name, subclass
      m.scope :extern
      m.declare :shadow => "#{shadow_struct_name} *shadow"
      m.setup :shadow =>
        "Data_Get_Struct(self, #{shadow_struct_name}, shadow)"
      m.instance_eval(&block) if block
      m
    end

    # Define a class method for this class.
    def define_c_class_method name,
          subclass = CGenerator::SingletonMethod, &block
      sf = shadow_library_source_file
      m = sf.define_c_singleton_method self, name, subclass
      m.scope :extern
      m.instance_eval(&block) if block
      m
    end
    
    # Define a function in the library of this class. By
    # default, the function has extern scope.
    # The +name+ is just the function name (as a C function).
    def define_c_function name, subclass = CGenerator::Function, &block
      sf = shadow_library_source_file
      m = sf.define_c_function name, subclass
      m.scope :extern
      m.instance_eval(&block) if block
      m
    end
    
    # Define a function in the library of this class. By
    # default, the function has extern scope.
    # The +name+ is typically a symbol (like :mark) which is used to
    # generate a function name in combination with the shadow struct name.
    #
    # If a class defines a function with +name+, and the child class does
    # not do so (i.e. doesn't instantiate the function template to add
    # code), then the child can call the parent's implementation using
    # #refer_to_function (see #new_method for an example).
    def define_inheritable_c_function name,
          subclass = CGenerator::Function, &block
      sf = shadow_library_source_file
      m = sf.define_c_function "#{name}_#{shadow_struct_name}", subclass
      c_function_templates[name] = m
      m.scope :extern
      m.instance_eval(&block) if block
      m
    end
    
    #== Internal methods ==#

    def fill_in_defs
      shadow_struct
      new_method; _alloc_method

      check_inherited_functions

      if self == base_class
        _dump_data_method; _load_data_method
      end
    end

    def c_function_templates; @c_function_templates ||= {}; end
    # Note that {} nondeterministic, so these should only be used to
    # check existence or get value, not to iterate.
    
    def find_super_function sym
      c_function_templates[sym] || (
        defined?(superclass.find_super_function) &&
          superclass.find_super_function(sym))
    end
    
    # Construct the name used for the shadow struct. Attempts to preserve
    # the full class path.
    def shadow_struct_name
      @shadow_struct_name ||=
        name.gsub(/_/, '__').gsub(/::/, '_o_') + CShadow::SHADOW_SUFFIX
    end
    
    # Return the object for managing the shadow struct.
    def shadow_struct
      unless defined?(@shadow_struct) and @shadow_struct
        raise if @inherited_shadow_struct
        sf = shadow_library_source_file
        ssn = shadow_struct_name
        @shadow_struct = sf.declare_extern_struct(ssn)
        if self == base_class
          @shadow_struct.declare :self => "VALUE self"
        else
          sss = superclass.shadow_struct
          shadow_struct.inherit\
            sss.inherit!,
            "/* #{superclass.shadow_struct_name} members */",
            sss.declare!, " "

          unless superclass.shadow_library_source_file ==
                 shadow_library_source_file
            shadow_library_include_file.include(
              superclass.shadow_library_include_file)
          end
        end
      end
      @shadow_struct
    end

    # Return the object for managing the +new+ method of the class.
    def new_method
      unless defined?(@new_method) and @new_method
        sf = shadow_library_source_file
        ssn = shadow_struct_name
        mark_name = refer_to_function :mark
        free_name = refer_to_function :free
        @new_method = sf.define_c_singleton_method self,
          :new, AttrClassMethod
        @new_method.instance_eval {
          scope :extern
          c_array_args
          declare :object => "VALUE object"
          declare :shadow => "#{ssn} *shadow"
          setup :shadow_struct => %{
            object = Data_Make_Struct(self,
                       #{ssn},
                       #{mark_name},
                       #{free_name},
                       shadow);
            shadow->self = object;
          }
          body attr_code!
          body %{
            rb_obj_call_init(object, argc, argv);
          }
          returns "object"
        }
        if superclass.respond_to? :shadow_struct
          @new_method.attr_code superclass.new_method.attr_code!
        end
      end
      @new_method
    end
    
    # Set of function names (symbols) that have been referenced in the
    # implementation of this class. The names are like :free or :mark,
    # rather than :free_in_class_C, to give a common identity to all free
    # functions.
    def referenced_functions
      @referenced_functions ||= {}
    end
    
    # Generate a string which, by convention, names the function for
    # instances of this particular class. Also, keeps track of
    # referenced_functions.
    def refer_to_function sym
      referenced_functions[sym] = true
      "#{sym}_#{shadow_struct_name}"
    end
    
    def inherited_function
      @inherited_function ||= {}
    end
    
    # For each function referenced in this class, but not defined, resolve
    # the reference by defining a macro to evaluate to the first
    # implementation found by ascending the class tree.
    def check_inherited_functions
      syms = referenced_functions.keys.sort_by{|k|k.to_s}
      syms.reject {|sym| c_function_templates[sym]}.each do |sym|
        fname = "#{sym}_#{shadow_struct_name}"
        pf = find_super_function(sym)
        inherited_function[sym] = true
        pf_str = pf ? pf.name : (sym == :free ? -1 : 0)
          # -1 means free the struct; See README.EXT
        shadow_library_source_file.declare fname.intern =>
          "#define #{fname} #{pf_str}"
      end
    end
    
    # Return the object for managing the mark function of the class.
    def mark_function
      unless defined?(@mark_function) and @mark_function
        raise if inherited_function[:mark]
        sf = shadow_library_source_file
        ssn = shadow_struct_name
        @mark_function = define_inheritable_c_function(:mark, MarkFunction) do
          arguments "#{ssn} *shadow"
          return_type "void"
        end
        if superclass.respond_to? :shadow_struct
          @mark_function.mark superclass.mark_function.mark!
        end
      end
      @mark_function
    end

    # Return the object for managing the free function of the class.
    def free_function
      unless defined?(@free_function) and @free_function
        raise if inherited_function[:free]
        sf = shadow_library_source_file
        ssn = shadow_struct_name
        @free_function = define_inheritable_c_function(:free, FreeFunction) do
          arguments "#{ssn} *shadow"
          return_type "void"
        end
        if superclass.respond_to? :shadow_struct
          @free_function.free superclass.free_function.free!
        end
      end
      @free_function
    end

    # Return the object for managing the +_dump_data+ method of the class.
    # See ruby's marshal.c.
    def _dump_data_method
      return nil unless persistent?
      unless defined?(@_dump_data_method) and @_dump_data_method
        @_dump_data_method = define_c_method(:_dump_data, AttrMethod) {
          declare :result   => "VALUE result"
          setup   :result   => "result = rb_ary_new()"
          body pre_code!, attr_code!, post_code!
          returns "result"
        }
        if superclass.respond_to? :shadow_struct
          @_dump_data_method.attr_code superclass._dump_data_method.body!
        end
      end
      @_dump_data_method
    end

    # Return the object for managing the +_load_data+ method of the class.
    # See ruby's marshal.c.
    def _load_data_method
      return nil unless persistent?
      unless defined?(@_load_data_method) and @_load_data_method
        @_load_data_method = define_c_method(:_load_data, AttrMethod) {
          arguments :from_array
          declare :tmp  => "VALUE tmp"
          body pre_code!, attr_code!, post_code!
          returns "from_array"  ## needed?
        }
        if superclass.respond_to? :shadow_struct
          @_load_data_method.attr_code superclass._load_data_method.body!
        end
      end
      @_load_data_method
    end

    # Return the object for managing the +alloc+ method of the class.
    def _alloc_method
      ## same as new_method, but no initialize -- factor this
      ## can we use define_c_class_method?
      return nil unless persistent?
      unless defined?(@_alloc_method) and @_alloc_method
        sf = shadow_library_source_file
        ssn = shadow_struct_name
        mark_name = refer_to_function :mark
        free_name = refer_to_function :free
        @_alloc_method = sf.define_alloc_func(self)
        @_alloc_method.instance_eval {
          scope :extern
          arguments 'VALUE klass'
          return_type 'VALUE'
          klass_c_name = "klass"
          declare :object => "VALUE object"
          declare :shadow => "#{ssn} *shadow"
          body %{
            object = Data_Make_Struct(#{klass_c_name},
                       #{ssn},
                       #{mark_name},
                       #{free_name},
                       shadow);
            shadow->self = object;
          }
          returns "object"
        }
      end
      @_alloc_method
    end

  private
  
    def check_overwrite_shadow_attrs(*symbols)
      for attr in shadow_attrs
        for sym in symbols
          if sym == attr.var
            raise NameError, "#{sym} is a shadow attr."
          end
        end
      end
    end

  public ## 1.9 compatibility (or 1.9 bug?)
    def attr_accessor(*args)
      check_overwrite_shadow_attrs(*args)
      super
    end

    def attr_reader(*args)
      check_overwrite_shadow_attrs(*args)
      super
    end

    def attr_writer(*args)
      check_overwrite_shadow_attrs(*args)
      super
    end
  private ## 1.9 compatibility (or 1.9 bug?)

    # Same as #shadow_attr with the +:reader+ and +:writer+ options.
    def shadow_attr_accessor(*args) # :doc:
      shadow_attr :reader, :writer, *args
    end

    # Same as #shadow_attr with the +:reader+ option.
    def shadow_attr_reader(*args) # :doc:
      shadow_attr :reader, *args
    end

    # Same as #shadow_attr with the +:writer+ option.
    def shadow_attr_writer(*args) # :doc:
      shadow_attr :writer, *args
    end

    # call-seq:
    #   shadow_attr [options,] :var => decl, ...
    #
    # Adds the specified declarations to the shadow struct of the current class
    # without defining any accessors. The data can be accessed only in C code.
    #
    # Each <tt>:var => decl</tt> pair generates one C struct member (<tt>:x =>
    # "int x,y"</tt> will generate an exception).
    #
    # The same symbol :var cannot be used in both a +shadow_attr_*+ definition
    # and an ordinary +attr_*+ definition. (You can always get around this by
    # manually defining accessor methods.)
    #
    # The available options are:
    #
    # +:persistent+, +:nonpersistent+::
    #   Serialize or do not serialize this attribute when dumping with Marshal,
    #   YAML, etc. When loading, it is initialized using the attribute's #init
    #   code (which, typically, sets it to zero or +nil+). Default is
    #   +:persistent+.
    #
    # +:reader+, +:writer+::
    #   Creates a reader or writer method, just like #shadow_attr_reader and
    #   #shadow_attr_writer. (This is mostly for internal use.)
    #
    # Returns list of handles to the attr funcs: [ [r0,w0], [r1,w1], ... ]
    #
    # Typically, #shadow_attr_accessor and so on are called instead.
    #
    def shadow_attr(*args) # :doc:
      attr_persists = true
      for arg in args
        case arg
        when Hash;            var_map = arg.sort_by {|var, decl| var.to_s}
        when :reader;         reader = true
        when :writer;         writer = true
        when :nonpersistent;  attr_persists = false
        when :persistent;     attr_persists = true
        else
          raise SyntaxError,
            "Unrecognized shadow_attr argument: #{arg.inspect}"
        end
      end

      source_file = shadow_library_source_file
      ssn = shadow_struct_name
      @shadow_attrs ||= []
      
      meths = nil

      var_map.map do |var, decl|
        var = var.intern if var.is_a? String
        meths ||= instance_methods(false).map {|sym| sym.to_s} ## 1.9 compat

        if meths.include?(var.to_s) or
           meths.include?(var.to_s + '=')
          raise NameError, "#{var} already has a Ruby attribute."
        end

        matches = AttributeTypes.collect { |t|
           [t, t.match(decl)]
        }.select {|t, match| match}

        if matches.size > 1
          raise StandardError, %{
            No unique AttributeType for '#{decl}':
              each of #{matches.map{|t|t[0]}.join ", "} match.
          }.tabto(0)
        end

        if matches.size < 1
          raise StandardError, "No Attribute type matches '#{decl}'."
        end

        attr_type, match = matches[0]
        attr = attr_type.new self, var, match, attr_persists
        each_shadow_attr { |a|
          if a.var == attr.var or a.cvar == attr.cvar
            unless a.var == attr.var and a.cdecl == attr.cdecl
              raise NameError, "Attribute #{a.inspect} already exists."
            end
          end
        }
        @shadow_attrs << attr

        shadow_struct.declare attr.cvar => attr.cdecl

        new_method.attr_code attr.init if attr.init

        m = attr.mark and mark_function.mark m
        f = attr.free and free_function.free f

        if persistent?
          if attr_persists
            _dump_data_method.attr_code attr.dump
            _load_data_method.attr_code attr.load
          else
            i = attr.init and _load_data_method.attr_code i
          end
        end

        if reader
          unless attr.reader
            raise ScriptError, "Can't have a reader method for #{attr}."
          end
          r_meth = source_file.define_c_method(self, var)
          r_meth.instance_eval {
            scope :extern
            declare :shadow => "#{ssn} *shadow"
            declare :result => "VALUE result"
            body "Data_Get_Struct(self, #{ssn}, shadow)", attr.reader
            returns "result"
          }
        end

        if writer
          unless attr.writer
            raise ScriptError, "Can't have a writer method for #{attr}."
          end
          w_meth = source_file.define_c_method(self, "#{var}=")
          w_meth.instance_eval {
            scope :extern
            c_array_args {
              required  :arg
              typecheck :arg => attr.check
            }
            declare :shadow => "#{ssn} *shadow"
            body "Data_Get_Struct(self, #{ssn}, shadow)", attr.writer
            returns "arg"
          }
        end
        
        [r_meth, w_meth]
      end
    end
  end

  def self.append_features base_class # :nodoc:
    unless base_class.is_a? Class
      raise TypeError, "CShadow can be included only in a Class"
    end

    unless base_class.ancestors.include? self
      base_class.class_eval {@base_class = self; @persistent = true}
      base_class.extend CShadowClassMethods

      class << base_class
        ## why can't these be in CShadowClassMethods?

        alias really_protected protected
        def protected(*args)
          (@to_be_protected ||= []).concat args
        end

        alias really_private private
        def private(*args)
          (@to_be_private ||= []).concat args
        end

        def protect_shadow_attrs
          if defined?(@to_be_protected) and @to_be_protected
            really_protected(*@to_be_protected)
          end
          if defined?(@to_be_private) and @to_be_private
            really_private(*@to_be_private)
          end
          ## should undo the aliasing
        end
        public :protect_shadow_attrs

      end

    end

    super
  end

  class AttrCodeAccumulator < CGenerator::CFragment::StatementAccumulator
    include CGenerator::SetAccumulator
  end
  
  class AttrMethod < CGenerator::Method
    accumulator(:attr_code) {AttrCodeAccumulator}
    accumulator(:pre_code)  {CGenerator::CFragment::StatementAccumulator}
    accumulator(:post_code) {CGenerator::CFragment::StatementAccumulator}
  end
  
  class AttrClassMethod < CGenerator::SingletonMethod
    accumulator(:attr_code) {AttrCodeAccumulator}
  end

  class MarkFunction < CGenerator::Function
    accumulator(:mark) {AttrCodeAccumulator}
    
    def initialize(*args)
      super
      body "rb_gc_mark(shadow->self)", mark!
    end
  end
  
  class FreeFunction < CGenerator::Function
    accumulator(:free) {AttrCodeAccumulator}
    
    def initialize(*args)
      super
      body free!, "free(shadow)"  # free the struct last!
    end
  end
  
  def inspect # :nodoc:
    attrs = []
    seen = {self => true}
    each_attr_value do |attr, value|
      if seen[value]
        attrs << "#{attr}=#{value}"
      else
        attrs << "#{attr}=#{value.inspect}"
      end
      seen[value] = true
    end
    super.sub(/(?=>\z)/, " " + attrs.join(", "))
  end
  
  # Iterate over each shadow attr and instance var of +self+, yielding the attr
  # name and value in this instance to the block. Differs in three ways from
  # CShadow.each_shadow_attr: it is an instance method of shadow objects, it
  # iterates over both shadow attrs and instance vars, and it yields both the
  # name and the value. (In the case of instance vars, the name does _not_
  # include the "@".)
  def each_attr_value # :yields: attr_name, attr_value
    values = _dump_data
    self.class.shadow_attrs.each_with_index do |attr, i|
      yield attr.var.to_s, values[i]
    end
    instance_variables.each do |ivar|
      yield ivar[1..-1], instance_variable_get(ivar)
    end
  end

  # Like #each_attr_value, but limited to attr declared as +persistent+.
  def each_persistent_attr_value # :yields: attr_name, attr_value
    values = _dump_data
    psa = self.class.shadow_attrs.select {|attr| attr.persists}
    psa.each_with_index do |attr, i|
      yield attr.var.to_s, values[i]
    end
    instance_variables.each do |ivar|
      yield ivar[1..-1], instance_variable_get(ivar)
    end
  end

  # Define YAML methods for CShadow classes. Can be called before
  # or after #commit. Loads the yaml library.
  def self.allow_yaml(your_tag = "path.berkeley.edu,2006")
    return if defined?(@cshadow_allow_yaml) and @cshadow_allow_yaml
    @cshadow_allow_yaml = true

    require 'yaml'
    
    yaml_as "tag:#{your_tag}:cshadow"

    def self.yaml_new( klass, tag, val )
      subtype, subclass = YAML.read_type_class(tag, Object)
      subclass.new_from_hash(val)
    end

    module_eval do
      def add_yaml_map_contents(map)
        each_persistent_attr_value do |attr, value|
          map.add(attr, value)
        end
      end

      def to_yaml( opts = {} )
        YAML.quick_emit(object_id, opts) do |out|
          out.map( taguri, to_yaml_style ) do |map|
            add_yaml_map_contents(map)
          end
        end
      end
    end
  end
end
