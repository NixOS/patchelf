#include <stdio.h>

int bar();

int foo()
{
    printf("This is foo()!\n");
    return 12 + bar();
}
