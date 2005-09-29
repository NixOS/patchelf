#include <stdio.h>

char buf[16 * 1024 * 1024];

int foo();

int main(int argc, char * * argv)
{
    printf("Hello World\n");
    int x = foo();
    printf("Result is %d\n", x);
    return x;
}
