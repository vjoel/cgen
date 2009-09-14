require 'cgen/cshadow'

class MyComplex < Numeric
  include CShadow

  shadow_attr_accessor :re => "double re", :im => "double im"

  def initialize re, im
    self.re = re
    self.im = im
  end

  define_c_method(:abs) {
    include "<math.h>"
    returns "rb_float_new(sqrt(pow(shadow->re, 2) + pow(shadow->im, 2)))"
  }

  define_c_method(:mul!) {
    arguments :other
    declare :other_shadow => "MyComplex_Shadow *other_shadow"
    declare :new_re => "double new_re", :new_im => "double new_im"
    body %{
      switch (TYPE(other)) {
        case T_FIXNUM:  shadow->re *= FIX2INT(other);
                        shadow->im *= FIX2INT(other); break;
        case T_FLOAT:   shadow->re *= NUM2DBL(other);
                        shadow->im *= NUM2DBL(other); break;
        default:
          if (rb_obj_is_kind_of(other, #{declare_class MyComplex}) ==
              Qtrue) {
            Data_Get_Struct(other, MyComplex_Shadow, other_shadow);
            new_re = shadow->re * other_shadow->re -
                     shadow->im * other_shadow->im;
            new_im = shadow->re * other_shadow->im +
                     shadow->im * other_shadow->re;
            shadow->re = new_re;
            shadow->im = new_im;
          }
          else
            rb_raise(#{declare_class ArgumentError},
                     "Argument to mul! is not numeric.");
      }
    }
    returns "self"
  }
end

require 'ftools'
dir = File.join("tmp", RUBY_VERSION)
File.mkpath dir
Dir.chdir dir

MyComplex.commit

z = MyComplex.new 5, 1.3
puts z.abs
z.mul! 10
p [z.re, z.im]
w = MyComplex.new 7.9, -1.2
z.mul! w
p [z.re, z.im]
