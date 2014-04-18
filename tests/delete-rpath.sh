#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}

cp libbar.so ${SCRATCH}/

../src/patchelfmod -d --delete-rpath ${SCRATCH}/libbar.so
newRPath=$(../src/patchelfmod -d --print-rpath ${SCRATCH}/libbar.so)

if test "$newRPath" != ""; then
    echo "couldn't delete RPATH!"
    exit 1
fi
