require 'cgen/cshadow'
require 'yaml'

CShadow.allow_yaml

class YamlExample
  include CShadow
  shadow_attr_accessor :x => "int x"
  shadow_attr_accessor :z => "double z"
  
  attr_accessor :a, :b
  
#  shadow_attr_accessor :myself => YamlExample
#  attr_accessor :myself2
  
  def initialize(x, z, a, b)
    self.x = x
    self.z = z
    @a = a
    @b = b
    
### These both gag the YAML parser.
#    self.myself = self
#    @myself2 = self
  end
end

Dir.mkdir('tmp') rescue SystemCallError
Dir.chdir('tmp') do
  YamlExample.commit
end

obj = YamlExample.new(1,2.6, :AAA, "BBB")
p obj
y obj

obj2 = YAML.load(YAML.dump(obj))
p obj2
y obj2

__END__

Output:

#<YamlExample:0x402b91dc x=1, z=2.6, b="BBB", a=:AAA>
--- !ruby/cshadow:YamlExample 
x: 1
z: 2.6
b: BBB
a: !ruby/sym AAA
#<YamlExample:0x402b67fc x=1, z=2.6, b="BBB", a=:AAA>
--- !ruby/cshadow:YamlExample 
x: 1
z: 2.6
b: BBB
a: !ruby/sym AAA
