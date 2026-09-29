#! /bin/sh -e

if test "$(uname -m)" != x86_64 || test "$(uname)" != Linux; then
    exit 77
fi

SCRATCH="scratch/$(basename "$0" .sh)"
READELF=${READELF:-readelf}

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"
cp main-no-pie "${SCRATCH}/main"

first_load_addr() {
    "${READELF}" -lW "$1" | awk '$1 == "LOAD" { print $3; exit }'
}

original_load=$(first_load_addr "${SCRATCH}/main")
../src/patchelf --set-rpath "$(printf '%0800d' 0)" "${SCRATCH}/main"
modified_load=$(first_load_addr "${SCRATCH}/main")

# This growth fits below the original split LOAD with one extra page.
test "$((original_load - modified_load))" -eq 4096

exitCode=0
LD_LIBRARY_PATH=. "${SCRATCH}/main" || exitCode=$?
test "${exitCode}" -eq 46
