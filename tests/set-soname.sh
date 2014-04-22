#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}

cp libbar-withsoname.so ${SCRATCH}


if ../src/patchelf -d --print-soname ${SCRATCH}/libbar-withsoname.so = libbar.so.0; then
    ../src/patchelf -d --set-soname libtest.so.0 ${SCRATCH}/libbar-withsoname.so
else
    echo "SONAME != 'libbar.so.0'"
    exit 1
fi

if ../src/patchelf -d --print-soname ${SCRATCH}/libbar-withsoname.so = libtest.so.0; then
    ../src/patchelf -d --set-soname libbar.so.0 ${SCRATCH}/libbar-withsoname.so
else
    echo "SONAME != 'libtest.so.0'"
    exit 1
fi
