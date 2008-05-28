#! /bin/sh -e

if test "$(uname)" = FreeBSD; then
    echo "skipping on FreeBSD"
    exit 0
fi

rm -rf scratch
mkdir -p scratch
mkdir -p scratch/libsA
mkdir -p scratch/libsB

cp main-scoped scratch/
cp libfoo-scoped.so scratch/libsA/
cp libbar-scoped.so scratch/libsB/

oldRPath=$(../src/patchelf --print-rpath scratch/main-scoped)
if test -z "$oldRPath"; then oldRPath="/oops"; fi
../src/patchelf --set-rpath $oldRPath:$(pwd)/scratch/libsA:$(pwd)/scratch/libsB scratch/main-scoped

# "main" contains libbar in its RUNPATH, but that's ignored when
# resolving libfoo.  So libfoo won't find libbar and this will fail.
exitCode=0
(cd scratch && ./main-scoped) || exitCode=$?

if test "$exitCode" = 46; then
    echo "expected failure"
    exit 1
fi

# So set an RUNPATH on libfoo as well.
oldRPath=$(../src/patchelf --print-rpath scratch/libsA/libfoo-scoped.so)
if test -z "$oldRPath"; then oldRPath="/oops"; fi
../src/patchelf --set-rpath $oldRPath:$(pwd)/scratch/libsB scratch/libsA/libfoo-scoped.so

exitCode=0
(cd scratch && ./main-scoped) || exitCode=$?

if test "$exitCode" != 46; then
    echo "bad exit code!"
    exit 1
fi

# Remove the libbar PATH from main using --shrink-rpath.
../src/patchelf --shrink-rpath scratch/main-scoped
if ../src/patchelf --print-rpath scratch/main-scoped | grep /libsB; then
    echo "shrink failed"
    exit 1
fi

# And it should still run.
exitCode=0
(cd scratch && ./main-scoped) || exitCode=$?

if test "$exitCode" != 46; then
    echo "bad exit code!"
    exit 1
fi
