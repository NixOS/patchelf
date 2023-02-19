#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

cp libtoomanystrtab.so "${SCRATCH}"/

# Set a RUNPATH on the library
../src/patchelf --set-rpath "\$ORIGIN" "${SCRATCH}/libtoomanystrtab.so"

# Check that patchelf is able to patch it again without crashing. Previously,
# it will wrongly identify the lib as a static object because there was no
# .dynamic section
exitCode=0
(../src/patchelf --set-rpath "\$ORIGIN" "${SCRATCH}/libtoomanystrtab.so") || exitCode=$?
if test "$exitCode" != 0; then
    echo "bad exit code!"
    exit 1
fi

