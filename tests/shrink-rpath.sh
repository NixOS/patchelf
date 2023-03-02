#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)

rpath=$(../src/patchelf --print-rpath ./libbar.so)
echo "RPATH before: $rpath"
if ! echo "$rpath" | grep -q /no-such-path; then
    echo "incomplete RPATH"
    exit 1
fi

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"
cp libbar.so "${SCRATCH}"/
../src/patchelf --shrink-rpath "${SCRATCH}/libbar.so"

rpath=$(../src/patchelf --print-rpath "${SCRATCH}/libbar.so")
echo "RPATH after: $rpath"
if echo "$rpath" | grep -q /no-such-path; then
    echo "RPATH not shrunk"
    exit 1
fi

cp libfoo.so "${SCRATCH}/"

exitCode=0
cd "${SCRATCH}" && LD_LIBRARY_PATH=. ../../main || exitCode=$?

if test "$exitCode" != 46; then
    echo "bad exit code!"
    exit 1
fi
