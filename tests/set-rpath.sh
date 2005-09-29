#! /bin/sh -e

oldInterpreter=$(../src/patchelf --print-interpreter ./simple)
echo "current interpreter is $oldInterpreter"

rm -rf scratch
mkdir -p scratch

cp main scratch/
cp libfoo.so scratch/
cp libbar.so scratch/

../src/patchelf --set-rpath $(pwd)/scratch scratch/main
../src/patchelf --set-rpath $(pwd)/scratch scratch/libfoo.so

exitCode=0
scratch/main || exitCode=$?

if test "$exitCode" != 46; then
    echo "bad exit code!"
    exit 1
fi
