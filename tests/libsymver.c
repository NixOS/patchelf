#include <stdio.h>

__asm__(".symver foo_v1, foo@V1");
__asm__(".symver foo_v2, foo@@V2");

void foo_v1() {
    printf("foo_v1\n");
}

void foo_v2() {
    printf("foo_v2\n");
}


// version defined in version script
void bar() {
    printf("bar_ver\n");
}