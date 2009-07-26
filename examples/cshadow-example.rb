#!/usr/env/bin ruby

require 'cgen/cshadow'

class Test
  include CShadow
  shadow_attr_accessor\
    :i => "int ii",
    :d => "double d"
  shadow_attr_reader :obj => Object
end

class SubTest < Test
  shadow_attr :hidden_array => Array
  shadow_attr_accessor\
    :foo => "char *foo",
    :bar => Symbol,
    :test => [Test]
end

class OtherSubTest < Test
  shadow_attr_accessor :j => "int j"
  def initialize j_init
    self.j = j_init
  end
end

class SubSubTest < SubTest
  shadow_attr_accessor :z => Object
end

require 'ftools'
dir = File.join("tmp", RUBY_VERSION)
File.mkpath dir
Dir.chdir dir

SubTest.commit # same as Test.commit

x = SubTest.new
puts "i = #{x.i}, d = #{x.d}, " +
     "foo = #{x.foo.inspect}, bar = #{x.bar.inspect}"
x.i = 7.5; x.d = 3; x.foo = "fred"; x.bar = :WILMA
puts "i = #{x.i}, d = #{x.d}, " +
     "foo = #{x.foo.inspect}, bar = #{x.bar.inspect}"

y = OtherSubTest.new -123456789
puts y.j, y.d

# make sure ShadowAttribute works
puts "x.test = #{x.test || 'nil'}"
x.test = y
puts "x.test = #{x.test || 'nil'}"
puts x.test.j

SubSubTest.each_shadow_attr {|x| p x}
