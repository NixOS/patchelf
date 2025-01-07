#! /bin/sh -e

PATCHELF=$(readlink -f "../src/patchelf")
SCRATCH="scratch/$(basename "$0" .sh)"
READELF=${READELF:-readelf}

EXEC_NAME="short-first-segment"

if test "$(uname -m)" != amd64 || test "$(uname)" != Linux; then
    echo "skipping test: amd64 Linux required"
    exit 77
fi

if ! command -v gzip >/dev/null; then
    echo "skipping test: gzip not found"
    exit 77
fi

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

gzip -c -d "${srcdir:?}/${EXEC_NAME}.gz" > "${SCRATCH}/${EXEC_NAME}"
cd "${SCRATCH}"

ldd "${EXEC_NAME}"


${PATCHELF} --set-rpath "$(printf '=%.0s' $(seq 1 4096))" --output modified1 "${EXEC_NAME}"
${PATCHELF} --add-rpath "$(printf '=%.0s' $(seq 1 4096))" modified1

ldd modified1

${PATCHELF} --add-needed "libXcursor.so.1" --output modified2 modified1
ldd modified2
