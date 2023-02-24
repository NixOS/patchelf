#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"
mkdir -p "${SCRATCH}/libsA"
mkdir -p "${SCRATCH}/libsB"

cp main "${SCRATCH}"/
cp libfoo.so "${SCRATCH}/libsA/"
cp libbar.so "${SCRATCH}/libsB/"

../src/patchelf --force-rpath --add-rpath "$(pwd)/${SCRATCH}/libsA" "${SCRATCH}/main"
../src/patchelf --force-rpath --add-rpath "$(pwd)/${SCRATCH}/libsB" "${SCRATCH}/main"

if test "$(uname)" = FreeBSD; then
    LD_LIBRARY_PATH="$(pwd)/${SCRATCH}/libsB"
    export LD_LIBRARY_PATH
fi

exitCode=0
(cd "${SCRATCH}" && ./main) || exitCode=$?

if test "$exitCode" != 46; then
    echo "bad exit code!"
    exit 1
fi
