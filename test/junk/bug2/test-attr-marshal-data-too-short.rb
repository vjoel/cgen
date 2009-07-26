require 'test/unit'
require 'cgen/cshadow'

#
#  Tests in this file focus on the behavior of individual attributes:
#  accessors, initial values, type conversion and checking, 
#  garbage collection (mark and free functions), etc.
#

class AttributeSample
  include CShadow
end

# General test of marshaling shadow objects.
class MarshalSample < AttributeSample
  shadow_attr_accessor :x => Object
  attr_accessor :t
end

class MarshalTest < Test::Unit::TestCase
  def test_marshal_ivars
    ms = MarshalSample.new
    ms.x = ["a", :b]
    ms.t = {3.79 => "zap"}
    ms.instance_eval {@u = 4}

    str = Marshal.dump ms
    copy = Marshal.load str

    assert_equal(ms.class, copy.class)
    assert_equal(ms.x, copy.x)
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
    copy = Marshal.load str, proc { |x|
      if x.class == MarshalSample then count += 1 end
    }

    assert_same(copy.x, copy.t.x)
    assert_same(copy.x.x, copy)
    assert_equal(3, count)
  end
end

require 'ftools'
dir = File.join("tmp", RUBY_VERSION)
File.mkpath dir
Dir.chdir dir

AttributeSample.commit
