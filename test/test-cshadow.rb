require 'minitest/autorun'
require 'cgen/cshadow'

#
#  Tests in this file focus on:
#   - shadow objects in general, rather than particular attribute
#     types, which are tested in attribute.rb
#   - behavior accessible from Ruby. The examples (complex.rb,
#     matrix.rb) test shadow objects from C.
#  Features tested include inheritance, multiple attributes, omission
#  of readers or writers, etc.
#

# EmptyBase hierarchy tests the following:
#  - inheritance with "gaps"
#  - using the same attr name in parallel branches

class EmptyBase
  include CShadow
end

class EBSub_1 < EmptyBase
  shadow_attr_accessor :x => "int x"
end

class EBSub_1_1 < EBSub_1
end

class EBSub_2 < EmptyBase
end

class EBSub_2_2 < EBSub_2
  shadow_attr_accessor :x => "int x"
end


# Base hierarchy tests the following:
#  - inheritance with multiple attributes
#  - omission of readers and writers
#  - accessors with different names than the variables
#  - conflicting accessor names or C variable names
#  - #each_shadow_attr and #shadow_attrs
#  - protected and private attrs

class Base
  include CShadow
  shadow_attr_reader :x => 'int x'
  shadow_attr_writer :y => 'int y'
  shadow_attr_accessor :obj => Array
  shadow_attr_accessor :nonpersistent, :np => Object
end

class Sub_1 < Base
  shadow_attr :z => 'int zzz'
end

# test a class with no shadow_attrs
class Sub_2 < Base
  attr_reader :ruby_reader
  attr_writer :ruby_writer
end

module Mod_For_Sub_3
  class Sub_3 < Base
    # Make sure the nested class name bug isn't biting today.
  end
end

class Sub_4 < Base
  private :x
  protected :y=
end

# OtherBase tests using shadow_library to specify another library
# to put definitions in. OtherFile tests using shadow_library_file
# to put definintions in another file within the same library.

class OtherBase
  include CShadow
  shadow_library Base
  shadow_attr_accessor :str => "char *pchar"
end

class OtherFile < OtherBase
  shadow_library_file "OtherFile"
  shadow_attr_accessor :x => "double x"
end


# Compile-time tests (that is, pre-commit)

class CompileTimeTestCase < Minitest::Test
  def test_conflict
    assert_raises(NameError) {
      Sub_2.class_eval {
        shadow_attr "y" => 'char * yy'
      }
    }
    assert_raises(NameError) {
      Sub_2.class_eval {
        shadow_attr :y => 'char * yy'
      }
    }
    assert_raises(NameError) {
      Sub_2.class_eval {
        shadow_attr :yy => 'char * y'
      }
    }

    # Checking overwrite by attr_*
    assert_raises(NameError) {
      Sub_2.class_eval {
        attr_accessor :y
      }
    }
    assert_raises(NameError) {
      Sub_2.class_eval {
        attr_reader :y
      }
    }
    assert_raises(NameError) {
      Sub_2.class_eval {
        attr_writer :y
      }
    }

    # Checking overwrite by shadow_attr_*
    assert_raises(NameError) {
      Sub_2.class_eval {
       shadow_attr_reader :ruby_writer => Object
      }
    }
    assert_raises(NameError) {
      Sub_2.class_eval {
       shadow_attr_writer :ruby_reader => Object
      }
    }
  end
end

require 'fileutils'
dir = File.join(File.dirname(__FILE__), "tmp", RUBY_VERSION)
FileUtils.mkpath dir
Dir.chdir dir do
  EmptyBase.commit
  Base.commit         # do not commit OtherBase
end

METHOD_MISSING_ERROR =
  RUBY_VERSION.to_f >= 1.7 ?
    NoMethodError :
    NameError

# Run-time tests (that is, post-commit)

class EmptyBaseTestCase < Minitest::Test

  def test_empty_base
    ebs1 = EBSub_1.new
    ebs2 = EBSub_2.new
    ebs11 = EBSub_1_1.new
    ebs22 = EBSub_2_2.new

    ebs1.x = 3
    ebs11.x = 4
    ebs22.x = 5

    assert_raises(METHOD_MISSING_ERROR) {
      ebs2.x = 6
    }

    assert_equal(3, ebs1.x)
    assert_equal(4, ebs11.x)
    assert_equal(5, ebs22.x)
  end

end

class BaseTestCase < Minitest::Test

  def test_limited_access
    b = Sub_1.new

    assert_raises(METHOD_MISSING_ERROR) {
      b.x = 1
    }
    assert_equal(0, b.x)

    b.y = 2
    assert_raises(METHOD_MISSING_ERROR) {
      b.y
    }

    assert_raises(METHOD_MISSING_ERROR) {
      b.z = 3
    }
    assert_raises(METHOD_MISSING_ERROR) {
      b.z
    }
  end

  def test_inherit
    b = Sub_1.new

    # test inheritance of attr initializers
    assert_equal(nil, b.obj)

    # test inheritance of attr dump/load code
    b.obj = [1,2,3]
    assert_equal([1,2,3], Marshal.load(Marshal.dump(b)).obj)
  end
  
  def test_marshal
    b = Base.new
    b.obj = [1, {:foo => "foo"}, "bar"]
    b.instance_eval {@z=3}
    bb = Marshal.load(Marshal.dump(b))
    assert_equal(bb.obj, b.obj)
    assert_equal(bb.instance_eval{@z}, b.instance_eval{@z})
  end

  def test_nonpersistence
    b = Base.new
    assert_equal(nil, b.np)
    b.np = [4,5,6]
    assert_equal([4,5,6], b.np)
    bb = Marshal.load(Marshal.dump(b))
    assert_equal(nil, bb.np)
  end

  def test_protect
    a = Base.new
    b = Sub_4.new
    
    #assert_nothing_raised
    a.x
    a.y = 2
    
    assert_raises(METHOD_MISSING_ERROR) {
      b.x
    }
    assert_raises(METHOD_MISSING_ERROR) {
      b.y = 2
    }
  end

  def test_reflection
    names = Sub_1.shadow_attrs.collect { |attr| attr.var.to_s }.sort
    assert_equal(['np', 'obj', 'x', 'y', 'z'], names)
  end

end

class OtherBaseTestCase < Minitest::Test

  def test_sharing_library
    ob = OtherBase.new
    ob.str = "fred"
    assert_equal("fred", ob.str)

    ob = OtherFile.new
    ob.x = 1.2
    assert_equal(1.2, ob.x)      
  end

end

require 'yaml'

class YamlTest < Minitest::Test

  def test_yaml
    base = Base.new
    base.obj = [1,2,3]
    base.np = "456"
    base.instance_variable_set(:@ivar, "save this too")
    base2 = YAML.load(YAML.dump(base))
    assert_equal(base.obj, base2.obj)
    assert_equal(nil, base2.np)
    assert_equal("save this too", base.instance_variable_get(:@ivar))
  end

end
