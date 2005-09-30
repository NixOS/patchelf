#! /bin/sh -e

rm -rf scratch
mkdir -p scratch
mkdir -p scratch/libsA
mkdir -p scratch/libsB

cp main scratch/
cp libfoo.so scratch/libsA/
cp libbar.so scratch/libsB/

oldRPath=$(../src/patchelf --print-rpath scratch/main)
if test -z "$oldRPath"; then oldRPath="/oops"; fi
../src/patchelf --set-rpath $oldRPath:$(pwd)/scratch/libsA:$(pwd)/scratch/libsB scratch/main

#oldRPath=$(../src/patchelf --print-rpath scratch/libsA/libfoo.so)
#if test -z "$oldRPath"; then oldRPath="/oops"; fi
#../src/patchelf --set-rpath $oldRPath:$(pwd)/scratch/libsB scratch/libsA/libfoo.so

#oldRPath=$(../src/patchelf --print-rpath scratch/libsB/libbar.so)
#if test -z "$oldRPath"; then oldRPath="/oops"; fi
#../src/patchelf --set-rpath $oldRPath:$(pwd)/scratch/libsC scratch/libsB/libbar.so

exitCode=0
cd scratch && ./main || exitCode=$?

if test "$exitCode" != 46; then
    echo "bad exit code!"
    exit 1
fi
