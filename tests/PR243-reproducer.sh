#!/bin/sh
set -ex
# PR243-reproducer.sh
curl -OLf https://github.com/NixOS/patchelf/files/6501509/ld-linux-x86-64.so.2.tar.gz
curl -OLf https://github.com/NixOS/patchelf/files/6501457/repro.tar.gz
tar fx repro.tar.gz
tar fx ld-linux-x86-64.so.2.tar.gz
chmod +x repro
cp repro repro.orig
../src/patchelf --set-interpreter ./ld-linux-x86-64.so.2 ./repro
patchelf --print-interpreter repro.orig 
readelf -a repro > /dev/null
./repro
