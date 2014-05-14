#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}

cp libbar-withsoname.so ${SCRATCH}/


soname=$(../src/patchelfmod -d --print-soname ${SCRATCH}/libbar-withsoname.so)
if test $soname = libbar.so.0; then
    ../src/patchelfmod -d --set-soname libtest.so.0 ${SCRATCH}/libbar-withsoname.so
else
    echo "SONAME != 'libbar.so.0'"
    exit 1
fi

soname=$(../src/patchelfmod -d --print-soname ${SCRATCH}/libbar-withsoname.so)
if test $soname = libtest.so.0; then
    ../src/patchelfmod -d --set-soname libbar.so.0 ${SCRATCH}/libbar-withsoname.so
else
    echo "SONAME != 'libtest.so.0'"
    exit 1
fi
