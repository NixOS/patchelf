#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}
mkdir -p ${SCRATCH}/libs

cp simple ${SCRATCH}/
cp libbar.so ${SCRATCH}/libs/

../src/patchelfmod -d --add-needed libfoo.so ${SCRATCH}/simple

export LD_LIBRARY_PATH=$(pwd)/${SCRATCH}/libs

exitCode=0
cd ${SCRATCH} && ./simple || exitCode=$?

if test "$exitCode" != 127; then
    echo "bad exit code!"
    exit 1
fi

cd ../..
../src/patchelfmod -d --replace-needed libfoo.so,libbar.so ${SCRATCH}/simple

exitCode=0
cd ${SCRATCH} && ./simple || exitCode=$?

if test "$exitCode" = 127; then
    echo "bad exit code!"
    exit 1
fi
