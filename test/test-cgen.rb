require 'test/unit'
require 'cgen/cgen'


class BasicTemplateTest < Test::Unit::TestCase

  class BasicTemplate < CGenerator::Template
    accumulator(:acc0, :acc1, :acc2)
    def initialize(*args)
      super
      add 'acc 0 is ', acc0!, 'acc 1 is ', acc1!, 'acc 2 is ', acc2!
    end
  end

  def setup
    @template = BasicTemplate.new
    @template.acc0 "zero", "zippo", "zed"
    @template.acc1 "one", "unity", "uno"
    @template.acc2 "two", "deuce", "brace"
  end
  alias set_up setup

  def test_accumulator
    result = ['acc 0 is ', "zero", "zippo", "zed",
              'acc 1 is ', "one", "unity", "uno",
              'acc 2 is ', "two", "deuce", "brace"].join "\n"
    assert_equal(result, @template.to_s)
  end

end


class CFragmentTest < Test::Unit::TestCase

  class CodeTemplate < CGenerator::CFragment
    accumulator(:decl) {StatementKeyAccumulator}
    accumulator(:block) {BlockAccumulator}
    accumulator(:inner, :outer) {StatementAccumulator}
    def initialize(*args)
      super
      add decl!, block(inner!), outer!
    end
  end

  def setup
    @template = CodeTemplate.new
    @template.decl :i => "int i"
    @template.inner "i = 0"
    @template.outer "f = 1.3"
    @template.decl :f => "float f"
  end
  alias set_up setup

  def test_accumulator
    result = <<-END
      int i;
      float f;
      {
          i = 0;
      }
      f = 1.3;
    END
    result = result.chomp.tabto 0
    assert_equal(result, @template.to_s)
  end

end


class LibraryTest < Test::Unit::TestCase
  class Sample
  end

  ##=== setup code to be done once ===##
  @lib = CGenerator::Library.new "cgen_test_lib"

  @lib.define_c_method(Sample, :add).instance_eval {
    arguments "x", "y"
    returns "rb_float_new(NUM2DBL(x) + NUM2DBL(y))"
  }

  @lib.define_c_singleton_method(Sample, :reverse).instance_eval {
    rb_array_args
    declare :result => "VALUE result"
    reverse_c_name = declare_symbol :reverse
    body "result = rb_funcall(args, #{reverse_c_name}, 0)"
    returns "result"
  }

#    @lib.declare_symbol "just_to_be_unique_#{(Time.now.to_f * 1000).to_i}"

  other_include_file, other_source_file = @lib.add_file "other_file"

  other_source_file.define_c_method(Sample, :sub).instance_eval {
    scope "extern"
    arguments "x", "y"
    returns "rb_float_new(NUM2DBL(x) - NUM2DBL(y))"
  }

  attr_accessor :ba

  @lib.before_commit { @@ba = [1] }
  @lib.before_commit { @@ba << 2 }
  @lib.after_commit  { @@ba << 3 }
  @lib.after_commit  { @@ba << 4 }

  require 'fileutils'
  dir = File.join(File.dirname(__FILE__), "tmp", RUBY_VERSION)
  FileUtils.mkpath dir
  Dir.chdir dir do
    @lib.commit
  end
  ##==================================##

  def test_add
    assert_equal(3, Sample.new.add(1, 2))
#      assert_equal(-1, Sample.new.sub(1, 2))
  end

  def test_reverse
    assert_equal([6, 5, 4], Sample.reverse(4, 5, 6))
  end

  def test_before_after
    assert_equal([1,2,4,3], @@ba)
  end
end
