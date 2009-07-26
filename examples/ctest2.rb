require 'cshadow.rb'
require 'misc/irb-session'

class Dummy
  def initialize value
    @value = value
  end
end

class Test2
  include CShadow
  
  shadow_attr_accessor :ary => Dummy
  attr_accessor :x
  
  def initialize
    self.ary = Dummy.new 1
    self.x = Dummy.new 2
  end
end

Dir.mkdir "tmp" rescue SystemCallError
Dir.chdir "tmp"

Test2.commit

t = Test2.new
GC.start

$z = GC.reachability_paths t.x

IRB.start_session([])
