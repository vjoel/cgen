  require 'cgen/cshadow'

  class MyClass
    include CShadow
    shadow_attr_accessor :my_c_string => "char *my_string"
    shadow_attr_accessor :my_ruby_string => String
    shadow_attr_accessor :my_ruby_object => Object

    def initialize
      # Must use 'self.varname = value', or else ruby will assign to
      # local var
      self.my_c_string = "default string"
        # stored as null-terminated char *

      self.my_ruby_string = "default string"
        # stored as ruby VALUE string, after checking type is String

      self.my_ruby_object = "default string"
        # stored as ruby VALUE string, no type checking
    end

    def inspect
      "<#{self.class}: %p, %p, %p>" %
        [my_c_string, my_ruby_string, my_ruby_object]
    end

    # easy way to add a method written in C
    define_c_method :foo do

      c_array_args { # interface to rb_scan_args
        required :x
        optional :y
        rest :stuff
        block :block
        typecheck :x => Numeric
        default :y => "INT2NUM(NUM2INT(x) + 1)"
      }

      declare :result   => "VALUE   result"

      body %{
        result = rb_funcall(block, #{declare_symbol :call}, 4,
                            shadow->my_ruby_string,
                            x, y, stuff);
      }
      # note use of shadow var to access shadow attrs

      returns "result"
    end
  end

  MyClass.commit # write C lib, compile, load

  my_obj = MyClass.new
  p my_obj
  # ==> <MyClass: "default string", "default string", "default string">

  block = proc do |str, x, y, stuff|
    "%s, %p, %p, %p" % [str, x, y, stuff]
  end

  p my_obj.foo(1, &block)
  # ==> "default string, 1, 2, []"
  p my_obj.foo(5, 0, "stuff", "more stuff", &block) 
  # ==> "default string, 5, 0, [\"stuff\", \"more stuff\"]"
