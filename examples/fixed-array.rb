#!/usr/bin/env ruby

require "cgen/cshadow"

=begin

This file contains an assortment of classes of shadow objects that are useful in building up complex data structures.

==class (({FixedArray}))

(({FixedArray})) is a factory class for generating fixed-size arrays of C variables or Ruby objects. There are several reasons for implementing (({FixedArray})) as a standalone object instead of as an attribute. First, defining [] and []= for one array attribute might conflict with another definition of those methods in the same object. Second, it can include Enumerable and add additional methods in subclasses. Third, the factory approach can handle different Ruby and C types more easily, with length and item_type stored as Ruby class attributes. Finally, an array attribute cannot easily return itself as a value to Ruby code. It is better if the array ((*is*)) the object.

For efficiency and easy access from C code, an attribute that refers to a (({FixedArray})) can be a (({ShadowAttribute})) rather than an (({ObjectAttribute})). (See ((<attribute.rb>)).)

If the (({item_type})) is a class which includes (({CShadow})), then the array itself uses (({ShadowAttribute}))s for efficiency. Ruby code doesn't need to be aware of this, but C code does: the entries are not of type (({VALUE})) but of type determined by calling (({#shadow_struct_name})).

Each different (({length})) and (({item_type})) results in a new anonymous subclass of (({FixedArray})), defined in its own library (because of the commit problem).

=end

if true # if this ever is useful, put it in attribute.rb

  # Fixed length array, embedded within shadow struct.
  # For use, see examples/fixed-array.rb.
  #
  # Currently, this attr type accepts declarations of
  # the form
  #  shadow_attr :var => "<type> <name>[<len>]"
  # and
  #  shadow_attr :var => "<type> * <name>[<len>]"
  # with any arrangement of spaces around the "*",
  # where <type> is a standard C type (int, double,
  # char) or a type defined by typedef.
  # 
  # Support for VALUE and shadow struct types is less
  # useful, but may later be added for completeness.
  #
  # The host object must define reader/writer methods.
  #
  class FixedArrayAttribute < CShadow::CNativeAttribute
    @pattern = /\A(\w+\s*\*?)\s*(\w+)\[(\d+)\]\z/
    
    attr_reader :length

    def initialize(*args)
      super
      @length = @match[3].to_i
      
      case @ctype
      when /\AVALUE /
        raise NotImplementedError
      when /#{CShadow::SHADOW_SUFFIX}\s*\*/
        raise NotImplementedError
      when /\*/
        @free = %{
          {
            int i;
            for (i = 0; i < #{@length}; i++)
              free(shadow->#{@cvar}[i])
          }
        }
      else
        # Not a pointer. Nothing to do.
      end
    end

  end

end

class FixedArray
  include Enumerable
  
  # length and item_type are hard-coded in the subclass definitions.
  def length;    type.length;    end
  def item_type; type.item_type; end

  @subs = {}
  
  class << self
    def length;    @length;    end
    def item_type; @item_type; end
    
    def to_s ### necessary?
      name
    end
    
    def new length, item_type = Object
      if self == FixedArray
        c = @subs[[length, item_type]] ||= make_subclass(length, item_type)
        c.new
      else
        super() ### superclass.new ... ???
      end
    end

    def make_subclass length, item_type
      c = Class.new(FixedArray)
      
      def c.name
        "FixedArray_#{@length}_#{@item_type}"
      end

      c.class_eval %q{ ### why doesn't block work?
        @length = length
        @item_type = item_type
        
        include CShadow
        shadow_library "foo_#@length_#@item_type"
        
        unless length > 0
          raise ArgumentError, "\nLength must be positive."
        end
        
        case item_type
        when Class
          raise NotImplementedError ## for now. These cases aren't so useful.
          if item_type.included_modules.include? CShadow
            shadow_attr :array =>
              "#{item_type.shadow_struct_name} *array[#{length}]"
          else
            shadow_attr :array => "VALUE array[#{length}]"
          end
        when String
          unless item_type =~ /\A\w+\s*\*?\z/
            raise TypeError, "\n"
          end
          shadow_attr :array => "#{item_type} array[#{length}]"
        end
        
        define_method(:[]) {
          arguments :index
          declare :i => "int i"
          body %{
            i = NUM2INT(index);
            if (i < 0 || i >= sizeof(shadow->array))
              rb_raise(#{declare_class IndexError},
                       "Index %d out of range [0, %d]",
                       i, sizeof(shadow->array) - 1);
          }
          case item_type
          when "int";     returns "INT2FIX(shadow->array[i])"
          when "double";  returns "rb_float_new(shadow->array[i])"
          else            raise NotImplementedError
          end
        }

        define_method(:[]=) {
          arguments :index, :value
          declare :i => "int i"
          body %{
            i = NUM2INT(index);
            if (i < 0 || i >= sizeof(shadow->array))
              rb_raise(#{declare_class IndexError},
                       "Index %d out of range [0, %d]",
                       i, sizeof(shadow->array) - 1);
          }
          case item_type
          when "int";     body "shadow->array[i] = NUM2INT(value)"
          when "double";  body "shadow->array[i] = NUM2DBL(value)"
          else            raise NotImplementedError
          end
          returns "value"
        }
      }
      
      begin
        Dir.mkdir "FixedArray"
      rescue SystemCallError
      end
      Dir.chdir "FixedArray"

      c.commit
      
      Dir.chdir ".."
      
      return c
    end
    private :make_subclass
  end
  
  # conversion to array and back
  
  def each
  
  end
end

def FixedArray length, item_type = Object
  FixedArray.new length, item_type
end


if $0 == __FILE__

  require "cgen/cshadow"

  require 'runit/testcase'
  require 'runit/cui/testrunner'
  require 'runit/testsuite'

  begin
    Dir.mkdir "tmp"
  rescue SystemCallError
  end
  Dir.chdir "tmp"

  class FixedArrayTest < RUNIT::TestCase
    
    Fai = FixedArray 10, "int"
    Fad = FixedArray 10, "double"
    
    def test__initial
      assert_equal(0, Fai[0])
      assert_equal(0, Fad[0])
    end
  end
  
  RUNIT::CUI::TestRunner.run(FixedArrayTest.suite)

end
