#! /bin/sh -e

PATCHELF=$(readlink -f "../src/patchelf")
SCRATCH="scratch/$(basename "$0" .sh)"
READELF=${READELF:-readelf}

EXEC_NAME="overlapping-segments-after-rounding"

# ldd would need the NVHPC libraries the fixture links against.
check_load_pages() {
    "${READELF}" -lW "$1" | awk '$1 == "LOAD" { print $3, $6 }' | {
        previous_end=0
        while read -r addr size; do
            test "$((addr / 4096 * 4096))" -ge "${previous_end}"
            previous_end=$(((addr + size + 4095) / 4096 * 4096))
        done
        test "${previous_end}" -gt 0
    }
}

if test "$(uname -m)" = x86_64 && test "$(uname)" = Linux; then
    rm -rf "${SCRATCH}"
    mkdir -p "${SCRATCH}"

    cp "${srcdir:?}/${EXEC_NAME}" "${SCRATCH}/"
    cd "${SCRATCH}"

    ${PATCHELF} --force-rpath --remove-rpath --output modified1 "${EXEC_NAME}"

    check_load_pages modified1

    ${PATCHELF} --force-rpath --set-rpath "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" --output modified2 modified1

    check_load_pages modified2
fi
