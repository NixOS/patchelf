#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)
STRIP=${STRIP:-strip}

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

cp simple "${SCRATCH}/"

${STRIP} --remove-section=.gnu.hash "${SCRATCH}/simple"

# Check if patchelf handles binaries with GNU_HASH in dynamic section but
# without .gnu.hash section
../src/patchelf --set-interpreter /oops "${SCRATCH}/simple"
