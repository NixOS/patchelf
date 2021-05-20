#!/bin/sh
set -ex
cat << EOF > hello.c
#include <stdio.h>
int main() {
   printf("Hello, World!");
   return 0;
}
EOF
gcc hello.c -o hello -no-pie
interpreter=$(../src/patchelf --print-interpreter ./hello)
cp ./hello ./hello.orig
../src/patchelf --set-interpreter $interpreter ./hello
../src/patchelf --replace-needed libc.so.6  $interpreter ./hello
./hello.orig
./hello
