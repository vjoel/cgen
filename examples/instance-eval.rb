require 'cgen/cshadow'

class A
  include CShadow
  
  define_c_method :instance_eval_proc do
    c_array_args {
      required :pr
      typecheck :pr => Proc
    }
    body %{
      printf("instance_eval_proc\\n");
    }
    returns "rb_iterate(my_instance_eval, shadow->self, call_block, pr)"
  end
  
  fn = shadow_library_source_file.define :my_instance_eval
  fn.instance_eval do
    arguments "VALUE obj"
    return_type "VALUE"
    body %{
      printf("my_instance_eval\\n");
    }
    returns "rb_obj_instance_eval(0, 0, obj)"
  end
  
  fn = shadow_library_source_file.define :call_block
  fn.instance_eval do
    arguments "VALUE arg1", "VALUE block"
    return_type "VALUE"
    body %{
      printf("call_block\\n");
    }
    returns "rb_funcall(block, #{declare_symbol :call}, 0)"
  end  

end

Dir.chdir "tmp" do
  A.commit
end

a = A.new
pr = proc { "self is %p" % self }

p a.instance_eval(&pr)
puts '---'
p a.instance_eval_proc(pr)

__END__



static VALUE my_instance_eval(VALUE obj)
{
    return rb_obj_instance_eval(0, 0, obj);
}

static VALUE call_block(VALUE arg1, VALUE block)
{
    return rb_funcall(block, ID_call, 0);
}

//...
    rb_iterate(my_instance_eval, obj, call_block, pr);

