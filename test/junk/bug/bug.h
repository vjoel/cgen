#include <ruby.h>

void Init_Bug(void);

typedef struct Bug_Shadow {
    VALUE self;
    VALUE x;
    VALUE y;
} Bug_Shadow;

extern VALUE module_Bug;
VALUE new_module_Bug_singleton_method(int argc, VALUE *argv, VALUE self);
void mark_Bug_Shadow(Bug_Shadow *shadow);
void free_Bug_Shadow(Bug_Shadow *shadow);
VALUE __dump__data_module_Bug_method(VALUE self);
VALUE __load__data_module_Bug_method(VALUE self, VALUE from_array);
VALUE x_module_Bug_method(VALUE self);
VALUE x_equals_module_Bug_method(int argc, VALUE *argv, VALUE self);
VALUE y_module_Bug_method(VALUE self);
VALUE y_equals_module_Bug_method(int argc, VALUE *argv, VALUE self);
extern VALUE module_String;
extern VALUE module_TypeError;
extern ID ID_class;
extern ID ID_to__s;
VALUE alloc_func_module_Bug(VALUE klass);


