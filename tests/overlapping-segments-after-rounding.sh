#! /bin/sh -e

PATCHELF=$(readlink -f "../src/patchelf")
SCRATCH="scratch/$(basename "$0" .sh)"
READELF=${READELF:-readelf}

EXEC_NAME="overlapping-segments-after-rounding"

check_load_pages() {
    # The fixture needs NVHPC libraries that are absent on some builders.
    # Inspect the page-rounded LOAD ranges without running the loader.
    load_pages=$("${READELF}" -lW "$1" | awk '$1 == "LOAD" { print $3, $6; count++ } END { if (count < 2) exit 1 }')
    printf '%s\n' "${load_pages}" |
    (
        previous_end=0
        while read -r addr size; do
            start=$((addr / 4096 * 4096))
            end=$(((addr + size + 4095) / 4096 * 4096))
            if test "${start}" -lt "${previous_end}"; then
                echo "overlapping LOAD pages in $1" >&2
                exit 1
            fi
            previous_end=${end}
        done
    )
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
