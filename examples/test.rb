#!/usr/bin/env ruby

require 'cgen/cgen'

lib = CGenerator::Library.new("test_lib")

lib.instance_eval {

  define_c_global_function(:test).instance_eval {
    declare :x => "double x"
    body %{
      for (x = 1.0; x >= 0.09; x -= 0.1);
    }
    returns "rb_float_new(x)"
  }

}

#Dir.mkdir "tmp" rescue SystemCallError
Dir.chdir "tmp"

lib.commit

p test
