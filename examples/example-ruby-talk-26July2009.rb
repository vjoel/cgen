require 'cgen/cshadow'

class Complex < Numeric
  include CShadow

  shadow_attr_accessor :re => "double re"
  shadow_attr_accessor :im => "double im"

  def initialize re, im
    self.re = re
    self.im = im
  end

  define_c_method(:abs) {
    include "<math.h>"
    returns "rb_float_new(sqrt(pow(shadow->re, 2) + pow(shadow->im, 2)))"
  }
  
  define_c_method(:scale!) {
    c_array_args {
      optional  :factor
      default   :factor => "INT2NUM(10)"
      typecheck :factor => Numeric
    }
    body %{
      shadow->re *= NUM2DBL(factor);
      shadow->im *= NUM2DBL(factor);
    }
    returns "self"
  }
end

Complex.commit

z = Complex.new 5, 1.3
p z             # ==> #<Complex:0xb7dc0098 re=5.0, im=1.3>
puts z.abs      # ==> 5.1662365412358
z.scale! 3.0    # float
p [z.re, z.im]  # ==> [15.0, 3.9]
z.scale! 3      # int
p [z.re, z.im]  # ==> [45.0, 11.7]
z.scale!        # use default value
p [z.re, z.im]  # ==> [450.0, 117]
