$COMPILE = false

if $COMPILE

  require 'cgen/cshadow'

  class MarshalSample
    include CShadow
    shadow_attr_accessor :x => Object, :y => String
    attr_accessor :t
  end

else

  class MarshalSample
    attr_accessor :t
  end
  require './tmp/1.8.1/MarshalSample/MarshalSample'

end

if $COMPILE
  require 'ftools'
  dir = File.join("tmp", RUBY_VERSION)
  File.mkpath dir
  Dir.chdir dir

  MarshalSample.commit
end

ms1 = MarshalSample.new
ms3 = MarshalSample.new

ms1.x = ms3
ms1.t = nil ### removing this line avoids the error
ms3.x = ms1

str = Marshal.dump ms1
copy = Marshal.load str
