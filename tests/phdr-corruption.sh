#! /bin/sh -e

PATCHELF="../src/patchelf"
SONAME="phdr-corruption.so"
SCRATCH="scratch/$(basename $0 .sh)"
SCRATCH_SO="${SCRATCH}/${SONAME}"

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"
cp "${SONAME}" "${SCRATCH}"

"${PATCHELF}" --set-rpath "$(pwd)" "${SCRATCH_SO}"

# Check for PT_PHDR entry VirtAddr corruption
readelfData=$(readelf -l "${SCRATCH_SO}" 2>&1)

if [ $(echo "$readelfData" | grep --count "PHDR") != 1 ]; then
  # Triggered if PHDR errors appear on stderr
  echo "ERROR: Unexpected number of occurences of PHDR in readelf results!"
  exit 1
fi
