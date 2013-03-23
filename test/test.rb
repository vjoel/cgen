#!/usr/bin/env ruby

def run(x)
  puts "-"*x.size
  puts x
  system(x)
#  unless system(x)
#    puts " ... failed: #{$?}"
#  end
end

require 'rbconfig'
ruby = RbConfig::CONFIG["RUBY_INSTALL_NAME"]

run "#{ruby} test-cgen.rb"
run "#{ruby} test-cshadow.rb"
run "#{ruby} test-attribute.rb"
