#!/usr/bin/env ruby

=begin

Sample for CGenerator.

==version

CGenerator 0.14

The current version of this software can be found at 
((<"http://redshift.sourceforge.net/cgen
"|URL:http://redshift.sourceforge.net/cgen>)).

==license
This software is distributed under the Ruby license.
See ((<"http://www.ruby-lang.org"|URL:http://www.ruby-lang.org>)).

==author
Joel VanderWerf,
((<vjoel@users.sourceforge.net|URL:mailto:vjoel@users.sourceforge.net>))

=end

require 'cgen/cgen'
require 'fileutils'

FileUtils.mkdir_p "tmp"

lib = CGenerator::Library.new "sample_lib"

class Point; end

lib.declare_extern_struct(:point).instance_eval {
  # make it extern so we can see it from another lib
  declare :x => "double x"
  declare :y => "double y"
}

lib.define_c_global_function(:new_point).instance_eval {
  arguments "x", "y"        # 'VALUE' is assumed
  declare :p => "point *p"
  declare :result => "VALUE result"
      # semicolons are added automatically
  body %{
    result = Data_Make_Struct(#{declare_module Point}, point, 0, free, p);
    p->x = NUM2DBL(x);
    p->y = NUM2DBL(y);
    
//#  might want to do something like this, too:
//#  rb_funcall(result, #{lib.declare_symbol :initialize}, 0);
  }
  returns "result"
      # can put a return statement in the body, if preferred
}

for var in [:x, :y]   # metaprogramming in C!
  lib.define_c_method(Point, var).instance_eval {
    declare :p => "point *p"
    body %{
      Data_Get_Struct(self, point, p);
    }
    returns "rb_float_new(p->#{var})"
  }
end

# A utility function, available to other C files
lib.define_c_function("distance").instance_eval {
  arguments "point *p1", "point *p2"
  return_type "double"
  scope :extern
  returns "sqrt(pow(p1->x - p2->x, 2) + pow(p1->y - p2->y, 2))"
  include "<math.h>"
  # The include accumulator call propagates up the parent
  # hierarchy until something handles it. In this case,
  # the Library lib handles it by adding an include
  # directive to the .c file. This allows related, but
  # separate aspects of the C source to be handled in
  # the same place in the Ruby code. We could also have
  # called include directly on lib.
}

lib.define_c_method(Point, :distance).instance_eval {
  # no name conflict between this "distance" and the previous one,
  # because "method" and "Point" are both part of the C identifier
  # for this method
  arguments "other"
  declare :p => "point *p"
  declare :q => "point *q"
  body %{
    Data_Get_Struct(self, point, p);
    Data_Get_Struct(other, point, q);
  }
  returns "rb_float_new(distance(p, q))"
}
  
lib.commit # now you can use the new definitions

p1 = new_point(1, 2)
puts "p1: x is #{p1.x}, y is #{p1.y}"

p2 = new_point(5, 8)
puts "p2: x is #{p2.x}, y is #{p2.y}"

puts "distance from p1 to p2 is #{p1.distance p2}"

# now let's make another lib, and test Library#c_array_args

lib2 = CGenerator::Library.new "sample_lib_2"

lib2.include "../sample_lib/sample_lib.h"

lib2.define_c_method(Point, :closest).instance_eval {
  # 'farthest Q_1, Q_2, ...'
  # returns the Q_i which is closest to self
  
  c_array_args    # args get passed in argc, argv
  
  declare :i        => "int     i",
          :dist     => "double  dist",
          :mindist  => "double  mindist",
          :p        => "point   *p",
          :q        => "point   *q",
          :result   => "VALUE   result"
    
  body %{
    result = Qnil;
    Data_Get_Struct(self, point, p);
    for (i = 0; i < argc; i++) {
      Data_Get_Struct(argv[i], point, q);
      dist = distance(p, q);
      if (i == 0 || dist < mindist) {
        mindist = dist;
        result = argv[i];
      }
    }
  }
  returns "result"
}

lib2.define_c_singleton_method(Point, :test).instance_eval {
  c_array_args {
    required  :arg0, :arg1
    optional  :arg2, :arg3, :arg4
    typecheck :arg2 => Numeric, :arg3 => Numeric
    default   :arg3 => "INT2NUM(7)",
              :arg4 => "INT2NUM(NUM2INT(arg2) + NUM2INT(arg3))"
    rest      :rest
    block     :block
  }
  body %{\
    rb_funcall(block, #{declare_symbol :call}, 6,
               arg0, arg1, arg2, arg3, arg4, rest);
  }
  # returns nil by default
}

lib2.commit

puts
p3 = new_point(-2, 5)

q = new_point(4.1, 4.2)
puts "q=(#{q.x}, #{q.y})"

r = q.closest(p1, p2, p3)

for p in [p1, p2, p3]
  puts "point #{p.x}, #{p.y}. Distance to q: #{q.distance(p)}"
end

puts "closest to q: (#{r.x}, #{r.y})"
puts

tester = proc { |arg0, arg1, arg2, arg3, arg4, rest|
  argstrs = [arg0, arg1, arg2, arg3, arg4, rest].map { |arg| arg.inspect }
  printf "test args are: %s, %s, %s, %s, %s, %s\n", *argstrs
}

Point.test(0, 1, 2, &tester)  # omit 2 ==> Ruby fails to convert nil to int.
Point.test(0, 1, 2, 3, &tester)
Point.test(0, 1, 2, 3, 4, &tester)
Point.test(0, 1, 2, 3, 4, 5, &tester)
Point.test(0, 1, 2, 3, 4, 5, 6, &tester)
