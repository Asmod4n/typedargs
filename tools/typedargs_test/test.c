#include <mruby.h>
#include <mruby/array.h>
#include <mruby/string.h>
#include <mruby/variable.h>
#include <mruby/presym.h>
#include <mruby/error.h>
#include <mruby/class.h>
#include <string.h>

int main(const int argc, const char * const argv[]) {
  mrb_state *mrb = NULL;
  int exit_code = 0;

  mrb = mrb_open();
  if (!mrb) {
    return 1;
  }
  if (mrb->exc) {
    mrb_print_error(mrb);
    mrb_close(mrb);
    return 1;
  }

  mrb_value ARGV = mrb_ary_new_capa(mrb, argc);
  for (int i = 0; i < argc; i++) {
    mrb_value arg = mrb_str_new_static_frozen(mrb, argv[i], strlen(argv[i]));
    mrb_ary_push(mrb, ARGV, arg);
  }
  mrb_obj_freeze(mrb, ARGV);
  mrb_define_const_id(mrb, mrb->object_class, MRB_SYM(ARGV), ARGV);

  struct RClass *typeadargs = mrb_module_get_id(mrb, MRB_SYM(TypedArgs));

  mrb_value res = mrb_funcall(mrb, mrb_obj_value(typeadargs), "opts", 0);

  if (mrb->exc) {
    mrb_print_error(mrb);
    exit_code = 1;
  } else {
    mrb_p(mrb, res);
  }

  mrb_close(mrb);
  return exit_code;
}
