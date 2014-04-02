#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}
mkdir -p ${SCRATCH}/libs

cp simple ${SCRATCH}/
cp libfoo.so ${SCRATCH}/libs/
cp libbar.so ${SCRATCH}/libs/
cp libfoo.so ${SCRATCH}/libs/libfoo1.so
cp libbar.so ${SCRATCH}/libs/libbar1.so

../src/patchelfmod --add-needed libfoo1.so --add-needed libbar1.so ${SCRATCH}/simple

export LD_LIBRARY_PATH=$(pwd)/${SCRATCH}/libs

exitCode=0
cd ${SCRATCH} && ./simple || exitCode=$?

if test "$exitCode" = 127; then
    echo "bad exit code!"
    exit 1
fi
