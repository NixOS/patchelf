#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"
mkdir -p "${SCRATCH}/libsA"
mkdir -p "${SCRATCH}/libsB"

cp main "${SCRATCH}"/
cp libfoo.so "${SCRATCH}/libsA/"
cp libbar.so "${SCRATCH}/libsB/"

oldRPath=$(../src/patchelf --print-rpath "${SCRATCH}/main")
if test -z "$oldRPath"; then oldRPath="/oops"; fi

../src/patchelf --force-rpath --set-rpath "$oldRPath:$(pwd)/${SCRATCH}/libsA:$(pwd)/${SCRATCH}/libsB" "${SCRATCH}/main" --output "${SCRATCH}/main2"
# make sure it copies even when there is nothing to do (because rpath is already set)
../src/patchelf --force-rpath --set-rpath "$oldRPath:$(pwd)/${SCRATCH}/libsA:$(pwd)/${SCRATCH}/libsB" "${SCRATCH}/main2" --output "${SCRATCH}/main3"

if test "$(uname)" = FreeBSD; then
    LD_LIBRARY_PATH="$(pwd)/${SCRATCH}/libsB"
    export LD_LIBRARY_PATH
fi

exitCode=0
(cd "${SCRATCH}" && ./main2) || exitCode=$?

if test "$exitCode" != 46; then
    echo "bad exit code!"
    exit 1
fi

exitCode=0
(cd "${SCRATCH}" && ./main3) || exitCode=$?

if test "$exitCode" != 46; then
    echo "bad exit code!"
    exit 1
fi
