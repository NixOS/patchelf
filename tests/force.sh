#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

cp simple "${SCRATCH}/"

../src/patchelf --force "${SCRATCH}/simple"

exitCode=0
"${SCRATCH}/simple" || exitCode=$?

if test "$exitCode" != 0; then
    echo "bad exit code after --force!"
    exit 1
fi

cp simple "${SCRATCH}/simple2"
../src/patchelf --force --output "${SCRATCH}/simple2-out" "${SCRATCH}/simple2"

if ! test -f "${SCRATCH}/simple2-out"; then
    echo "--force with --output did not create output file!"
    exit 1
fi

exitCode=0
"${SCRATCH}/simple2-out" || exitCode=$?

if test "$exitCode" != 0; then
    echo "bad exit code after --force --output!"
    exit 1
fi
