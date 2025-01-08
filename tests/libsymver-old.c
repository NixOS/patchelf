#include <stdio.h>

__asm__(".symver foo_v1, foo@@V1");

void foo_v1() {
    printf("foo_v1\n");
}

void bar() {
    printf("bar_unver\n");
}
