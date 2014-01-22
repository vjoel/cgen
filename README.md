# Overview #

Ruby has a C interface for defining extensions to the language. Using this interface, you define functions in C and add them as methods that are callable from ruby code. You may also define classes, modules, globals, and so on.

CGen is a library that makes it relatively easy to code, build, and load extensions from within a ruby program, rather than using a typical C development process. In this way, the construction of the extension is driven by the ruby program. The extension is also available for execution from the program. CGen is a kind of "inline" tool. 

The CShadow module is for the special case of T_DATA objects, particularly those whose data is defined by a C struct. A class of such objects can be defined only through the ruby C API. Unlike normal ruby objects such as arrays and strings, a T_DATA object contains a "blob" of data that can only be accessed through methods defined in a C extension.

Including the CShadow module in a class lets you define the structure of the data blob by using simple attribute declarations (no C code needed). CShadow uses these declarations to generate the essential functions: accessors with type conversion and checking, mark/free, marshal, yaml, and initialization. Additional methods can be defined in ruby or using CGenerator. CShadow also manages inheritance of the structure from parent class to child class; the child class may define further attributes.

See the CGenerator, CShadow, and CShadow::Attribute pages for details.

# Purpose and history #

The intended use of cgen is managing a complex library that may change from one run of the program to the next. The reason for the change might be that the program is written in a DSL (domain-specific language), and that the library functions are generated based on the statements of the DSL.

In fact, the original use of cgen was to support a DSL for designing and simulating dynamic networks of hybrid automata.[RedShift, formerly hosted at redshift.sourceforge.net, now at http://rubyforge.org/projects/redshift]

Cgen was introduced in 2001 with this post:

http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-talk/24443

# Getting started #

## Installing ##

Cgen is available from http://rubyforge.org/projects/cgen.

Install either as gem:

  gem install cgen

or from tarball, by unpacking and then:

  ruby install.rb config
  ruby install.rb setup
  ruby install.rb install

### System Requirements ###

Cgen is pure ruby, so you don't need a compiler to install it. However, you do need a C compiler to do anything useful with it.

On Unix and GNU/Linux, the gcc compiler works fine. The Sun C compiler has also been tested.

On Windows, you should use a compiler that is compatible with your ruby interpreter. The following compilers have been tested:

* MSVC 6.0 (with the traditional one-click ruby installer--the OCI)
* MSVC 2003
* Mingw32 (gcc; the foundation of the new OCI by Luis Lavena)

# Examples #

The cgen package comes with a substantial examples directory, but it is not yet very well organized. Here are the best ones to start with:

sample.rb::
  introduction to CGenerator

complex.rb::
  introduction to CShadow

matrix.rb::
  second example of CShadow

# Web site #

http://rubyforge.org/projects/cgen
http://cgen.rubyforge.org/

# License #

Ruby license.

# Author #

Copyright 2001-2014, Joel VanderWerf, mailto:vjoel@users.sourceforge.net.
