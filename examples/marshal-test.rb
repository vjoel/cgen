require 'cgen/cshadow'

class MarshalTest
  include CShadow
  
  shadow_attr_accessor :x => Object
end

Dir.mkdir "tmp" rescue SystemCallError
Dir.chdir "tmp"

MarshalTest.commit

mt = MarshalTest.new

mt.x = "foo"
p mt.x

p Marshal.dump mt
