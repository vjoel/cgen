class Foo
  def initialize
    @a = 1
    @b = 2
  end

  def inc_iv
    [:@a, :@b].each { |iv|
      eval "#{iv} += 1"
    }
  end
end

require 'cgen/cshadow'

class Bar
  include CShadow
  
  def initialize
    @a = 1
    @b = 2
  end
  
  def inc_iv
    [:@a, :@b].each { |iv|
      iv = iv
      set_iv(iv, get_iv(iv) + 1)
    }
  end
  
  define_method :set_iv do
    arguments :attr, :value
    body %{
      rb_ivar_set(shadow->self, rb_to_id(attr), value);
    }
    returns %{shadow->self}
  end
  private :set_iv
  
  define_method :get_iv do
    arguments :attr
    returns %{rb_ivar_get(shadow->self, rb_to_id(attr))}
  end
  private :get_iv
  
  def inspect
    "<Bar: a = #{@a}, b = #{@b}>"
  end
end

Bar.commit # write to .c files, make, and require

bar = Bar.new
bar.inc_iv
p bar
