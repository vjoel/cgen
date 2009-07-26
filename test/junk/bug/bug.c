#include "bug.h"

VALUE module_Bug;
VALUE module_String;
VALUE module_TypeError;
ID ID_class;
ID ID_to__s;

void Init_Bug(void)
{
    module_Bug = rb_eval_string("Bug");
    module_String = rb_eval_string("String");
    module_TypeError = rb_eval_string("TypeError");
    ID_class = rb_intern("class");
    ID_to__s = rb_intern("to_s");
    rb_define_method(module_Bug, "_dump_data", __dump__data_module_Bug_method, 0);
    rb_define_method(module_Bug, "_load_data", __load__data_module_Bug_method, 1);
    rb_define_method(module_Bug, "x", x_module_Bug_method, 0);
    rb_define_method(module_Bug, "x=", x_equals_module_Bug_method, -1);
    rb_define_method(module_Bug, "y", y_module_Bug_method, 0);
    rb_define_method(module_Bug, "y=", y_equals_module_Bug_method, -1);
    rb_define_singleton_method(module_Bug, "new", new_module_Bug_singleton_method, -1);
    
    rb_define_alloc_func(module_Bug, alloc_func_module_Bug)
    ;
}

VALUE new_module_Bug_singleton_method(int argc, VALUE *argv, VALUE self)
{
    VALUE object;
    Bug_Shadow *shadow;
    
    object = Data_Make_Struct(self,
               Bug_Shadow,
               mark_Bug_Shadow,
               free_Bug_Shadow,
               shadow);
    shadow->self = object;
    
    shadow->x = Qnil;
    shadow->y = Qnil;
    
    rb_obj_call_init(object, argc, argv);
    
    return object;
}

void mark_Bug_Shadow(Bug_Shadow *shadow)
{
    rb_gc_mark(shadow->self);
    rb_gc_mark(shadow->x);
    rb_gc_mark(shadow->y);
}

void free_Bug_Shadow(Bug_Shadow *shadow)
{
    free(shadow);
}

VALUE __dump__data_module_Bug_method(VALUE self)
{
    Bug_Shadow *shadow;
    VALUE   result;
    Data_Get_Struct(self, Bug_Shadow, shadow);
    result  = rb_ary_new();
    rb_ary_push(result, shadow->x);
    rb_ary_push(result, shadow->y);
    return result;
}

VALUE __load__data_module_Bug_method(VALUE self, VALUE from_array)
{
    Bug_Shadow *shadow;
    VALUE tmp;
    Data_Get_Struct(self, Bug_Shadow, shadow);
    shadow->x = rb_ary_shift(from_array);
    shadow->y = rb_ary_shift(from_array);
    return from_array;
}

VALUE x_module_Bug_method(VALUE self)
{
    Bug_Shadow *shadow;
    VALUE result;
    Data_Get_Struct(self, Bug_Shadow, shadow);
    result = shadow->x;
    return result;
}

VALUE x_equals_module_Bug_method(int argc, VALUE *argv, VALUE self)
{
    VALUE arg;
    Bug_Shadow *shadow;
    
    rb_scan_args(argc, argv, "1", &arg);
    
    Data_Get_Struct(self, Bug_Shadow, shadow);
    shadow->x = arg;
    return arg;
}

VALUE y_module_Bug_method(VALUE self)
{
    Bug_Shadow *shadow;
    VALUE result;
    Data_Get_Struct(self, Bug_Shadow, shadow);
    result = shadow->y;
    return result;
}

VALUE y_equals_module_Bug_method(int argc, VALUE *argv, VALUE self)
{
    VALUE arg;
    Bug_Shadow *shadow;
    
    rb_scan_args(argc, argv, "1", &arg);
    
    if (!NIL_P(arg) &&
        rb_obj_is_kind_of(arg, module_String) != Qtrue)
      rb_raise(module_TypeError,
               "argument arg declared String but passed %s.",
               STR2CSTR(rb_funcall(
                 rb_funcall(arg, ID_class, 0),
                 ID_to__s, 0)));
    
    Data_Get_Struct(self, Bug_Shadow, shadow);
    shadow->y = arg;
    return arg;
}

VALUE alloc_func_module_Bug(VALUE klass)
{
    VALUE object;
    Bug_Shadow *shadow;
    
    object = Data_Make_Struct(klass,
               Bug_Shadow,
               mark_Bug_Shadow,
               free_Bug_Shadow,
               shadow);
    shadow->self = object;
    
    return object;
}
