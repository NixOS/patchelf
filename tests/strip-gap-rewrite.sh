#! /bin/sh -e

if test "$(uname -m)" != x86_64 || test "$(uname)" != Linux; then
    exit 77
fi

SCRATCH="scratch/$(basename "$0" .sh)"
READELF=${READELF:-readelf}
STRIP=${STRIP:-strip}

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"
cp main-no-pie "${SCRATCH}/main"

# An 8 KiB insertion leaves a spare file page with this small RPATH.
../src/patchelf --page-size 8192 --set-rpath "$(printf '%0800d' 0)" "${SCRATCH}/main"
"${STRIP}" "${SCRATCH}/main"

load_address() {
    "${READELF}" -lW "$1" | awk -v load_index="$2" '$1 == "LOAD" && ++n == load_index { print $3; exit }'
}

load_offset() {
    "${READELF}" -lW "$1" | awk -v load_index="$2" '$1 == "LOAD" && ++n == load_index { print $2; exit }'
}

# strip removes the spare file page, so the first two LOADs now have
# different address-to-offset mappings.
header_base=$(load_address "${SCRATCH}/main" 1)
second_addr=$(load_address "${SCRATCH}/main" 2)
second_off=$(load_offset "${SCRATCH}/main" 2)
test "$((header_base))" -ne "$((second_addr - second_off))"

../src/patchelf --set-rpath "$(printf '%01600d' 0)" "${SCRATCH}/main"

exitCode=0
LD_LIBRARY_PATH=. "${SCRATCH}/main" || exitCode=$?
test "${exitCode}" -eq 46
