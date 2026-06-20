#! /bin/sh -e

PATCHELF="../src/patchelf"
SONAME="phdr-corruption.so"
SCRATCH="scratch/$(basename "$0" .sh)"
SCRATCH_SO="${SCRATCH}/${SONAME}"
READELF=${READELF:-readelf}

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"
cp "${SONAME}" "${SCRATCH}"

"${PATCHELF}" --append-null-phdr --append-null-phdrs 2 "${SCRATCH_SO}"

# Check for PT_NULL entries
readelfData=$(${READELF} -l "${SCRATCH_SO}" 2>&1)

if [ "$(echo "$readelfData" | grep -c "NULL")" != 3 ]; then
  # Triggered if patchelf doesn't append two PT_NULL entries
  echo "ERROR: PT_NULL segments were not appended to the program header table!"
  exit 1
fi
