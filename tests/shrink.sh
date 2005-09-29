#! /bin/sh -e

echo -n "RPATH before: "
readelf -a ./libfoo.so | grep RPATH
if ! readelf -a ./libfoo.so | grep RPATH | grep -q /no-such-path; then
    echo "incomplete RPATH"
    exit 1
fi

rm -rf scratch
mkdir -p scratch
cp libfoo.so scratch/
../src/patchelf --shrink-rpath scratch/libfoo.so

echo -n "RPATH after: "
readelf -a scratch/libfoo.so | grep RPATH
if readelf -a scratch/libfoo.so | grep RPATH | grep -q /no-such-path; then
    echo "incomplete RPATH"
    exit 1
fi

