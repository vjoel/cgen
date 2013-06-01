require 'minitest/autorun'
require 'cgen/cshadow'

#
#  Tests in this file focus on the behavior of individual attributes:
#  accessors, initial values, type conversion and checking, 
#  garbage collection (mark and free functions), etc.
#

class AttributeSample
  include CShadow
end

class AttributeTest < Minitest::Test
  def default_test; end
end

class ObjectAttributeTest < AttributeTest
  class ObjectAttributeSample < AttributeSample
    def self.foo; end
    shadow_attr_accessor :x => Object, :y => String,
                         :z => ObjectAttributeSample
  end

  def test__initial
    @oas = ObjectAttributeSample.new
    assert_equal(nil, @oas.x)
    assert_equal(nil, @oas.y)
  end

  def test_accessor
    @oas = ObjectAttributeSample.new
    @oas.x = lx = Object.new
    @oas.y = ly = "A string"
    @oas.z = @oas
    assert_same(lx, @oas.x)
    assert_same(ly, @oas.y)
    assert_same(@oas, @oas.z)

    @oas.x = nil
    @oas.y = nil
    assert_equal(nil, @oas.x)
    assert_equal(nil, @oas.y)
  end

  def test_typecheck
    @oas = ObjectAttributeSample.new
    assert_raises(TypeError) {
      @oas.y = 5
    }
  end

  def make_thing c
    @oas.x = c.new
  end
  
  def make_things c, n
    10.times do
      make_thing c
    end
  end

  def trash_thing
    @oas.x = nil
  end

  def test_gc
    @oas = ObjectAttributeSample.new
    c = Class.new

    make_things c, 10

    GC.start
    assert_equal(1, ObjectSpace.each_object(c) {})
  end

  def test_marshal_uninitialized
    @oas = ObjectAttributeSample.new
    s = Marshal.dump @oas
    t = Marshal.load s
    assert_equal(nil, t.x)
  end

  def test_marshal_nil
    @oas = ObjectAttributeSample.new
    @oas.x = nil
    s = Marshal.dump @oas
    t = Marshal.load s
    assert_equal(nil, t.x)
  end

  def test_marshal
    @oas = ObjectAttributeSample.new

    @oas.x = "fred"
    copy = Marshal.load(Marshal.dump(@oas))
    assert_equal("fred", copy.x)

    @oas.x = nil
    copy = Marshal.load(Marshal.dump(@oas))
    assert_equal(nil, copy.x)
  end
end

class ShadowObjectAttributeTest < AttributeTest
  class ShadowObjectAttributeSample < AttributeSample
    shadow_attr_accessor :x => [ShadowObjectAttributeSample]
    shadow_attr_accessor :z => "int z"
  end

  class Sub < ShadowObjectAttributeSample
    shadow_attr_accessor :y => "int y"
  end

  def test__initial
    @sas = ShadowObjectAttributeSample.new
    assert_equal(nil, @sas.x)
  end

  def test_accessor
    @sas = ShadowObjectAttributeSample.new
    @sas.x = lx = ShadowObjectAttributeSample.new
    assert_same(lx, @sas.x)
    @sas.x = nil
    assert_equal(nil, @sas.x)
  end

  def test_typecheck
    @sas = ShadowObjectAttributeSample.new
    assert_raises(TypeError) {
      @sas.x = 5
    }
  end

  def make_thing c
    @sas.x = c.new
  end
  
  def make_things c, n
    n.times do
      make_thing c
    end
  end

  def trash_thing
    @sas.x = nil
  end

  def test_gc
    @sas = ShadowObjectAttributeSample.new
    c = ShadowObjectAttributeSample

    GC.start
    n = ObjectSpace.each_object(c) {}
    make_things c, 10
    GC.start
    n2 = ObjectSpace.each_object(c) {}
    assert_send( [[n, n+1], :include?, n2] )
  end

  def test_marshal_uninitialized
    @sas = ShadowObjectAttributeSample.new
    s = Marshal.dump @sas
    t = Marshal.load s
    assert_equal(nil, t.x)
  end

  def test_marshal_nil
    @sas = ShadowObjectAttributeSample.new
    @sas.x = nil
    s = Marshal.dump @sas
    t = Marshal.load s
    assert_equal(nil, t.x)
  end

  def test_marshal
    @sas1 = ShadowObjectAttributeSample.new
    @sas2 = ShadowObjectAttributeSample.new

    @sas1.x = @sas2
    @sas2.x = @sas1
    s = Marshal.dump @sas1
    t = Marshal.load s
    assert_same(t, t.x.x)

    @sas1.x = nil
    @sas1.z = 3
    s = Marshal.dump @sas1
    t = Marshal.load s
    assert_equal(nil, t.x)
    assert_equal(3, t.z)
  end

  def test_sub
    @sas = ShadowObjectAttributeSample.new
    sub = Sub.new
    sub.y = 3
    @sas.x = sub
    assert_equal(3, @sas.x.y)

    s = Marshal.dump sub
    t = Marshal.load s
    assert_equal(3, t.y)

    s = Marshal.dump @sas
    t = Marshal.load s
    assert_equal(3, t.x.y)
  end
end

class IntAttributeTest < AttributeTest
  class IntAttributeSample < AttributeSample
    shadow_attr_accessor :x => "int x"
  end

  def test__initial
    @ias = IntAttributeSample.new
    assert_equal(0, @ias.x)
  end

  def test_accessor
    @ias = IntAttributeSample.new
    @ias.x = 5
    assert_equal(5, @ias.x)
    @ias.x = -5.1
    assert_equal(-5, @ias.x)
    @ias.x = 2**31-1
    assert_equal(2**31-1, @ias.x)
    assert_raises(RangeError) {@ias.x = 2**31}
    @ias.x = -2**31
    assert_equal(-2**31, @ias.x)
    assert_raises(RangeError) {@ias.x = -2**31 - 1}
  end

  def test_conversion
    @ias = IntAttributeSample.new
    @ias.x = 5.1
    assert_equal(5, @ias.x)
  end

  def test_typecheck
    @ias = IntAttributeSample.new
    assert_raises(TypeError) {
      @ias.x = "Foo"
    }
  end

  def test_marshal
    @ias = IntAttributeSample.new
    @ias.x = -11
    s = Marshal.dump @ias
    t = Marshal.load s
    assert_equal(@ias.x, t.x)

    @ias.x = 2**31-1
    s = Marshal.dump @ias
    t = Marshal.load s
    assert_equal(@ias.x, t.x)
  end
end

class BooleanAttributeTest < AttributeTest
  class BooleanAttributeSample < AttributeSample
    shadow_attr_accessor :x => "boolean x"
  end

  def test__initial
    @ias = BooleanAttributeSample.new
    assert_equal(false, @ias.x)
  end

  def test_accessor
    @ias = BooleanAttributeSample.new
    @ias.x = true
    assert_equal(true, @ias.x)
    @ias.x = false
    assert_equal(false, @ias.x)
    @ias.x = nil
    assert_equal(false, @ias.x)
  end

  def test_conversion
    @ias = BooleanAttributeSample.new
    @ias.x = 5
    assert_equal(true, @ias.x)
    @ias.x = {:foo => "bar"}
    assert_equal(true, @ias.x)
  end

  def test_marshal
    @ias = BooleanAttributeSample.new
    @ias.x = true
    s = Marshal.dump @ias
    t = Marshal.load s
    assert_equal(@ias.x, t.x)

    @ias.x = false
    s = Marshal.dump @ias
    t = Marshal.load s
    assert_equal(@ias.x, t.x)
  end
end

class LongAttributeTest < AttributeTest
  class LongAttributeSample < AttributeSample
    shadow_attr_accessor :x => "long x"
  end

  def test__initial
    @las = LongAttributeSample.new
    assert_equal(0, @las.x)
  end

  def test_accessor
    @las = LongAttributeSample.new
    @las.x = 5
    assert_equal(5, @las.x)
    @las.x = -5.1
    assert_equal(-5, @las.x)
    @las.x = 2**31-1
    assert_equal(2**31-1, @las.x)
    assert_raises(RangeError) {@las.x = 2**63}
      # on 32 bit, should use: @las.x = 2**31
    @las.x = -2**31
    assert_equal(-2**31, @las.x)
    assert_raises(RangeError) {@las.x = -2**63 - 1}
  end

  def test_conversion
    @las = LongAttributeSample.new
    @las.x = 5.1
    assert_equal(5, @las.x)
  end

  def test_typecheck
    @las = LongAttributeSample.new
    assert_raises(TypeError) {
      @las.x = "Foo"
    }
  end

  def test_marshal
    @las = LongAttributeSample.new
    @las.x = -11
    s = Marshal.dump @las
    t = Marshal.load s
    assert_equal(@las.x, t.x)

    @las.x = 2**31-1
    s = Marshal.dump @las
    t = Marshal.load s
    assert_equal(@las.x, t.x)
  end
end

class DoubleAttributeTest < AttributeTest
  class DoubleAttributeSample < AttributeSample
    shadow_attr_accessor :x => "double x"
  end

  def test__initial
    @das = DoubleAttributeSample.new
    assert_equal(0, @das.x)
  end

  def test_accessor
    @das = DoubleAttributeSample.new
    @das.x = 5.1
    assert_equal(5.1, @das.x)
  end

  def test_conversion
    @das = DoubleAttributeSample.new
    @das.x = 5
    assert_equal(5, @das.x)
  end

  def test_typecheck
    @das = DoubleAttributeSample.new
    assert_raises(TypeError) {
      @das.x = "Foo"
    }
  end

  def test_marshal
    @das = DoubleAttributeSample.new
    @das.x = -11.8
    s = Marshal.dump @das
    t = Marshal.load s
    assert_equal(@das.x, t.x)
  end
end    

class CharPointerAttributeTest < AttributeTest
  class CharPointerSample < AttributeSample
    shadow_attr_accessor :x => "char *x"
  end

  def test__initial
    @cps = CharPointerSample.new
    assert_equal(nil, @cps.x)
  end

  def test_accessor
    @cps = CharPointerSample.new
    str = "foo"
    @cps.x = str
    assert_equal("foo", @cps.x)
    assert(str.object_id != @cps.x.object_id)

    @cps.x = nil
    assert_equal(nil, @cps.x)
  end

  def test_typecheck
    @cps = CharPointerSample.new
    assert_raises(TypeError) {
      @cps.x = 5
    }
  end

  def test_marshal
    @cps = CharPointerSample.new
    @cps.x = "a string"
    s = Marshal.dump @cps
    t = Marshal.load s
    assert_equal(@cps.x, t.x)
  end
end

# General test of marshaling shadow objects.
class MarshalSample < AttributeSample
  shadow_attr_accessor :x => Object, :y => String
  attr_accessor :t
end

class MarshalTest < Minitest::Test
  def test_marshal_ivars
    ms = MarshalSample.new
    ms.x = ["a", :b]
    ms.y = "fuzz"
    ms.t = {3.79 => "zap"}
    ms.instance_eval {@u = 4}

    str = Marshal.dump ms
    copy = Marshal.load str

    assert_equal(ms.class, copy.class)
    assert_equal(ms.x, copy.x)
    assert_equal(ms.y, copy.y)
    assert_equal(ms.t, copy.t)
    assert_equal(ms.instance_eval {@u}, copy.instance_eval {@u})
  end

  def test_link_and_proc
    ms1 = MarshalSample.new
    ms2 = MarshalSample.new
    ms3 = MarshalSample.new

    ms1.x = ms3
    ms1.t = ms2

    ms2.x = ms3
    ms3.x = ms1

    count = 0
    str = Marshal.dump ms1
    copy = Marshal.load str

    assert_same(copy.x, copy.t.x)
    assert_same(copy.x.x, copy)
  end
end

require 'fileutils'
dir = File.join(File.dirname(__FILE__), "tmp", RUBY_VERSION)
FileUtils.mkpath dir
Dir.chdir dir do
  AttributeSample.commit
end
