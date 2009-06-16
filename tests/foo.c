#include <stdio.h>

/* Include a bogus .interp section in libfoo.so (NIXPKGS-98).
   Borrowed from Glibc. */
const char __invoke_dynamic_linker__[] __attribute__ ((section (".interp"))) = "/foo/bar";

int bar();

int foo()
{
    printf("This is foo()!\n");
    return 12 + bar();
}
