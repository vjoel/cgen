require 'cgen/cshadow'

class Parent
  include CShadow
  
  shadow_attr_accessor :ruby_str => String
  shadow_attr_accessor :c_int => "int c_int"
end

class Child < Parent
  shadow_attr_accessor :obj => Object # VALUE type
end

Parent.commit
  # we're done adding attrs and methods, so make.

x = Child.new
x.ruby_str = "foo"
x.obj = [1,2,3]
x.c_int = 3

p x
# ==> #<Child:0xb7ba96f4 ruby_str="foo", c_int=3, obj=[1, 2, 3]>

CShadow.allow_yaml
y x
