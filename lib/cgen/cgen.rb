require 'rbconfig'
require 'cgen/inherit'

# ==Overview
#
# The CGenerator module is a framework for dynamically generating C
# extensions. It is a bit like Perl's +inline+ but intended for a different
# purpose: managing incremental, structured additions to C source files, and
# compiling the code and loading the library just in time for execution. Whereas
# +inline+ helps you write a C extension, CGenerator helps you write a Ruby
# program that generates C extensions. To put it another way, this is a Ruby
# interface to the Ruby C API. 
#
# The original use of CGenerator was as the back end of a compiler for
# mathematical expressions in C-like syntax involving limited Ruby
# subexpressions. In that case, CGenerator allowed the compiler to think
# about the syntax and semantics of the input expressions without having to
# worry about the high-level structure of the generated .c and .h files.
#
# One potential use is quick-turnaround development and testing of C code,
# possibly using Ruby as a driver environment; the library under construction
# needn't be Ruby-specific. If SWIG didn't support Ruby, this framework could be
# the starting point for a program that generates wrapper code for existing
# libraries. Finally, a Ruby package that includes C extensions could benefit
# from being able to use Ruby code to dynamically specify the contents and
# control the build process during installation.
#
# The CGenerator framework consists of two base classes, Accumulator and
# Template. Think of accumulators as blanks in a form and templates as the form
# around the blanks, except that accumulators and templates can nest within each
# other. The base classes have subclasses which hierarchically decompose the
# information managed by the framework. This hierarchy is achieved by
# inheritance along the +parent+ attribute, which is secondary to subclass
# inheritance.
#
# ==Templates
#
# The main template in the CGenerator module is Library. It has accumulators for
# such constructs as including header files, declaring variables, declaring Ruby
# symbols, declaring classes, defining functions, and defining structs. Some
# accumulators, such as those for adding function and struct definitions, return
# a new template each time they are called. Those templates, in turn, have their
# own accumulators for structure members, function arguments, declarations,
# initialization, scope, etc.
#
# ===Library templates
#
# A Library corresponds to one main C source file and one shared C library (.so
# or .dll). It manages the +Init_library+ code (including registration of
# methods), as well as user-specified declaration and initialization in the
# scope of the .c file and its corresponding .h file. All files generated in the
# process of building the library are kept in a directory with the same name as
# the library. Additional C files in this directory will be compiled and linked
# to the library.
#
# Each library is the root of a template containment hierarchy, and it alone has
# a #commit method. After client code has sent all desired fragments to the
# accumulators, calling the commit method uses the structure imposed by the
# sub-templates of the library to joins the fragments into two strings, one for
# the .h file and one for the .c file. Then each string is written to the
# corresponding file (only if the string is different from the current file
# contents), and the library is compiled (if necessary) and loaded.
#
# ===Function templates
#
# Function templates are used to define the functions in a Library. The base
# class, CGenerator::Function, generates a function (by default, static) in the
# library without registering it with Ruby in any way.
#
# The CGenerator::RubyFunction templates define the function as above and also
# register the function as an instance method, module function, or singleton
# method of a specified class or module, or as a global function (a private
# method of +Kernel+).
#
# Client code does not instantiate these templates directly, but instead uses
# the library's #define accumulator methods, which return the new template.
#
# The function template for the library's initialization function can be
# accessed using the library's #init_library_function method, although direct
# access to this template is typically not needed. (Use the library's #setup
# method to write code to the #init_library_function.)
#
# ===Struct templates
#
# A struct template generates a typedef for a C struct. It can be external, in
# which case it is written to the .h file. It has a #declare accumulator for
# adding data members.
#
# ==Accumulators
#
# Accumulators are a way of defining a hierarchical structure and populating it
# with data in such a way that the data can be serialized to a string at any
# point during the process without side effects. Templates are Accumulators
# which contain other accumulators and have convenience methods for accessing
# them from client code.
#
# Accumulators can be fairly unstructured--they just accumulate in sequence
# whatever is sent to them, possibly with some filtering, which may include
# other accumulators. Templates are usually more more structured. In general,
# only Templates can be parents; other accumulators set the #parent of each
# accumulated item to be the accumulator's #parent, simplifying the #parent
# hierarchy.
#
# Accumulators are responsible for the format of each accumulated item, for
# joining the items to form a string when requested to do so, and for doing any
# necessary preprocessing on the items (e.g., discarding duplicates).
#
# From the point of view of client code, accumulators are methods for "filling
# in the blanks" in templates. Client code doesn't access the accumulator object
# directly, only through a method on the template. For example:
#
#   lib.declare :global_int_array =>
#                 'int global_int_array[100]',
#               :name =>
#                 'char *name'
#
# is used to access the "declare" accumulator of the library (which is actually
# delegated to a file template).
#
# Providing a key for each declaration (in the example, the keys are symbols,
# but they can be any hash keys) helps CGenerator reject repeated declarations.
# (Redundancy checking by simple string comparison is inadequate, because it
# would allow two declarations of different types, but the same name, or two
# declarations with insignificant whitespace differences.)
#
# The basic Accumulator class adds fragments to an array in sequence. When
# converted to a string with #to_s, it joins the fragments with newline
# separators. These behaviors change as needed in the subclasses. <b>Note that
# the accumulated items need not all be strings, they need only respond to
# +to_s+.</b>
#
# Return values of accumulators are not very consistent: in general, an
# accumulator returns whatever is needed for the caller to continue working with
# the thing that was just accumulated. It might be a template which supports
# some other accumulators, or it might be a string which can be inserted in C
# code.
#
# Some accumulators take existing Ruby objects as an argument. These
# accumulators typically return, as a Ruby symbol, the C identifier that has
# been defined or declared to refer to that Ruby object. This can be
# interpolated into C code to refer to the Ruby object from C.
#
# <b>Note about argument order:</b> Since hashes are unordered, passing a hash
# of key-value pairs to #declare or similar methods will not preserve the
# textual ordering. Internally, cgen sorts this hash into an array of pairs so
# that at least the result is deterministic, reducing recompilation. One can
# force an argument order by using an array of pairs.
#
#   lib.declare [[:global_int_array,
#                  'int global_int_array[100]'],
#                [:name =>
#                  'char *name']
#
# Alternately, simply break the declaration into multiple declares.
#
# ==C code output
#
# ===Format
#
# Some effort is made to generate readable code. Relative tabbing within code
# fragments is preserved. One goal of CGenerator is producing Ruby extensions
# that can be saved and distributed with little or no modification (as opposed
# to just created and loaded on the fly).
#
# ===Use of C identifiers
#
# CGenerator attempts to generate C identifiers in non-conflicting ways...
# (prove some nice property)
#
# ==Usage
#
# Create a library with:
#
#   lib = CGenerator::Library.new "my_lib_name"
#
# The name must be an identifier: +/[A-Za-z0-9_]*/+.
#
# It is useful to keep a reference to +lib+ around to send define and declare
# messages to.
#
# ==Example
#
#   require 'cgen'
#
#   lib = CGenerator::Library.new "sample_lib"
#
#   class Point; end
#
#   lib.declare_extern_struct(:point).instance_eval {
#     # make it extern so we can see it from another lib
#     declare :x => "double x"
#     declare :y => "double y"
#   }
#
#   lib.define_c_global_function(:new_point).instance_eval {
#     arguments "x", "y"        # 'VALUE' is assumed
#     declare :p => "point *p"
#     declare :result => "VALUE result"
#         # semicolons are added automatically
#     body %{
#       result = Data_Make_Struct(#{lib.declare_class Point}, point, 0, free, p);
#       p->x = NUM2DBL(x);
#       p->y = NUM2DBL(y);
#
#   //  might want to do something like this, too:
#   //  rb_funcall(result, #{lib.declare_symbol :initialize}, 0);
#     }
#     returns "result"
#         # can put a return statement in the body, if preferred
#   }
#
#   for var in [:x, :y]   # metaprogramming in C!
#     lib.define_c_method(Point, var).instance_eval {
#       declare :p => "point *p"
#       body %{
#         Data_Get_Struct(self, point, p);
#       }
#       returns "rb_float_new(p->#{var})"
#     }
#   end
#
#   # A utility function, available to other C files
#   lib.define_c_function("distance").instance_eval {
#     arguments "point *p1", "point *p2"
#     return_type "double"
#     scope :extern
#     returns "sqrt(pow(p1->x - p2->x, 2) + pow(p1->y - p2->y, 2))"
#     include "<math.h>"
#     # The include accumulator call propagates up the parent
#     # hierarchy until something handles it. In this case,
#     # the Library lib handles it by adding an include
#     # directive to the .c file. This allows related, but
#     # separate aspects of the C source to be handled in
#     # the same place in the Ruby code. We could also have
#     # called include directly on lib.
#   }
#
#   lib.define_c_method(Point, :distance).instance_eval {
#     # no name conflict between this "distance" and the previous one,
#     # because "method" and "Point" are both part of the C identifier
#     # for this method
#     arguments "other"
#     declare :p => "point *p"
#     declare :q => "point *q"
#     body %{
#       Data_Get_Struct(self, point, p);
#       Data_Get_Struct(other, point, q);
#     }
#     returns "rb_float_new(distance(p, q))"
#   }
#
#   lib.commit # now you can use the new definitions
#
#   p1 = new_point(1, 2)
#   puts "p1: x is #{p1.x}, y is #{p1.y}"
#
#   p2 = new_point(5, 8)
#   puts "p2: x is #{p2.x}, y is #{p2.y}"
#
#   puts "distance from p1 to p2 is #{p1.distance p2}"
#
# Output is:
#
#   p1: x is 1.0, y is 2.0
#   p2: x is 5.0, y is 8.0
#   distance from p1 to p2 is 7.211102551  
#
# That's a lot of code to do a simple operation, compared with an Inline-style
# construct. CGenerator's value shows up with more complex tasks. The
# +sample.rb+ file extends this example.
#
# ==Notes
#
# * My first Ruby extension was built with this module. That speaks well of the
# elegance, simplicity, and utter coolness of Ruby and its extension
# architecture. Thanks matz!
#
# * Some accumulators, like declare_symbol and declare_class, operate by default
# on the file scope, even if called on a method definition, so the declarations
# are shared across the library. This reduces redundancy with no disadvantage.
# (In general, accumulator calls propagate first thru the inheritance hierarchy
# and then thru the parent Template hierarchy.)
#
# * Note that accumulators can nest within accumulators, because #to_s is
# applied recursively. This is *very* useful (see Library#initialize for
# example). This defines a many-to-one dataflow pattern among accumulators. A
# one-to-many dataflow pattern arises when a method calls several accumulators,
# as in #define_c_method and kin.
#
# * CGenerator makes no attempt to check for C syntax errors in code supplied to
# the accumulators.
#
# * It may help to think of templates as heterogeneous collections, like
# structs, and accumulators as homogeneous collections, like arrays.
#
# * The containment hierarchy is represented by the #parent accessor in
# Accumulators and Templates. It provides a secondary inheritance of calls to
# accumulators. (As a result, doing #include at the function level adds an
# #include directive at the file level.)
#
# * The basic Template and Accumulator class are more general than C source, or
# even strings. The Module#inherit method is also reusable.
#
# * CGenerator does not allow more than one C function with the same name. This
# could be changed fairly easily.
#
# * You can subclass Library and override #extconf to do more complex processing
# than just #create_makefile.
#
# * Calling a #to_s method on an accumulator more than once has no unexpected
# side effects. It can be called at any time for a snapshot of the whole library
# or of a subtemplate.
#
# * CGenerator is probably not very efficient, so it may not be useful with
# large amounts of C code.
#
# * Library#commit will try to commit even if already comitted (in which case it
# raises a CommitError) or if the lib is empty. Use #committed? and #empty? to
# check for these cases. (Should these checks, or just the latter, be
# automatic?)
#
# * Library#commit first reads the .c and .h file and checks for changes. If
# there are none, it doesn't write to the file. If neither file gets written to,
# make won't need to compile them...
#
# * CGenerator generates header file entries for any non-static functions or
# data. This can be used for communication between files in the library without
# using Ruby calls, and to provide an API for other C libraries and executables.
#
# * Accumulator#inspect is a nice hierarchy-aware inspector.
#
# ==To do
#
# * Automatically generate inner and outer functions as in Michael Neumann's
# cplusruby. Similarly, should there be another field to refer to a struct of
# function pointers, so that C code can call the inner functions without
# funcall?
#
# * Try CFLAGS for optimization: with gcc, -march, -O3, -fomit-frame-pointer
#
# * Rename to something less generic (cgen --> "sagehen"?)
#
# * Option to target ruby/ext dir: generate MANIFEST file, but no Makefile. What
# about depend? how to generate it in installation-independent format?
#
# * Let user set dir to build in, rather than rely on chdir, which is not thread
# safe.
#
# * Instead of using an external program to makedepend, do it manually based on
# include operations? (Might have to do this anyway on mswin.)
#
# * Investigate Tiny C--Linux only, but fast, and libtcc allows dynamic codegen.
# Maybe best used in "develop" mode, rather than for production code (no -O).
#
# * Option in define_c_method to make method private/protected (see
# rb_define_private/protected_method in intern.h).
#
# * Optimization: declare_symbol and declare_module should do less work if the
# declaration has already neen done.
#
# * Macros, e.g. something for rb_funcall that does the declare_class for you.
#
# * Extend c_array_args features to rb_array_args and fixed length arglists.
#
# * Exception if modify descendant of Library after committed. Accumulators
# always notify parent before admitting any changes.
#
# * Freeze data structures after commit?
#
# * More wrappers: define_class, globals (in C and in Ruby), funcalls,
# iterators, argument type conversion, etc. Really, all of Chapter 17 of Thomas
# & Hunt.
#
# * Make commit happen automatically when the first call is made to a method in
# the library. (Use alias, maybe, since method_missing won't work--won't let you
# override.)
#
# * Finer granularity in accumulators. For example, #init could take a (lvalue,
# rvalue) pair, which would allow it to detect initialization of the same var
# with different values.
#
# * make this into Inline for ruby:
#
# Module#define_c_method ("name") { ... }
#
# (use instance_eval, so that accumulators can be used in the block?) The main
# drawback is that no Library is specified, so where does it go? (Actually,
# CShadow solves this problem, if you don't mind having a struct as overhead.)
#
# * investigate unloading a .so/.dll. Or: maybe rb_define_* can be called again,
# but in a different library (append version number to the lib name, but not to
# the dir name). See Ruby/DL in RAA. (See dln.c, eval.c, ruby.c in ruby source.
# It all seems possible, but a bit of work.)
#
# * parser/generator for (at first) simple ruby code, like '@x.y': one option
# would be to use init to define a Proc and use setup to call the Proc
#
# * check ANSI, check w/ other compilers
#
# * Improve space recognition in the tab routines (check for \t and handle
# intelligently, etc.).
#
# * Formalize the relation between templates and accumulators. Make it easier
# for client code to use its own templates and accumulators.
#
# * Double-ended accumulators (add_at_end vs. add_at_beginning, or push vs.
# unshift).
#
# * Automatically load/link other dynamic or static libs in the same dir. For
# static, use 'have_library' in #extconf; see p.185 of pickaxe. For dynamic, use
# Ruby/DL from RAA, or just require. (Currently, this can be done manually by
# subclassing and overriding extconf.)
#
# * More thorough checking for assert_uncommitted. Currently, just a few
# top-level methods (Library#commit and some of the define methods) check if the
# library has already been committed. Ideally, #commit would freeze all
# accumulators. But then the problem is how to report a freeze exception in a
# way that makes clear that the problem is really with commit.
module CGenerator

VERSION = '0.16.8'

class Accumulator ## should be a mixin? "Cumulative"?

## should delegate Accs into two objects with two inheritance hierarchies,
## one for adding items, one for generating strings
##OR:
## two hierarchies of modules that get included into Template subclasses

  attr_reader :name, :parent
  
  def initialize name, parent = nil
    @name = name; @parent = parent
    @pile = []
  end
  
  def accept? item
    true
  end

  def add_one_really item
    @pile << item
  end

  def add_one item
    add_one_really item if accept? item
  end

  def add(*items)
    for item in items
      add_one item
    end
  end
  
  def output_one item
    item
  end
  
  def output items
    items.collect { |item|
      output_one item
    }.select { |item|
      item && item != ""
    }
  end
  
  def separator; "\n"; end

  def to_s
    output(@pile).join(separator)
  end
  
  def inspect
    eol = "\n" if @pile.size > 0
    s = "s" if @pile.size != 1
    %{<#{self.class} "#{@name}": #{@pile.size} item#{s}>#{eol}} +
    @pile.collect { |item| inspect_one item }.join("\n").tabto(2)
  end
  
  def inspect_one item
    item.inspect
  end
  
end # class Accumulator

module SetAccumulator
  def accept? item
    not @pile.include? item
  end
end

module KeyAccumulator
  def initialize(*args)
    super
    @hash = {}  # @pile maintains ordered list of keys for @hash
  end
  
  def add_one item
## why not do this?
#    unless item.is_a? Hash
#      raise ArgumentError,
#        "Tried to add non-hash '#{item}' to KeyAccumulator."
#    end
    
    item = item.sort_by {|k,v| k.to_s} unless item.is_a?(Array)
    
    for key, value in item
      if not @hash.has_key? key
        super key
      end
      @hash[key] = value_filter(value)
    end
  end
  
  def value_filter(value)
    value
  end
  
  def output_one item
    super @hash[item]
  end
  
  def inspect_one item
    @hash[item].inspect
  end
  
  def [](item)
    @hash[item]
  end
end

# All templates respond to #library and #file methods, which return the library
# or file object which contains the template. (The library itself does not
# respond to #file.) They also respond to #name and #parent.
class Template < Accumulator

  def initialize name = "", parent = nil, &block
    super
    instance_eval(&block) if block
    ## not very useful: users call an accumulator, rather than Template#new
  end
  
  def Template.accumulator(*names)
    kind = if block_given? then yield else Accumulator end
    
    for name in names
    
      module_eval %{
        def #{name}(*items)
          #{name}!.add(*items)
        end
        def #{name}!
          @#{name} ||= #{kind}.new(:#{name}, self)
        end
      }
      
      unless Template.respond_to? name
        Template.inherit :@parent, name
      end
      
    end
    
  end
  
end # class Template


class Library < Template
  
  class CommitError < RuntimeError; end
  
  # Returns a Function template object. This function is called when the library
  # is loaded. Method definitions put stuff here to register methods with Ruby.
  # Usually, there is no need to bother this guy directly. Use Library#setup
  # instead.
  attr_reader :init_library_function
  
  # Returns the template for the main include file of the library.
  # Usually, there is no need to access this directly.
  attr_reader :include_file
  
  # Returns the template for the main source file of the library.
  # Usually, there is no need to access this directly.
  attr_reader :source_file
  
  attr_accessor :show_times_flag
  
  # The #purge_source_dir attribute controls what happens to .c, .h, and .o
  # files in the source dir of the library that are not among those generated as
  # part of the library. If this is set to +:delete+, then those files are
  # deleted. Other true values cause the .c, .h, and .o files to be renamed with
  # the .hide extension. (Note that this makes it difficult to keep manually
  # written C files in the same dir.) False +flag+ values (the default) cause
  # CGen to leave the files untouched.
  #
  # Note that, regardless of this setting, #mkmf will construct a Makefile which
  # lists all .c files that are in the source dir. If you do not delete obsolete
  # files, they will be compiled into your library!
  attr_accessor :purge_source_dir
  
  # Array of dirs which will be searched for extra include files. Example:
  #   lib.include_dirs << "/home/me/include"
  attr_reader :include_dirs

  def initialize name
    super name
    
    @show_times_flag = @purge_source_dir = false
    @committed = false
    @source_file = nil
    @include_dirs = []
    
    @rtime = Time.now.to_f
    @ptime = process_times

    unless name =~ /\A[A-Za-z_]\w*\z/
      raise NameError,
        "\n  Not a valid library name: '#{name}'." +
        "\n  Name must be a C identifier."
    end
    
    @include_file, @source_file = add_file "libmain"
    @include_file.include '<ruby.h>'
    
    @init_library_function = define_c_function "Init_" + name
    @init_library_function.scope :extern
    
    @init_library_function.body     \
        rb_define_method!,
        rb_define_module_function!,
        rb_define_global_function!,
        rb_define_singleton_method!,
        rb_define_alloc_func!
      ## odd, putting an accum inside
      ## a template which is not the parent
  end
  
  # Changes into +dir_name+, creating it first if necessary. Does nothing if
  # already in a directory of that name. Often used with +"tmp"+.
  def use_work_dir dir_name
    if File.basename(Dir.pwd) == dir_name
      yield
    else
      require 'fileutils'
      FileUtils.makedirs dir_name
      Dir.chdir dir_name do
        yield
      end
    end
  end

  # Creates templates for two files, a source (.c) file and an include (.h) file
  # that will be generated in the same dir as the library. The base file name is
  # taken from the argument. Returns an array containing the include file
  # template and the source file template, in that order.
  #
  # Functions can be added to the source file by calling #define_method and
  # similar methods on the source file template. Their +rb_init+ calls are done
  # in
  # #init_library_function in the main library source file. The new source file
  # automatically #includes the library's main header file, as well as its own
  # header file, and the library's main source file also #includes the new
  # header file. Declarations can be added to the header file by calling
  # #declare on it, but in many cases this is taken care of automatically.
  def add_file name, opts = {}
    pair = @pile.detect {|p| p[0].name == name + ".h"}

    if not pair
      new_include_file = CFile.new name + ".h", self
      new_source_file = CFile.new name + ".c", self, new_include_file

      if @source_file
        new_source_file.include @include_file unless opts[:independent]
        @source_file.include new_include_file
      end
      new_source_file.include new_include_file

      pair = [new_include_file, new_source_file]
      add pair     # for inspect and commit
    end
    
    return pair
  end
  
  def assert_uncommitted
    if @committed
      raise CommitError, "\nLibrary #{@name} has already been committed."
    end
  end
  
  # True if the library has been committed.
  def committed?
    @committed
  end
  
  # True if no content has been added to the library.
  def empty?
    @init_library_function.empty?  ## is this enough?
  end
  
  # Schedules block to run before Library#commit. The before blocks are run in
  # the same order in which they were scheduled; the after blocks run in the
  # reverse order (analogously with +BEGIN+/+END+). Each block is evaluated in
  # the context in which it was created (instance_eval is *not* used), and it is
  # passed the library as an argument.
  def before_commit(&block)
    (@before_commit ||= []) << block
  end
  
  # Schedules block to run after Library#commit. The before blocks are run in
  # the same order in which they were scheduled; the after blocks run in the
  # reverse order (analogously with +BEGIN+/+END+). Each block is evaluated in
  # the context in which it was created (instance_eval is *not* used), and it is
  # passed the library as an argument.
  def after_commit(&block)
    (@after_commit ||= []) << block
  end
  
  # Writes the files to disk, and makes and loads the library.
  #
  # Note that #commit must be called after all C code definitions for the
  # library, but before instantiation of any objects that use those definitions.
  # If a definition occurs after commit, or if instantiation occurs before
  # commit, then a CGenerator::Library::CommitError is raised, with an
  # appropriate message. Sometimes, this forces you to use many small libraries,
  # each committed just in time for use. See examples/fixed-array.rb.
  def commit(build = true)
    assert_uncommitted
    
    while @before_commit
      bc = @before_commit; @before_commit = nil
      bc.each {|block| block[self]}
    end

    @committed = true

    if build
      @logname ||= "make.log"

      show_times "precommit"       
      show_times "write"       do write       end
      show_times "makedepend"  do makedepend  end
      show_times "mkmf"        do mkmf        end
      show_times "make"        do make        end
    end
    
    show_times "loadlib"     do loadlib     end

    while @after_commit
      ac = @after_commit; @after_commit = nil
      ac.reverse.each {|block| block[self]}
    end
  end
  
  #----------------
  # :section: Build methods
  #
  # Methods used during commit to control the build chain.
  # In sequence, #commit calls these methods:
  #
  #   * #write       dumps each file template to disk, if needed
  #   * #makedepend  executes +makedepend+
  #   * #mkmf        calls Library#extconf
  #   * #make        executes the system's +make+ program
  #   * #loadlib     load the library that has been built
  #
  # These methods can be overridden, but are more typically called via commit or
  # sometimes directly. The argument to #make is interpolated into the system
  # call as a command line argument to the +make+ program. If the argument is
  # 'clean' or 'distclean' then the make log is deleted; if the argument is
  # 'distclean' then all .c and .h files generated by #write are deleted
  # (additional user-supplied .c and .h files in the library dir are not
  # affected).
  #----------------
  
  def process_times
    RUBY_VERSION.to_f >= 1.7 ? Process.times : Time.times
  end

  # If the attribute #show_times_flag is set to true, print the user and system
  # times (and child user and child system on some platforms) and real time for
  # each major step of the commit process. Display +message+.
  def show_times message
    yield if block_given?
    if @show_times_flag
      unless @show_times_started
        printf "\n%20s %6s %6s %6s %6s %7s\n",
          "__step__", "utime", "stime", "cutime", "cstime", "real"
        @show_times_started = true
      end
      ptime = self.process_times
      rtime = Time.now.to_f
      printf "%20s %6.2f %6.2f %6.2f %6.2f %7.3f\n", message,
        ptime.utime - @ptime.utime, ptime.stime - @ptime.stime,
        ptime.cutime - @ptime.cutime, ptime.cstime - @ptime.cstime,
        rtime - @rtime
      @ptime = ptime
      @rtime = rtime
    end
  end
  
  def write
    build_wrapper do
      templates = @pile.flatten.sort_by { |t| t.name }
      
      if @purge_source_dir
        # hide or delete files not listed in templates
        files = Dir["*.{c,h,o}"]
        template_files = templates.map { |t| t.name }
        template_files += 
          template_files.grep(/\.c$/).map { |f| f.sub(/\.c$/, ".o") }
        for file in files - template_files
          if @purge_source_dir == :delete
            File.delete(file) rescue SystemCallError
          else
            File.rename(file, file + ".hide") rescue SystemCallError
          end
        end
      end
      
      for template in templates do
        begin
          File.open(template.name, 'r+') {|f| update_file f, template}
        rescue SystemCallError
          File.open(template.name, 'w+') {|f| update_file f, template}
        end
      end
    end
  end
  
  # Called by write on each .c and .h file to actually write +template+ to the
  # open file +f+. The default behavior is to compare the existing data with the
  # generated data, and leave the file untouched if nothing changed. Subclasses
  # may have more efficient ways of doing this. (For instance, check a version
  # indicator in the file on disk, perhaps stored using the file's preamble
  # accumulator. It is even possible to defer some entries in the template until
  # after this check has been made: code that only needs to be regenerated if
  # some specification has changed)
  def update_file f, template
    template_str = template.to_s
    file_data = f.gets(nil) ## sysread is faster?
    unless file_data == template_str
      if defined?($CGEN_VERBOSE) and $CGEN_VERBOSE
        print_update_reason(template, template_str, file_data)
      end
      f.rewind
      f.print template_str
      f.truncate f.pos
    end
  end
  
  def print_update_reason template, template_str, file_data
    puts "\nUpdating file #{template.name}"
    
    if file_data == nil
      puts "File on disk is empty"
      return
    end
    
    s = file_data
    t = template_str
    slines = s.split "\n"
    tlines = t.split "\n"
    i = 0
    sline = slines[i]
    tline = tlines[i]
    catch :done do
      while sline and tline
        if sline != tline
          puts "Line #{i+1}",
               "On disk:    #{sline.inspect}",
               "In memory:  #{tline.inspect}",
               ""
          throw :done
        end
        i += 1
        sline = slines[i]
        tline = tlines[i]
      end
      if sline == nil and tline == nil
        puts "Very strange, no difference found!"
      else
        if slines.size > tlines.size
          puts "file on disk is longer"
        else
          puts "file in memory is longer"
        end
      end
    end
  end
  
  def makedepend
    return if /mswin/i =~ RUBY_PLATFORM ## what else can we do?
    build_wrapper do
      cpat = "*.c"
      chpat = "*.[ch]"
      dep = "depend"
      return if Dir[cpat].all? {|f| test ?<, f, dep}
      
      cfg = RbConfig::CONFIG
      dirs = [cfg["sitearchdir"], cfg["archdir"], cfg["includedir"], *include_dirs]
      
      case cfg["CC"]
      when /gcc/
        makedepend_cmd =
          "#{cfg["CC"]} -MM #{cpat} -I#{dirs.join " -I"} >#{dep} 2>#{@logname}"
      
      else
        makedepend_cmd =
          "touch #{dep} && \
          makedepend -f#{dep} #{cpat} -I#{dirs.join " -I"} >#{@logname} 2>&1"
      end

      result = system makedepend_cmd

      unless result
        log_data = File.read(@logname) rescue nil
        msg = "\n  `#{makedepend_cmd}` failed for #{@name}."
        if log_data
          msg <<
            "\n  Transcript is saved in #{@name}/#{@logname} and follows:" +
            "\n  " + "_" * 60 +
            "\n" + log_data.tabto(3).gsub(/^  /, " |") +
            "  " + "_" * 60 + "\n"
        else
          msg <<
            "\n  No log available.\n"
        end
        raise CommitError, msg
      end
    end
  end

  def mkmf
    need_to_make_clean = false
    
    # Need to do this in a separate process because mkmf.rb pollutes
    # the global namespace.
    build_wrapper do
      require 'rbconfig'
      ruby = RbConfig::CONFIG["RUBY_INSTALL_NAME"]
      
      old_contents = File.read("extconf.rb") rescue nil
      contents = extconf
      require 'stringio'
      s = StringIO.new
      s.puts(contents)
      s.rewind
      contents = s.read
      
      if old_contents != contents
        File.open("extconf.rb", "w") do |f|
          f.puts contents
        end
        need_to_make_clean = true
      end
      
      ## it would be better to capture the output of extconf.rb before
      ## it writes it to Makefile, but mkmf.rb is not written that way :(
      if File.exist?("Makefile")
        old_makefile = File.read("Makefile")
        require 'fileutils'
        FileUtils.mv("Makefile", "Makefile.old")
      end
      
      system %{
        #{ruby} extconf.rb > #{@logname}
      }
      
      if old_makefile and old_makefile == File.read("Makefile")
        FileUtils.rm("Makefile")
        FileUtils.mv("Makefile.old", "Makefile")
      end
    end
    
    make "clean" if need_to_make_clean
  end
  
  ## use -j and -l make switches for multiprocessor builds (man sysconf)
  ## see http://www.gnu.org/manual/make/html_chapter/make_5.html#SEC47
  def make arg = nil
    build_wrapper do
      unless system "#{make_program} #{arg} >>#{@logname} 2>&1"
        raise CommitError,
          "\n  Make #{arg} failed for #{@name}." +
          "\n  Transcript is saved in #{@name}/#{@logname} and follows:" +
          "\n  " + "_" * 60 +
          "\n" + File.read(@logname).tabto(3).gsub(/^  /, " |") +
          "  " + "_" * 60 + "\n"
      end
      
      if arg == 'clean' or arg == 'distclean'
        File.delete(@logname) rescue SystemCallError
        if arg == 'distclean'
          for template in @pile.flatten do
            File.delete(template.name) rescue SystemCallError
          end
        end
      end
    end
  end
  
  def make_program
    case RUBY_PLATFORM
    when /mswin/i
      "nmake"
    when /mingw/i
      "make"
      # "mingw32-make" is the MSYS-independent, MSVC native version
      # which is supposedly less useful
    else
      "make"
    end
  end
  
  def build_wrapper
    if File.exists? @name
      unless File.directory? @name
        raise CommitError, "Library #{@name}: Can't mkdir; file exists."
      end
    else
      Dir.mkdir @name
    end
    
    Dir.chdir @name do yield end
      ### this is fragile--should record abs path when Lib is created
  end
  
  # Override #extconf if you want to do more than just #create_makefile. Note
  # that #create_makefile recognizes all .c files in the library directory, and
  # generates a makefile that compiles them and links them into the dynamic
  # library.
  #
  # Yields the array of lines being constructed so that additional configuration
  # can be added. See the ruby documentation on mkmf.
  def extconf # :yields: lines_array
    a = []
    a << "require 'mkmf'"
    a << "$CFLAGS = \"#$CFLAGS\"" if defined?($CFLAGS)
    include_dirs.each do |dir|
      a << %{$INCFLAGS << " -I#{dir}"}
    end
    yield a if block_given?
    a << "create_makefile '#{@name}'"
  end
  
  def loadlib
    require File.join(".", @name, @name)
  rescue ScriptError, StandardError => e
    raise e.class, "\nCgen: problem loading library:\n" + e.message
  end
    
  class RbDefineAccumulator < Accumulator
    def add spec
      c_name  = spec[:c_name]
      mod     = spec[:mod]
      rb_name = spec[:rb_name]
      cfile   = spec[:cfile]
      
      meth_rec =
        if c_name
          @pile.find { |s| s[:c_name] == c_name }
        else
          @pile.find { |s| s[:mod] == mod and s[:rb_name] == rb_name }
        end
      
      if meth_rec
        meth_rec.update spec
      else
        meth_rec = spec
        
        unless rb_name
          raise ArgumentError, "define: must provide method name."
        end
        
        kind = @name.to_s.sub(/\Arb_define_/, "")
        if mod
          meth_rec[:mod_c_name] ||= @parent.declare_module(mod, cfile)  ## @parent ?
          meth_rec[:c_name] ||=
            ("#{CGenerator::make_c_name rb_name}" +
             "_#{meth_rec[:mod_c_name]}_#{kind}").intern
        else
          meth_rec[:c_name] ||=
            "#{CGenerator::make_c_name rb_name}_#{kind}".intern
        end
        meth_rec[:argc] ||= 0
        @pile << meth_rec
      end
      
      meth_rec[:c_name]
    end
    
    def to_s
      @pile.collect { |m|
        rb_name = m[:rb_name]
        c_name  = m[:c_name]
        argc    = m[:argc]
        if m[:mod]
          mod_c_name = m[:mod_c_name]
          "#{@name}(#{mod_c_name}, \"#{rb_name}\", #{c_name}, #{argc});"
        else
          "#{@name}(\"#{rb_name}\", #{c_name}, #{argc});"
        end
      }.join "\n"
    end
    
  end # class RbDefineAccumulator
  
  accumulator(:rb_define_method,
              :rb_define_module_function,
              :rb_define_global_function,
              :rb_define_singleton_method) {RbDefineAccumulator}

  class RbDefineAllocAccumulator < Accumulator
    def add spec
      klass = spec[:class]
      cfile = spec[:cfile]
      
      if @pile.find {|s| s[:class] == klass}
        raise ArgumentError, "Duplicate alloc func definition for #{klass}"
      end

      klass_c_name =
        spec[:class_c_name] ||= @parent.declare_class(klass, cfile) ## @parent ?
      spec[:c_name] ||= "alloc_func_#{klass_c_name}".intern
      @pile << spec
      
      spec[:c_name]
    end
    
    def to_s
      @pile.collect { |spec|
        c_name        = spec[:c_name]
        klass_c_name  = spec[:class_c_name]
        "rb_define_alloc_func(#{klass_c_name}, #{c_name});"
      }.join "\n"
    end
  end # class RbDefineAllocAccumulator
  
  accumulator(:rb_define_alloc_func) {RbDefineAllocAccumulator}
  
  # call-seq:
  #   define_c_method mod, name, subclass
  #   define_c_module_function mod, name, subclass
  #   define_c_global_function name, subclass
  #   define_c_singleton_method mod, name, subclass
  #   define_c_class_method mod, name, subclass
  #
  # Defines a function of the specified name and type in the given class/module
  # (or in the global scope), and returns the function template (often used with
  # #instance_eval to add arguments, code, etc.). The +subclass+ argument is
  # optional and allows the template to belong to a subclass of the function
  # template it would normally belong to.
  #
  # For example,
  #
  #   define_c_method String, "reverse"
  #
  # The arguments accepted by the method automatically include +self+. By
  # default, arguments are passed as individual C arguments, but the can be
  # passed in a Ruby or C array. The latter has the advantage of argument
  # parsing (based on rb_scan_args), defaults, and typechecking. See
  # Method#c_array_args. #define_c_class_method is just an alias for
  # #define_c_singleton_method.
  #
  def define_c_method(*args)
    @source_file.define_c_method(*args)
  end
  
  # See #define_c_method.
  def define_c_module_function(*args)
    @source_file.define_c_module_function(*args)
  end
  
  # See #define_c_method.
  def define_c_global_function(*args)
    @source_file.define_c_global_function(*args)
  end
  
  # See #define_c_method.
  def define_c_singleton_method(*args)
    @source_file.define_c_singleton_method(*args)
  end
  alias define_c_class_method define_c_singleton_method
  
  # call-seq:
  #   include "file1.h", "<file2.h>", ...
  #
  # Insert the include statement(s) at the top of the library's main .c file.
  # For convenience, <ruby.h> is included automatically, as is the header file
  # of the library itself.
  def include(*args)
    @source_file.include(*args)
  end
  
  # call-seq:
  #   declare :x => "int x", ...
  #   declare_extern :x => "int x", ...
  #
  # Puts the string in the declaration area of the .c or .h file, respectively.
  # The declaration area is before the function definitions, and after the
  # structure declarations.
  def declare(*args)
    @source_file.declare(*args)
  end
  alias declare_static declare
  
  def declare_extern(*args)
    @include_file.declare(*args)
  end
  
  # call-seq:
  #   declare_struct name, attributes=nil
  #   declare_extern_struct name, attributes=nil
  #
  # Returns a Structure template, which generates to a typedefed C struct in the
  # .c or .h file. The #declare method of this template is used to add members.
  def declare_struct struct_name, *rest
    @source_file.declare_struct struct_name, *rest
  end
  alias declare_static_struct declare_struct
  
  # See #declare_struct.
  def declare_extern_struct struct_name, *rest
    @include_file.declare_struct struct_name, *rest
  end
  
  # call-seq:
  #   define_c_function  
  #
  # Defines a plain ol' C function. Returns a Function template (see below), or
  # a template of the specified +type+, if given.
  def define(*args)
    @source_file.define(*args)
  end
  alias define_c_function define
  
  # call-seq:
  #   declare_class cl
  #   declare_module mod
  #   declare_symbol sym
  #
  # Define a C variable which will be initialized to refer to the class, module,
  # or symbol. These accumulators return the name of the C variable which will
  # be generated and initialized to the ID of the symbol, and this return value
  # can be interpolated into C calls to the Ruby API. (The arguments are the
  # actual Ruby objects.) This is very useful in #rb_ivar_get/#rb_ivar_set
  # calls, and it avoids doing the lookup more than once:
  #
  #   ...
  #   declare :my_ivar => "VALUE my_ivar"
  #   body %{
  #     my_ivar = rb_ivar_get(shadow->self, #{declare_symbol :@my_ivar});
  #     rb_ivar_set(shadow->self, #{declare_symbol :@my_ivar}, Qnil);
  #   }
  #
  # The second declaration notices that the library already has a variable that
  # will be initialized to the ID of the symbol, and uses it.
  def declare_module mod, cfile = nil
    c_name = "module_#{CGenerator::make_c_name mod.to_s}"
    declare mod => "VALUE #{c_name}"
    (cfile || self).declare_extern mod => "extern VALUE #{c_name}"
    setup mod => "#{c_name} = rb_path2class(\"#{mod}\")"
    c_name.intern
  end
  alias declare_class declare_module
  
  # See #declare_module.
  def declare_symbol sym, cfile = nil
    c_name = "ID_#{CGenerator::make_c_name sym}"
    declare sym => "ID #{c_name}"
    (cfile || self).declare_extern sym => "extern ID #{c_name}"
    setup sym => "#{c_name} = rb_intern(\"#{sym}\")"
    c_name.intern
  end
  
  # Like Library#declare_symbol, but converts the ID to a VALUE at library
  # initialization time. Useful for looking up hash values keyed by symbol
  # objects, for example. +sym+ is a string or symbol.
  def literal_symbol sym, cfile = nil
    c_name = "SYM_#{CGenerator::make_c_name sym}"
    declare sym => "VALUE #{c_name}"
    (cfile || self).declare_extern sym => "extern VALUE #{c_name}"
    setup sym => "#{c_name} = ID2SYM(rb_intern(\"#{sym}\"))"
    c_name.intern
  end
  
  # call-seq:
  #   setup key => "statements", ...
  #
  # Inserts code in the #init_library_function, which is called when the library
  # is loaded. The +key+ is used for redundancy checking, as in the #declare
  # accumulators. Note that hashes are unordered, so constructs like
  #
  #    setup :x => "...", :y => "..."
  #
  # can result in unpredictable order. To avoid this, use several #setup calls.
  def setup(*args)
    @init_library_function.setup(*args)
  end

  Template.inherit :parent,
    :declare_module, :declare_symbol,
    :declare_static, :declare_extern,
    :declare_class, :declare_module,
    :literal_symbol,
    :library, :file,
    :assert_uncommitted
  
  def library
    self
  end
  
end # class Library


class CFragment < Template
  
  class StatementAccumulator < Accumulator
    def add_one_really item
      if item.kind_of? String
        super item.tabto(0)
      else
        super
      end
    end
    
    def output_one item
      case item
      when Array
        str = item.join("") ## 1.9 compatibility
      else
        str = item.to_s
      end
#      if str =~ /(?:\A|[;}])\s*\z/
      if str.empty? or str =~ /[\s;}]\z/ or str =~ /\A\s*(?:\/\/|#)/
        str
      else
        str + ';'
      end
    end
  end
  
  class StatementKeyAccumulator < StatementAccumulator
    include KeyAccumulator
    def value_filter(value)
      if value.kind_of? String
        super value.tabto(0)
      else
        super
      end
    end
  end
  
  class BlockAccumulator < StatementAccumulator
    def add(*args)
      super
      return self
    end
    def to_s
      ["{", super.tabto(4), "}"].join "\n"
    end
  end
  
  class SingletonAccumulator < Accumulator
    def add_one item
      @pile = [item]
    end
  end
  
end # class CFragment


# File templates are managed by the Library, and most users do not need to
# interact with them directly. They are structured into four sections: includes,
# structure declarations, variable and function declarations, and function
# definitions. Each source file automatically includes its corresponding header
# file and the main header file for the library (which includes ruby.h). The
# main source file for the library includes each additional header file.
#
# The File#preamble accumulator wraps its input in C comments and places it at
# the head of the source file.
class CFile < CFragment
  
  attr_reader :include_file
  
  def initialize name, library, include_file = nil, bare = !!include_file
    super name, library
    @include_file = include_file
    if bare
      add preamble!, include!, declare!, define!
    else
      ## it's a little hacky to decide in this way that this is a .h file
      sym = name.gsub(/\W/, '_')
      add "#ifndef #{sym}\n#define #{sym}",
          preamble!, include!, declare!, define!,
          "#endif"
    end
  end
  
  def separator
    "\n\n"
  end
  
  class FunctionAccumulator < Accumulator
  
    def add name, kind = Function
      @parent.assert_uncommitted
      name = name.intern if name.is_a? String
      
      if kind.is_a? Symbol or kind.is_a? String
        kind = eval "CGenerator::#{kind}"
      end
      
      unless kind <= Function
        raise ArgumentError,
          "#{kind.class} #{kind} is not a subclass of CGenerator::Function."
      end
      
      fn = @pile.find { |f| f.name == name }
      unless fn
        fn = kind.new name, @parent
        super fn
      end
      fn
    end
    
    def separator
      "\n\n"
    end
    
  end
  
  class IncludeAccumulator < Accumulator
    include SetAccumulator
    def output_one item
      item = item.name unless item.is_a? String
      "#include " +
        if item =~ /\A<.*>\z/
          item
        else
          '"' + item + '"'
        end
    end
  end
  
  class CommentAccumulator < Accumulator
    def to_s
      str = super
      if str.length > 0
        str.gsub(/^(?!\/\/)/, "// ")
      else
        str
      end
    end
  end
  
  accumulator(:preamble)       {CommentAccumulator}
  accumulator(:include)        {IncludeAccumulator}
  accumulator(:declare)        {StatementKeyAccumulator}
  accumulator(:define)         {FunctionAccumulator}
  
  # As for the Library, but can be used on any source file within the library.
  # Used to break large projects up into many files.
  def define_c_function c_name, subclass = Function
    define c_name, subclass
  end
  
  # As for the Library, but can be used on any source file within the library.
  # Used to break large projects up into many files.
  def define_c_method mod, name, subclass = Method
    unless subclass <= Method ## should use assert
      raise "#{subclass.name} is not <= Method"
    end
    c_name = rb_define_method :mod => mod, :rb_name => name, :cfile => self
    define c_name, subclass
  end
  
  # As for the Library, but can be used on any source file within the library.
  # Used to break large projects up into many files.
  def define_c_module_function mod, name, subclass = ModuleFunction
    raise unless subclass <= ModuleFunction
    c_name = rb_define_module_function :mod => mod, :rb_name => name, :cfile => self
    define c_name, subclass
  end
  
  # As for the Library, but can be used on any source file within the library.
  # Used to break large projects up into many files.
  def define_c_global_function name, subclass = GlobalFunction
    raise unless subclass <= GlobalFunction
    c_name = rb_define_global_function :rb_name => name, :cfile => self
    define c_name, subclass
  end
  
  # As for the Library, but can be used on any source file within the library.
  # Used to break large projects up into many files.
  def define_c_singleton_method mod, name, subclass = SingletonMethod
    raise unless subclass <= SingletonMethod
    c_name = rb_define_singleton_method :mod => mod, :rb_name => name, :cfile => self
    define c_name, subclass
  end
  alias define_c_class_method define_c_singleton_method
  
  def define_alloc_func klass
    c_name = rb_define_alloc_func :class => klass, :cfile => self
    define c_name, Function
  end
  
  def declare_struct struct_name, *rest
    struct = CGenerator::Structure.new struct_name, self, *rest
    declare struct_name => ["\n", struct, ";\n"]
    struct
  end
  
  def declare_extern_struct struct_name, *rest
    @include_file.declare_struct struct_name, *rest
  end
  
  alias declare_static declare
  
  def declare_extern(*args)
    if @include_file
      @include_file.declare(*args)
    else
      declare(*args)
    end
  end
  
  def to_s
    super + "\n"
  end
  
  def file
    self
  end
  
end # class CFile


class Prototype < CFragment

  class ArgumentAccumulator < Accumulator
    include SetAccumulator
    def to_s
      if @pile.size > 0
        "(" + @pile.join(", ") + ")"
      else
        '(void)'
      end
    end
    
    def size
      @pile.size
    end
  end
  
  accumulator(:scope,
              :return_type)   {SingletonAccumulator}
  accumulator(:arguments)     {ArgumentAccumulator}
  
  def initialize name, parent
    super
    add scope!, return_type!, " ", name, arguments!
  end
  
  def separator; ""; end
  
  def argc
    arguments!.size
  end
  
end # class Prototype

# The Function class manages all kinds of functions and methods.
#
# === Function Prototype
#
#   scope :static
#   scope :extern
#   arguments 'int x', 'double y', 'VALUE obj', ... 
#   return_type 'void'
#
# These accumulators affect the prototype of the function, which will be placed
# in the declaration section of either the .h or the .c file, depending on the
# scope setting. The default scope is static. The default return type is 'void'.
#
# For the Method subclasses of Function, argument and return types can be
# omitted, in which case they default to 'VALUE'.
#
# === Function Body
#
#   declare :x => "static double x", ...
#   init "x = 0", ...
#   setup 'x' => "x += 1", ...
#   body 'y = sin(x); printf("%d\n", y)', ...
#
# These four accumulators determine the contents of the function between the
# opening and closing braces. The #init code is executed once when the function
# first runs; it's useful for initializing static data. The #setup code runs
# each time the function is called, as does the #body. Distinguishing #setup
# from #body is useful for two reasons: first, #setup is guaranteed to execute
# before #body, and, second, one can avoid setting up the same variable twice,
# because of the key.
#
#   returns "2*x"
#
# Specifies the string used in the final return statement of the function.
# Subsequent uses of this method clobber the previous value. Alternately, one
# can simply insert a "return" manually in the body.
#
# === Method Classes
#
#   Method
#   ModuleFunction
#   GlobalFunction
#   SingletonMethod
#
# These subclasses of the Function template are designed for coding
# Ruby-callable methods in C. The necessary registration (+rb_define_method+,
# etc.) is handled automatically. Defaults are different from Function: +'VALUE
# self'+ is automatically an argument, and argument and return types are assumed
# to be +'VALUE'+ and can be omitted by the caller. The return value is +nil+ by
# default.
#
# === Method Arguments
#
# There are three ways to declare arguments, corresponding to the three ways
# provided by the Ruby interpreter's C API.
#
#   arguments :arg1, :arg2, ...
#
# The default way of specifying arguments. Allows a fixed number of VALUE
# arguments.
#
#   c_array_args argc_name = 'argc', argv_name = 'argv', &block
#
#   rb_array_args args_name = 'args'
#
# Specifies that arguments are to be collected and passed in a C or Ruby array,
# instead of individually (which is the default). In each case, the array of
# actual arguments will be bound to a C parameter with the name specified. See
# the Ruby API documentation for details.
#
# If a block is given to Method#c_array_args, it will be used to specify a call
# to the API function +rb_scan_args+ and to declare the associated variables.
# For example:
#
#   c_array_args('argc', 'argv') {
#     required :arg0, :arg1
#     optional :arg2, :arg3, :arg4
#     rest     :rest
#     block    :block
#   }
#
# declares all the listed symbols as variables of type +VALUE+ in function
# scope, and arranges for the following to be called in the #setup clause (i.e.,
# before the #body):
#
#   rb_scan_args(argc, argv, "23*&", &arg0, &arg1, &arg2,
#                &arg3, &arg4, &rest, &block);
#
# The <tt>'argc', 'argv'</tt> are the default values and are usually omitted.
#
# The lines in the block can occur in any order, and any line can be omitted.
# However, only one line of each kind should be used. In addition, each optional
# argument can be associated with a fragment of C code that will be executed to
# assign it a default value, if needed. For example, one can add the following
# lines to the above block:
#
#     default   :arg3 => "INT2NUM(7)",
#               :arg4 => "INT2NUM(NUM2INT(arg2) + NUM2INT(arg3))"
#
# Otherwise, optional arguments are assigned nil.
#
# In this case, if +arg4+ is not provided by +argv+, then it is initialized
# using the code given. If, in addition, +arg3+ is not provided, then it too is
# initialized. These initializations happen in the #setup clause of the Function
# template and are executed in the same order as the arguments are given in the
# +optional+ line.
#
# Finally, argument types can be checked automatically:
#
#     typecheck :arg2 => Numeric, :arg3 => Numeric
#
# The value passed to the function must either be +nil+ or match the type. Note
# that type checking happens *before* default assignment, so that default
# calculation code can assume types are correct. No typechecking code is
# generated if the type is Object.
class Function < CFragment

  def initialize name, parent
    super
    
    scope :static
    return_type 'void'
    
    add prototype,
        block(declare!, init!, setup!, body!, returns!)
  end
  
  def empty?
    block!.to_s =~ /\A\{\s*\}\z/m
  end
  
  def prototype
    @prototype ||= Prototype.new(name, self)
  end
  
  def scope s
    scope_str = s.to_s
    unless defined?(@scope) and scope_str == @scope
      @scope = scope_str
      case scope_str
      when "static"
        prototype.scope "static "           ## this is kludgy
        declare_static @name => prototype
        declare_extern @name => nil
      when "extern"
        prototype.scope "" ## would be too much work to do "extern "
        declare_extern @name => prototype
        declare_static @name => nil
      end
    end
  end
  
  class ReturnAccumulator < SingletonAccumulator
    def to_s
      if @pile.size > 0
        "return #{@pile.join};"
      else
        ""
      end
    end
  end
  
  class InitAccumulator < BlockAccumulator
    def add_one_really(*args)
      super
      @parent.declare :first_time => "static int first_time = 1"
    end
    
    def to_s
      if @pile.size > 0
        ["\nif (first_time)", super].join(" ") +
         "\nif (first_time) first_time = 0;\n"
      else
        ""
      end
    end
  end
  
  accumulator(:block)           {BlockAccumulator}
  accumulator(:declare)         {StatementKeyAccumulator}
  accumulator(:init)            {InitAccumulator}
  accumulator(:setup)           {StatementKeyAccumulator}
  accumulator(:body)            {StatementAccumulator}
  accumulator(:returns)         {ReturnAccumulator}
  
  def return_type(*args)
    prototype.return_type(*args)
  end
  
  def arguments(*args)
    prototype.arguments(*args)
  end

end # class Function


class MethodPrototype < Prototype

  class MethodArgumentAccumulator < ArgumentAccumulator
    def add_one item
      item = item.to_s
      unless item =~ /\AVALUE /
        item = "VALUE " + item
      end
      super
    end
    def reset
      @pile = []
    end
  end
  
  class RbScanArgsSpec
    def initialize bl
      @required = @optional = @typecheck = @default = @rest = @block = nil
      if bl
        instance_eval(&bl)
      end
    end
    
    def required(*args);      @required = args;     end
    def optional(*args);      @optional = args;     end
    def typecheck(arg);       @typecheck = arg;     end
    def default(arg);         @default = arg;       end
    def rest(arg);            @rest = arg;          end
    def block(arg);           @block = arg;         end
    
    def get_required;         @required;            end
    def get_optional;         @optional;            end
    def get_typecheck;        @typecheck;           end
    def get_default;          @default;             end
    def get_rest;             @rest;                end
    def get_block;            @block;               end
  end
  
  accumulator(:arguments)     {MethodArgumentAccumulator}
  
  def c_array_args(argc_name = 'argc', argv_name = 'argv', &bl)
    arguments!.reset
    arguments!.add_one_really "int #{argc_name}"
    arguments!.add "*#{argv_name}", "self"
    @pile.freeze
    
    scan_spec = RbScanArgsSpec.new(bl)
    
    fmt_str = '"'
    arg_list = [fmt_str]
    
    required = scan_spec.get_required
    count_required = required ? required.size : 0
    if count_required > 0
      fmt_str << "#{required.size}"
      for arg in required
        arg_list << arg
        declare arg => "VALUE #{arg}"
      end
    end
    
    optional = scan_spec.get_optional

    count_optional = optional ? optional.size : 0
    if count_optional > 0
      fmt_str << "0" unless count_required > 0
      fmt_str << "#{optional.size}"
      for arg in optional
        arg_list << arg
        declare arg => "VALUE #{arg}"
      end
    end
    
    rest = scan_spec.get_rest
    if rest
      fmt_str << "*"
      arg_list << rest
      declare rest => "VALUE #{rest}"
    end
    
    block = scan_spec.get_block
    if block
      fmt_str << "&"
      arg_list << block
      declare block => "VALUE #{block}"
    end
    
    fmt_str << '"'
    arg_str = arg_list.join ", &"
    
    unless arg_str == '""'
      setup :rb_scan_args => %{
        rb_scan_args(#{argc_name}, #{argv_name}, #{arg_str});
      }.tabto(0)
      
      typecheck = scan_spec.get_typecheck
      if typecheck
        for arg, argtype in typecheck
          next unless argtype and argtype != Object
          ## this could be a function call
          setup "#{arg} typecheck" => %{\
            if (!NIL_P(#{arg}) &&
                rb_obj_is_kind_of(#{arg}, #{declare_class argtype}) != Qtrue) {
              VALUE v = rb_funcall(
                rb_funcall(#{arg}, #{declare_symbol :class}, 0),
                #{declare_symbol :to_s}, 0);
              rb_raise(#{declare_class TypeError},
                       "argument #{arg} declared #{argtype} but passed %s.",
                       StringValueCStr(v));
            }
          }.tabto(0)
        end
      end

      default = scan_spec.get_default
      if default and default.size > 0
        cases =
          (0..count_optional-1).map { |i|
            "case #{i}:" +
              if default[optional[i]]
                " #{optional[i]} = #{default[optional[i]]};" 
              else
                ""
              end
          }.join("\n")

        setup :rb_scan_args_defaults => %{\
          switch (argc - #{count_required}) {\n#{cases}
          }
        }.tabto(0)
      end
    end
  end
  
  def rb_array_args args_name = 'args'
    arguments "#{args_name}"
    @pile.freeze
  end
  
end # class MethodPrototype

class RubyFunction < Function

  def initialize name, parent
    super   
    return_type 'VALUE'
    arguments 'self'
    returns 'Qnil'
  end
  
  def prototype
    @prototype ||= MethodPrototype.new(name, self)
  end
  
  def c_array_args(*args, &bl)
    prototype.c_array_args(*args, &bl)
    register_args :c_name => @name, :argc => -1  # code used by Ruby C API
  end
  
  def rb_array_args(*args, &bl)
    prototype.rb_array_args(*args, &bl)
    register_args :c_name => @name, :argc => -2  # code used by Ruby C API
  end
  
  def arguments(*args, &bl)
    prototype.arguments(*args, &bl)
    register_args :c_name => @name, :argc => prototype.argc - 1
  end
  
end


class Method < RubyFunction
  def register_args(*args)
    rb_define_method(*args)
  end
end

class ModuleFunction < RubyFunction
  def register_args(*args)
    rb_define_module_function(*args)
  end
end

class GlobalFunction < RubyFunction
  def register_args(*args)
    rb_define_global_function(*args)
  end
end

class SingletonMethod < RubyFunction
  def register_args(*args)
    rb_define_singleton_method(*args)
  end
end

# A Structure instance keeps track of data members added to a struct.
#
#   declare :x => "int x"
#
# Adds the specified string to define a structure member.
class Structure < CFragment

  class InheritAccumulator < Accumulator; include SetAccumulator; end

  accumulator(:block)           {BlockAccumulator}
  accumulator(:inherit)         {InheritAccumulator}
  accumulator(:declare)         {StatementKeyAccumulator}
  
  def initialize name, parent, attribute = nil
    super(name, parent)
    if attribute
      add "typedef struct #{name}", block!, "#{attribute} #{name}"
    else
      add "typedef struct #{name}", block!, name
    end
    block inherit!, declare!
  end

  def separator; " "; end

end # class Structure


OpName= {
  '<'   => :op_lt,
  '<='  => :op_le,
  '>'   => :op_gt,
  '>='  => :op_ge,
  '=='  => :op_eqeq
}

# Generates a unique C itentifier from the given Ruby identifier, which may
# include +/[@$?!]/+, +'::'+, and even +'.'+. (Some special globals are not yet
# supported: +$:+ and +$-I+, for example.)
#
# It is unique in the sense that distinct Ruby identifiers map to distinct C
# identifiers. (Not completely checked. Might fail for some really obscure
# cases.)
def CGenerator.make_c_name s
  s = s.to_s
  OpName[s] || translate_ruby_identifier(s)
end

def CGenerator.translate_ruby_identifier(s)
  # For uniqueness, we use a single '_' to indicate our subs
  # and translate pre-existing '_' to '__'
  # It should be possible to write another method which 
  # converts the output back to the original.
  c_name = s.gsub(/_/, '__')


  # Ruby identifiers can include prefix $, @, or @@, or suffix ?, !, or =
  # and they can be [] or []=
  c_name.gsub!(/\$/, 'global_')
  c_name.gsub!(/@/, 'attr_')
  c_name.gsub!(/\?/, '_query')
  c_name.gsub!(/!/, '_bang')
  c_name.gsub!(/=/, '_equals')
  c_name.gsub!(/::/, '_')
  c_name.gsub!(/\[\]/, '_brackets')

  # so that some Ruby expressions can be associated with a name,
  # we allow '.' in the str. Eventually, handle more Ruby exprs.
  c_name.gsub!(/\./, '_dot_')

  # we should also make an attempt to encode special globals
  # like $: and $-I

  unless c_name =~ /\A[A-Za-z_]\w*\z/
    raise SyntaxError,
      "Cgen's encoding cannot handle #{s.inspect}; " +
      "best try is #{c_name.inspect}."
  end

  c_name.intern
end

end # module CGenerator


##class Array
##  def join_nonempty str
##    map { |x|. x.to_s }.reject { |s| s == "" }.join(str)
##  end
##end

class String

  # Tabs left or right by n chars, using spaces.
  def tab n
    if n >= 0
      gsub(/^/, ' ' * n)
    else
      gsub(/^ {0,#{-n}}/, "")
    end
  end
  
  # The first non-empty line is adjusted to have n spaces before the first
  # nonspace. Additional lines are changed to preserve relative tabbing.
  def tabto n
    if self =~ /^( *)\S/
      tab(n - $1.length)
    else
      self
    end
  end
  
  # Aligns each line to have n spaces before the first non-space.
  def taballto n
    gsub(/^ */, ' ' * n)
  end
  
end # class String
