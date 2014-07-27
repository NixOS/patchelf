#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}

cp libsimple.so ${SCRATCH}/


soname=$(../src/patchelf --print-soname ${SCRATCH}/libsimple.so)
if test $soname = libsimple.so.1.0; then
    ../src/patchelf --set-soname libtest.so.0 ${SCRATCH}/libsimple.so
else
    echo "SONAME != 'libsimple.so.1.0'"
    exit 1
fi

soname=$(../src/patchelf --print-soname ${SCRATCH}/libsimple.so)
if test $soname = libtest.so.0; then
    ../src/patchelf --set-soname libsimple.so.1.0 ${SCRATCH}/libsimple.so
else
    echo "SONAME != 'libtest.so.0'"
    exit 1
fi
