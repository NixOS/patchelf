#! /bin/sh -e

if ! objdump -p main | grep -q MIPS_RLD_MAP_REL; then
    echo "No MIPS_RLD_MAP_REL dynamic section entry, skipping"
    exit 0
fi

SCRATCH=scratch/$(basename $0 .sh)

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}
mkdir -p ${SCRATCH}/libsA
mkdir -p ${SCRATCH}/libsB

cp main ${SCRATCH}/
cp libfoo.so ${SCRATCH}/libsA/
cp libbar.so ${SCRATCH}/libsB/

# break the main executable by removing .rld_map section
objcopy --remove-section .rld_map ${SCRATCH}/main

oldRPath=$(../src/patchelf --print-rpath ${SCRATCH}/main)
if test -z "$oldRPath"; then oldRPath="/oops"; fi
../src/patchelf --force-rpath --set-rpath $oldRPath:$(pwd)/${SCRATCH}/libsA:$(pwd)/${SCRATCH}/libsB ${SCRATCH}/main

if test "$(uname)" = FreeBSD; then
    export LD_LIBRARY_PATH=$(pwd)/${SCRATCH}/libsB
fi

exitCode=0

(cd ${SCRATCH} && ./main) || exitCode=$?

if test "$exitCode" != 46; then
    echo "bad exit code!"
    exit 1
fi
