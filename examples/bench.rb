# for comparison with RubyInline

require 'cgen'

class MyTest
  def factor
end

Dir.mkdir "tmp" rescue SystemCallError
Dir.chdir "tmp"

MyTest.commit

t = MyTest.new
