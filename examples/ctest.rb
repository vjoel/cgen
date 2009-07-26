require 'cshadow.rb'

class Test
  include CShadow

  define_class_method :foo do
    body %{
      typedef struct Bar {
        struct Foo *foo;
      } Bar;
      typedef struct Foo {
        int x;
      } Foo;
      
      Bar bar;
      char s[20], buf[100];
      
      bar.foo->x;
      
      {int *x = 0; printf("%d", *x);}
      
      sscanf("foo bar", "%s", s);
      while (gets(buf))
        printf("%s\n", s);
    }
  end
end

Dir.mkdir "tmp" rescue SystemCallError
Dir.chdir "tmp"

Test.commit

Test.foo
