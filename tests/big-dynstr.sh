#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}
mkdir -p ${SCRATCH}/libsA
mkdir -p ${SCRATCH}/libsB

cp big-dynstr ${SCRATCH}/
cp libfoo.so ${SCRATCH}/libsA/
cp libbar.so ${SCRATCH}/libsB/

oldRPath=$(../src/patchelf --print-rpath ${SCRATCH}/big-dynstr)
if test -z "$oldRPath"; then oldRPath="/oops"; fi
../src/patchelf --force-rpath --set-rpath $oldRPath:$(pwd)/${SCRATCH}/libsA:$(pwd)/${SCRATCH}/libsB ${SCRATCH}/big-dynstr

if test "$(uname)" = FreeBSD; then
    export LD_LIBRARY_PATH=$(pwd)/${SCRATCH}/libsB
fi

exitCode=0
cd ${SCRATCH} && ./big-dynstr || exitCode=$?

if test "$exitCode" != 46; then
    echo "bad exit code!"
    exit 1
fi
