#!/usr/bin/env ruby

require 'cgen/cshadow'

SAME_LIBRARY = true

class A
  include CShadow
  shadow_attr_accessor :obj => Object, :sym => Symbol
end

class B
  include CShadow
  
  if SAME_LIBRARY
    shadow_library A                # in the same lib as A
    shadow_library_file 'B'         # but in a different file
  else  
    # different lib, but connected with a '#include'
    shadow_library_include_file.include '../A/A.h'
  end
  
  shadow_attr_accessor :a => [A]

  def initialize
    self.a = A.new
    self.a.sym = :something
  end
end

require 'ftools'
dir = File.join("tmp", RUBY_VERSION)
File.mkpath dir
Dir.chdir dir

A.commit
unless SAME_LIBRARY
  B.commit
end

p B.new.a.sym

A.shadow_library.make 'distclean'
unless SAME_LIBRARY
  B.shadow_library.make 'distclean'
end
