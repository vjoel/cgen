require 'cshadow.rb'

class Object
  def insteval_proc pr
    instance_eval &pr
  end
end

class TestSuper
  def foo arg
    p "foo #{arg}"
  end
  
  class << self
    def class_meth
      puts "Class method!"
    end
  end
end

class Test < TestSuper
  include CShadow

#  shadow_library.declare :typedefs =>  %{
#      typedef struct zap *T1;
#      typedef int *T2;
#      struct zap {
#        double z;
#      };
#  }
  
#  shadow_library_include_file.declare :foo => "extern int foo"
#  shadow_library.declare :foo => "int foo"
  
  shadow_attr_accessor :ary => Array
  
  def initialize
    self.ary = []
  end
#  protected :zap
  
  shadow_library.include "<assert.h>"
  shadow_library.include "<math.h>"
  
  define_method :bar do
    body %{
      rb_funcall(RBASIC(shadow->self)->klass, #{declare_symbol :class_meth}, 0);
    }
  end
  
  define_class_method :foo do
    arguments :from_array
    body %{
      enum zap {zow, zim=3, zug=zow+zim, zwip} zzz;
      typedef struct {
        short s;
        unsigned a : 4;
        enum zap b : 4;
//        enum zap c : 15;
//        unsigned d : 1;
        unsigned e : 5;
        unsigned f : 3;
      } bitfld;
      struct {
        struct {} v0;
        struct {} v1;
        struct {} v2;
        int x;
      } z;
      int zz = 123;
      VALUE pi;
      
      inline VALUE fn(VALUE v) { 
        printf("The value is %d.\\n", NUM2LONG(v));
      }
      
      VALUE fnie(VALUE arg, VALUE my_proc) {
        rb_funcall(my_proc, #{declare_symbol :call}, 0);
      }
      
typedef void (*Flow)(void *);  // evaluates one variable
typedef struct {
  unsigned    d_tick    : 16; // last discrete tick at which flow computed
  unsigned    rk_level  :  3; // last rk level at which flow was computed
  unsigned    algebraic :  1; // should compute flow when inputs change?
  unsigned    nested    :  1; // to catch circular evaluation
  Flow        flow;           // cached flow function of current state
  double      value_0;        // value during discrete step
  double      value_1;        // value at steps of Runge-Kutta
  double      value_2;
  double      value_3;
} ContVar;

typedef struct T_o_ContState_Shadow {
    
    /* RedShift_o_Component_o_ContState_Shadow members */
    long self;
    long foo;
  
    struct {} begin_vars __attribute__ ((aligned (8)));
     
    ContVar x;
} T_o_ContState_Shadow;

T_o_ContState_Shadow shadow;

      printf("sizeof(z) = %d\\n", sizeof(z));
      printf("sizeof(ContVar) = %d\\n", sizeof(ContVar));
      printf("sizeof(T_o_ContState_Shadow) = %d\\n", sizeof(T_o_ContState_Shadow));
      
      printf("&shadow.x - &shadow.begin_vars = %d\\n",
      (void *)&(shadow.x) - (void *)&(shadow.begin_vars));
      
      return Qnil;
      
      printf("sizeof(z) = %d\n", sizeof(z));
      return Qnil;
      
#if 1
      rb_funcall(Qnil, #{declare_symbol :insteval_proc},
                 1, RARRAY(from_array)->ptr[0]);
#else
//#      rb_obj_instance_eval(1, &RARRAY(from_array)->ptr[0], Qnil);
      rb_iterate(rb_obj_instance_eval, INT2NUM(15), &fnie, RARRAY(from_array)->ptr[0]);
#endif

      return Qnil;
      
//      printf("Result = %f\\n", pow(1.0,5));
      
//      return Qnil;
      
      fn(RARRAY(from_array)->ptr[2]);
      printf("Len = %d\\n", RARRAY(from_array)->len);
            
      goto skip;            
      assert(1==0);
skip:
      pi = rb_const_get(#{declare_module :Math}, #{declare_symbol :PI});
      
      printf("Math::PI = %f", NUM2DBL(pi));
      
      printf("\\n%d, %d, %d, %d.\\n", zow, zim, zug, zwip);

      printf("\\nSize is: %d\\n", sizeof(bitfld));
      
      switch (zz) {
        case 1: 0;
      }
      
      while (zz-- > 0) {
        int xx = zz;
        printf("%d\n", xx);
      }
    }
  end
end

Dir.mkdir "tmp" rescue SystemCallError
Dir.chdir "tmp"

Test.commit

Test.new.bar
exit

#p Test.new

#num = 2**31-1
#puts "original num = #{num}"

class MyArray < Array; end
ma = MyArray.new << 0 << 1 << 2 << 3

result = Test.foo([proc { puts "bar" }])
#puts "result num = #{num}"

#marshalled_num = Marshal.load(Marshal.dump(num))
#puts "marshalled num = #{marshalled_num}"
