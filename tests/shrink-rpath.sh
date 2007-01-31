#! /bin/sh -e

rpath=$(../src/patchelf --print-rpath ./libbar.so)
echo "RPATH before: $rpath"
if ! echo "$rpath" | grep -q /no-such-path; then
    echo "incomplete RPATH"
    exit 1
fi

rm -rf scratch
mkdir -p scratch
cp libbar.so scratch/
../src/patchelf --shrink-rpath scratch/libbar.so

rpath=$(../src/patchelf --print-rpath scratch/libbar.so)
echo "RPATH after: $rpath"
if echo "$rpath" | grep -q /no-such-path; then
    echo "RPATH not shrunk"
    exit 1
fi

cp libfoo.so scratch/

exitCode=0
cd scratch && LD_LIBRARY_PATH=. ../main || exitCode=$?

if test "$exitCode" != 46; then
    echo "bad exit code!"
    exit 1
fi
