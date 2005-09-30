#! /bin/sh -e

rm -rf scratch
mkdir -p scratch
mkdir -p scratch/libsA
mkdir -p scratch/libsB

cp main scratch/
cp libfoo.so scratch/libsA/
cp libbar.so scratch/libsB/

../src/patchelf --set-rpath $(pwd)/scratch/libsA scratch/main
../src/patchelf --set-rpath $(pwd)/scratch/libsB scratch/libsA/libfoo.so

exitCode=0
scratch/main || exitCode=$?

if test "$exitCode" != 46; then
    echo "bad exit code!"
    exit 1
fi
