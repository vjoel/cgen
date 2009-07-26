class Bug
  attr_accessor :t
end
require 'Bug'

ms1 = Bug.new
ms3 = Bug.new

ms1.x = ms3
ms1.t = nil ### removing this line avoids the error
ms3.x = ms1

str = Marshal.dump ms1
copy = Marshal.load str
