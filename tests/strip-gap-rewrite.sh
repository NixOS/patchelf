#! /bin/sh -e

if test "$(uname -m)" != x86_64 || test "$(uname)" != Linux; then
    exit 77
fi

SCRATCH="scratch/$(basename "$0" .sh)"
READELF=${READELF:-readelf}
STRIP=${STRIP:-strip}

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"
cp main-no-pie-rpath "${SCRATCH}/main"

# The oversized page leaves file padding between the LOADs for strip to remove.
../src/patchelf --page-size 8192 --set-rpath "$(printf '%0800d' 0)" "${SCRATCH}/main"
"${STRIP}" "${SCRATCH}/main"

# Guard the precondition: the first two LOADs must map offsets to addresses
# differently, otherwise this test exercises nothing.
"${READELF}" -lW "${SCRATCH}/main" | awk '$1 == "LOAD" { print $3, $2 }' | {
    read -r addr1 off1
    read -r addr2 off2
    test "$((addr1 - off1))" -ne "$((addr2 - off2))"
}

../src/patchelf --set-rpath "$(printf '%01600d' 0)" "${SCRATCH}/main"

exitCode=0
LD_LIBRARY_PATH=. "${SCRATCH}/main" || exitCode=$?
test "${exitCode}" -eq 46
