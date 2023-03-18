#! /bin/sh -e

PATCHELF=$(readlink -f "../src/patchelf")
SCRATCH="scratch/$(basename "$0" .sh)"
READELF=${READELF:-readelf}

EXEC_NAME="overlapping-segments-after-rounding"

if test "$(uname -i)" = x86_64 && test "$(uname)" = Linux; then
    rm -rf "${SCRATCH}"
    mkdir -p "${SCRATCH}"

    cp "${srcdir:?}/${EXEC_NAME}" "${SCRATCH}/"
    cd "${SCRATCH}"

    ${PATCHELF} --force-rpath --remove-rpath --output modified1 "${EXEC_NAME}"

    ldd modified1

    ${PATCHELF} --force-rpath --set-rpath "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" --output modified2 modified1

    ldd modified2
fi
