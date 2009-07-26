require 'cgen/cshadow.rb'

class Test
  include CShadow

  shadow_attr_accessor :sym  => Symbol

  define_c_method :foo do
    body %{
      shadow->sym = ID2SYM(rb_intern("some_symbol"));
    }
  end
  free_function.body %{
    printf("Freeing a Test instance.\\n");
  }
end

Dir.mkdir "tmp" rescue SystemCallError
Dir.chdir "tmp"

Test.commit

t = Test.new
t.foo
p t.sym
t.sym = :qwerty
p t.sym
