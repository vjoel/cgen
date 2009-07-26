#!/usr/bin/env ruby

require 'cgen/cshadow'

class MyMatrix
  include CShadow

  shadow_attr_reader :rows => "int rows", :cols => "int cols"
  shadow_attr :matrix => "double *matrix"

  define_c_method(:initialize) {
    c_array_args {
      required :rows, :cols
      typecheck :rows => Fixnum, :cols => Fixnum
    }
    declare :size => "int size"
    body %{
      shadow->rows = FIX2INT(rows);
      shadow->cols = FIX2INT(cols);
      
      if (shadow->rows <= 0)
        rb_raise(#{declare_class ArgumentError}, "Rows must be positive.");
      if (shadow->cols <= 0)
        rb_raise(#{declare_class ArgumentError}, "Cols must be positive.");
      
      size = shadow->rows * shadow->cols;
      shadow->matrix = ALLOC_N(double, size);
      memset(shadow->matrix, 0, size * sizeof(double));
    }
  }
  
  define_c_method(:[]) {
    arguments :i, :j
    declare :ii => "int ii", :jj => "int jj"
    body %{
      ii = NUM2INT(i);
      jj = NUM2INT(j);

      if (ii < 0 || ii >= shadow->rows)
        rb_raise(#{declare_class IndexError},
                 "Row index %d out of range [0, %d]",
                 ii, shadow->rows - 1);

      if (jj < 0 || jj >= shadow->cols)
        rb_raise(#{declare_class IndexError},
                 "Column index %d out of range [0, %d]",
                 jj, shadow->cols - 1);
    }
    returns "rb_float_new(shadow->matrix[ii * shadow->cols + jj])"
  }

  define_c_method(:[]=) {
    arguments :i, :j, :x
    declare :ii => "int ii", :jj => "int jj", :xx => "double xx"
    body %{
      ii = NUM2INT(i);
      jj = NUM2INT(j);
      xx = NUM2DBL(x);

      if (ii < 0 || ii >= shadow->rows)
        rb_raise(#{declare_class IndexError},
                 "Row index %d out of range 0..%d",
                 ii, shadow->rows - 1);

      if (jj < 0 || jj >= shadow->cols)
        rb_raise(#{declare_class IndexError},
                 "Column index %d out of range 0..%d",
                 jj, shadow->cols - 1);

      shadow->matrix[ii * shadow->cols + jj] = xx;
    }
    returns "x"
  }
end

require 'ftools'
dir = File.join("tmp", RUBY_VERSION)
File.mkpath dir
Dir.chdir dir

MyMatrix.commit

m = MyMatrix.new 5, 2
m[3,1] = 8.2e+13
puts m[3,1]
puts m[3,0]
begin
  puts m[3,2]
rescue IndexError
  puts "Caught an IndexError: m[3,2] is out of range."
end
