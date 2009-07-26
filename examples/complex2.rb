#!/usr/bin/env ruby

require 'cgen/cshadow'

class MyComplex2 < Numeric
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

require 'ftools'
dir = File.join("tmp", RUBY_VERSION)
File.mkpath dir
Dir.chdir dir do
  MyComplex2.commit
end

z = MyComplex2.new 5, 1.3
puts z.abs      # ==> 5.1662365412358
z.scale! 3.0    # float
p [z.re, z.im]  # ==> [15.0, 3.9]
z.scale! 3      # int
p [z.re, z.im]  # ==> [45.0, 11.7]
z.scale!        # use default value
p [z.re, z.im]  # ==> [450.0, 117]
