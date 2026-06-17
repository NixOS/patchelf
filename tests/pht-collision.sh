#! /bin/sh -e

PATCHELF="../src/patchelf"
SONAME="pht-collision.so"
SCRATCH="scratch/$(basename "$0" .sh)"
SCRATCH_SO="${SCRATCH}/${SONAME}"
READELF=${READELF:-readelf}

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"
cp "${SONAME}" "${SCRATCH}"

# Setup: copy the PHT to the end of section .pht, right before .adjacent_data
adjacent_data_offset=$(${READELF} -WS "${SCRATCH_SO}" | awk -F'[][ ]+' '($3==".adjacent_data"){print $6}')
adjacent_data_offset=$((0x$adjacent_data_offset))

orig_phoff=$(${READELF} -h "${SCRATCH_SO}" | awk '/Start of program headers:/{print $5}')
phentsize=$(${READELF} -h "${SCRATCH_SO}" | awk '/Size of program headers:/{print $5}')
phnum=$(${READELF} -h "${SCRATCH_SO}" | awk '/Number of program headers:/{print $5}')
pht_size=$((phentsize * phnum))

new_phoff=$((adjacent_data_offset - pht_size))
dd if="${SCRATCH_SO}" of="${SCRATCH_SO}" bs=1 skip="${orig_phoff}" seek="${new_phoff}" count="${pht_size}" conv=notrunc

# Patch e_phoff in the ELF header to reflect the new location.
# ELF64: offset 32, 8 bytes (phentsize == 56)
# ELF32: offset 28, 4 bytes (phentsize == 32)
if [ "${phentsize}" -eq 56 ]; then
  phoff_offset=32
  phoff_size=8
else
  phoff_offset=28
  phoff_size=4
fi
# EI_DATA (byte 5): 1 = little-endian, 2 = big-endian
ei_data=$(dd if="${SCRATCH_SO}" bs=1 skip=5 count=1 2>/dev/null | od -An -tu1 | tr -d ' ')
offset="${new_phoff}"
for i in $(seq 0 $((phoff_size - 1))); do
  if [ "${ei_data}" -eq 2 ]; then
    byte=$(( (offset >> (8 * (phoff_size - 1 - i))) & 0xff ))
  else
    byte=$(( (offset >> (8 * i)) & 0xff ))
  fi
  printf "%b" "\\$(printf '%03o' "${byte}")" | dd of="${SCRATCH_SO}" bs=1 seek=$((phoff_offset + i)) count=1 conv=notrunc 2>/dev/null
done

# Verify PHT was moved correctly
verify_phoff=$(${READELF} -h "${SCRATCH_SO}" | awk '/Start of program headers:/{print $5}')
if [ "${verify_phoff}" != "${new_phoff}" ]; then
  echo "ERROR: Failed to relocate PHT (expected offset ${new_phoff}, got ${verify_phoff})"
  exit 1
fi

# Now for the actual test: add a DT_NEEDED and force patchelf to grow the PHT.
# It should detect that there's no room to grow it in place.
"${PATCHELF}" --add-needed libfoo.so "${SCRATCH_SO}"

# Verify .adjacent_data still contains 16 'z' characters (0x7a)
if ! ${READELF} -p .adjacent_data "${SCRATCH_SO}" 2>&1 | grep -q "zzzzzzzzzzzzzzzz"; then
  echo "ERROR: .adjacent_data was corrupted by PHT expansion!"
  ${READELF} -x .adjacent_data "${SCRATCH_SO}"
  exit 1
fi
