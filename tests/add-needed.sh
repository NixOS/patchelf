#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}
mkdir -p ${SCRATCH}/libs

cp simple ${SCRATCH}/
cp libfoo.so ${SCRATCH}/libs/
cp libbar.so ${SCRATCH}/libs/
cp libfoo.so ${SCRATCH}/libs/libfoo0.so
cp libbar.so ${SCRATCH}/libs/libbar0.so
cp libfoo.so ${SCRATCH}/libs/libfoo1.so
cp libbar.so ${SCRATCH}/libs/libbar1.so
cp libfoo.so ${SCRATCH}/libs/libfoo2.so
cp libbar.so ${SCRATCH}/libs/libbar2.so
cp libfoo.so ${SCRATCH}/libs/libfoo3.so
cp libbar.so ${SCRATCH}/libs/libbar3.so

../src/patchelfmod -d --add-needed libfoo0.so --add-needed libbar0.so ${SCRATCH}/simple
../src/patchelfmod -d --add-needed libfoo1.so,libfoo2.so,libfoo3.so ${SCRATCH}/simple
../src/patchelfmod -d --add-needed libbar1.so,libbar2.so,libbar3.so ${SCRATCH}/simple

export LD_LIBRARY_PATH=$(pwd)/${SCRATCH}/libs

exitCode=0
cd ${SCRATCH} && ./simple || exitCode=$?

if test "$exitCode" = 127; then
    echo "bad exit code!"
    exit 1
fi
