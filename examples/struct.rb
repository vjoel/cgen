require 'cgen/cshadow'

# see also buffer.rb in redshift

class MyStruct
  include CShadow

  shadow_library_include_file.declare :MyStruct => %{
    typedef struct {
      long    len;
      double  *ptr;
    } MyStruct;
  }.tabto(0)
  
  # An embedded struct that holds a pointer +ptr+ to an externally stored array
  # of doubles of length +len+.
  class MyStructAttribute < CShadow::CNativeAttribute
    @pattern = /\A(MyStruct)\s+(\w+)\z/
    def initialize(*args)
      super
      lib = owner_class.shadow_library
      @reader = "result = mystruct_exhale_array(&shadow->#{@cvar})"
      @writer = "mystruct_inhale_array(&shadow->#{@cvar}, arg)"
      @dump = %{
        rb_ary_push(result, mystruct_exhale_array(&shadow->#{@cvar}));
      }
      @load = %{
        mystruct_inhale_array(&shadow->#{@cvar}, rb_ary_shift(from_array));
      }
      @free = "free(shadow->#{@cvar}.ptr)"
    end
  end

  shadow_attr_accessor :s => "MyStruct s"
  
  define_c_function(:mystruct_inhale_array).instance_eval {
    arguments "MyStruct *mystruct", "VALUE ary"
    scope :static
    body %{
      int  size, i;
      
      Check_Type(ary, T_ARRAY);

      size = RARRAY(ary)->len;
      if (mystruct->ptr) {
        REALLOC_N(mystruct->ptr, double, size);
      }
      else {
        mystruct->ptr = ALLOC_N(double, size);
      }
      mystruct->len = size;

      for (i = 0; i < size; i++) {
        mystruct->ptr[i] = NUM2DBL(RARRAY(ary)->ptr[i]);
      }
    }
  }
  
  define_c_function(:mystruct_exhale_array).instance_eval {
    arguments "MyStruct *mystruct"
    return_type "VALUE"
    returns "ary"
    declare :size => "int size",
            :i => "int i",
            :ary => "VALUE ary"
    body %{
      size = mystruct->len;
      ary = rb_ary_new2(size);
      RARRAY(ary)->len = size;
      for (i = 0; i < size; i++) {
        RARRAY(ary)->ptr[i] = rb_float_new(mystruct->ptr[i]);
      }
    }
  }
    
  define_c_method(:initialize) {
    c_array_args {
      required :ary
      typecheck :ary => Array
    }
    declare :size => "int size",
            :i => "int i"
    body %{
      mystruct_inhale_array(&shadow->s, ary);
    }
  }
end

require 'ftools'
dir = File.join("tmp", RUBY_VERSION)
File.mkpath dir
Dir.chdir dir

MyStruct.commit

m = MyStruct.new [1,2,3]
p m.s
m.s = [4,5,6]
p Marshal.load(Marshal.dump(m))

CShadow.allow_yaml
puts m.to_yaml
p YAML.load(m.to_yaml)
