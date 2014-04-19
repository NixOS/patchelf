#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}

cp libsimple.so ${SCRATCH}/

# print and set DT_SONAME
soname=$(../src/patchelf --print-soname ${SCRATCH}/libsimple.so)
if test "$soname" != libsimple.so.1.0; then
    echo "failed --print-soname test. Expected soname: libsimple.so.1.0, got: $soname"
    exit 1
fi

../src/patchelf --set-soname libsimple.so.1.1 ${SCRATCH}/libsimple.so
newSoname=$(../src/patchelf --print-soname ${SCRATCH}/libsimple.so)
if test "$newSoname" != libsimple.so.1.1; then
    echo "failed --set-soname test. Expected newSoname: libsimple.so.1.1, got: $newSoname"
    exit 1
fi
