#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}

cp simple ${SCRATCH}/

../src/patchelfmod -d --add-needed libfoo0.so,libfoo1.so,libfoo2.so,libfoo3.so ${SCRATCH}/simple
../src/patchelfmod -d --add-needed libbar0.so,libbar1.so,libbar2.so,libbar3.so ${SCRATCH}/simple
../src/patchelfmod -d --remove-needed libfoo0.so --remove-needed libbar0.so ${SCRATCH}/simple
../src/patchelfmod -d --remove-needed libfoo1.so,libfoo2.so,libfoo3.so ${SCRATCH}/simple
../src/patchelfmod -d --remove-needed libbar1.so,libbar2.so,libbar3.so ${SCRATCH}/simple

export LD_LIBRARY_PATH=$(pwd)/${SCRATCH}/libs

exitCode=0
cd ${SCRATCH} && ./simple || exitCode=$?

if test "$exitCode" = 127; then
    echo "bad exit code!"
    exit 1
fi
