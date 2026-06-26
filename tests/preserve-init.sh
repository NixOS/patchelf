#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)
READELF=${READELF:-readelf}

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

cp libcustom-init.so "${SCRATCH}/"

initAddr() {
    "${READELF}" -d "$1" | grep '(INIT)' | awk '{print $NF}'
}
sectAddr() {
    "${READELF}" -SW "$1" | sed -n 's/.* \.init  *PROGBITS  *\([0-9a-f]*\).*/\1/p'
}

before=$(initAddr "${SCRATCH}/libcustom-init.so")
sect=$(sectAddr "${SCRATCH}/libcustom-init.so")

# Precondition: -Wl,-init produced a DT_INIT that does not point at .init.
# If the toolchain didn't, the test is meaningless; skip rather than pass.
if [ -z "$before" ] || [ -z "$sect" ]; then
    echo "skip: toolchain emits no DT_INIT / .init section (e.g. musl)"
    exit 77
fi
if [ "$((before))" -eq "$((0x$sect))" ]; then
    echo "skip: DT_INIT already equals .init sh_addr on this toolchain"
    exit 77
fi

../src/patchelf --set-rpath "$(pwd)/${SCRATCH}" "${SCRATCH}/libcustom-init.so"

after=$(initAddr "${SCRATCH}/libcustom-init.so")

if [ "$((before))" -ne "$((after))" ]; then
    echo "DT_INIT changed: $before -> $after" >&2
    exit 1
fi
