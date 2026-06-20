#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)
OBJCOPY=${OBJCOPY:-objcopy}

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

cp simple "${SCRATCH}/"

${OBJCOPY} --only-keep-debug "${SCRATCH}/simple" "${SCRATCH}/simple.debug"

# Check if patchelf handles debug-only executables
../src/patchelf --set-interpreter /oops "${SCRATCH}/simple.debug"
