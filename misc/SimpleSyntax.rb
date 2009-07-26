#!/usr/bin/env ruby

require 'cgen'

include CGenerator::SimpleSyntax

library("simple") {

  define_global_function(:test) {
    arguments {
      required :x, :y  ## uses c_array_args
    }
    returns 
  }
  
  define_class :Foo {
  
    define_method(:meth) {

    }
  
  }
  
} ## commit now
