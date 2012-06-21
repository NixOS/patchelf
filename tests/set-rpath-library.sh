#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)

if test "$(uname)" = FreeBSD; then
    echo "skipping on FreeBSD"
    exit 0
fi

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}
mkdir -p ${SCRATCH}/libsA
mkdir -p ${SCRATCH}/libsB

cp main-scoped ${SCRATCH}/
cp libfoo-scoped.so ${SCRATCH}/libsA/
cp libbar-scoped.so ${SCRATCH}/libsB/

oldRPath=$(../src/patchelf --print-rpath ${SCRATCH}/main-scoped)
if test -z "$oldRPath"; then oldRPath="/oops"; fi
../src/patchelf --set-rpath $oldRPath:$(pwd)/${SCRATCH}/libsA:$(pwd)/${SCRATCH}/libsB ${SCRATCH}/main-scoped

# "main" contains libbar in its RUNPATH, but that's ignored when
# resolving libfoo.  So libfoo won't find libbar and this will fail.
exitCode=0
(cd ${SCRATCH} && ./main-scoped) || exitCode=$?

if test "$exitCode" = 46; then
    echo "expected failure"
    exit 1
fi

# So set an RUNPATH on libfoo as well.
oldRPath=$(../src/patchelf --print-rpath ${SCRATCH}/libsA/libfoo-scoped.so)
if test -z "$oldRPath"; then oldRPath="/oops"; fi
../src/patchelf --set-rpath $oldRPath:$(pwd)/${SCRATCH}/libsB ${SCRATCH}/libsA/libfoo-scoped.so

exitCode=0
(cd ${SCRATCH} && ./main-scoped) || exitCode=$?

if test "$exitCode" != 46; then
    echo "bad exit code!"
    exit 1
fi

# Remove the libbar PATH from main using --shrink-rpath.
../src/patchelf --shrink-rpath ${SCRATCH}/main-scoped
if ../src/patchelf --print-rpath ${SCRATCH}/main-scoped | grep /libsB; then
    echo "shrink failed"
    exit 1
fi

# And it should still run.
exitCode=0
(cd ${SCRATCH} && ./main-scoped) || exitCode=$?

if test "$exitCode" != 46; then
    echo "bad exit code!"
    exit 1
fi
