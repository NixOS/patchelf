#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}
mkdir -p ${SCRATCH}/libsA
mkdir -p ${SCRATCH}/libsB

cp main ${SCRATCH}/
cp libfoo.so ${SCRATCH}/libsA/
cp libbar.so ${SCRATCH}/libsB/

oldRPath=$(../src/patchelfmod --print-rpath ${SCRATCH}/main)
if test -z "$oldRPath"; then oldRPath="/oops"; fi
../src/patchelfmod --force-rpath --set-rpath $oldRPath:$(pwd)/${SCRATCH}/libsA:$(pwd)/${SCRATCH}/libsB ${SCRATCH}/main


RPathType=$(../src/patchelfmod --print-rpath-type ${SCRATCH}/main)
if test "$RPathType" = "$(echo 'DT_RPATH')"; then
    echo "$RPathType"
else
    echo "$RPathType: Type should be DT_RPATH!"
    exit 1
fi

../src/patchelfmod --convert-rpath ${SCRATCH}/main

RPathType=$(../src/patchelfmod --print-rpath-type ${SCRATCH}/main)
if test "$RPathType" = "$(echo 'DT_RUNPATH')"; then
    echo "$RPathType"
else
    echo "$RPathType: Type should be DT_RUNPATH!"
    exit 1
fi
