require 'cgen/cshadow.rb'

class Test
  include CShadow
  
  define_c_class_method :foo do
    body %{
      printf("Ok!\n");
    }
  end
end

Dir.mkdir "tmp" rescue SystemCallError
Dir.chdir "tmp"

Test.commit

Test.foo
