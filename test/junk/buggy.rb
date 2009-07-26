require 'cgen/cshadow'

if true
  class Buggy
    include CShadow
    shadow_attr_reader :x => 'int x'
    shadow_attr_writer :y => 'int y'
    shadow_attr_accessor :obj => Array
    shadow_attr_accessor :nonpersistent, :np => Object
  end

  require 'ftools'
  dir = File.join("tmp", RUBY_VERSION)
  File.mkpath dir
  Dir.chdir dir

  Buggy.commit

else
  class Buggy; end
  
  dir = File.join("tmp", RUBY_VERSION)
  require File.expand_path(File.join(dir, "Buggy/Buggy.so"))
end

buggy = Buggy.new

buggy.y = 5
p buggy.x
