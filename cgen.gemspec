require 'cgen/cgen'

Gem::Specification.new do |s|
  s.name = "cgen"
  s.version = CGenerator::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0")
  s.authors = ["Joel VanderWerf"]
  s.date = "2013-06-01"
  s.description = "Framework for dynamically generating and loading C extensions and for defining classes in terms of C structs."
  s.email = "vjoel@users.sourceforge.net"
  s.extra_rdoc_files = ["History.txt", "README.md"]
  s.files = Dir[
    "Rakefile",
    "History.txt", "README.md",
    "lib/**/*.rb",
    "examples/*.{rb,txt}",
    "test/*.rb"
  ]
  s.homepage = "http://rubyforge.org/projects/cgen"
  s.rdoc_options = ["--quiet", "--line-numbers", "--inline-source", "--title", "CGenerator", "--main", "README.md"]
  s.require_paths = ["lib"]
  s.rubyforge_project = "cgen"
  s.summary = "C code generator"
end
