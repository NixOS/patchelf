#! /bin/sh -e

rpath=$(../src/patchelf --print-rpath ./libfoo.so)
echo "RPATH before: $rpath"
if ! echo "$rpath" | grep -q /no-such-path; then
    echo "incomplete RPATH"
    exit 1
fi

rm -rf scratch
mkdir -p scratch
cp libfoo.so scratch/
../src/patchelf --shrink-rpath scratch/libfoo.so

rpath=$(../src/patchelf --print-rpath scratch/libfoo.so)
echo "RPATH after: $rpath"
if echo "$rpath" | grep -q /no-such-path; then
    echo "RPATH not shrunk"
    exit 1
fi

