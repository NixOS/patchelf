#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)
READELF=${READELF:-readelf}
PATCHELF=$(readlink -f "../src/patchelf")

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}/libsA" "${SCRATCH}/libsC"

cp libfoo.so "${SCRATCH}/libsA/"
cp libfoo.so "${SCRATCH}/libsC/"

here=$(pwd)

note_present() {
    ${READELF} -SW "$1" | grep -q "\.note\.nixos\.ldcache"
}

make_cached() {
    cp main "$1"
    ${PATCHELF} --set-rpath "$2" "$1"
    ${PATCHELF} --build-resolution-cache "$1"
    if ! note_present "$1"; then
        echo "FAIL: test setup did not create a resolution cache note in $1"
        exit 1
    fi
}

check_no_stale_note() {
    if note_present "$2"; then
        echo "FAIL: stale resolution cache survived $1"
        failures=$((failures + 1))
    fi
}

failures=0

bin="${SCRATCH}/main-set"
# The edit must succeed (the script runs under -e, so a non-zero exit aborts
# and fails the test) and then leave no stale note. Gating the check on the
# edit's exit code would silently skip it if the edit regressed to an error.
make_cached "$bin" "${here}/${SCRATCH}/libsA"
${PATCHELF} --set-rpath "${here}/${SCRATCH}/libsC" "$bin"
check_no_stale_note "--set-rpath" "$bin"

bin="${SCRATCH}/main-add"
make_cached "$bin" "${here}/${SCRATCH}/libsA"
${PATCHELF} --add-rpath "${here}/${SCRATCH}/libsC" "$bin"
check_no_stale_note "--add-rpath" "$bin"

bin="${SCRATCH}/main-remove"
make_cached "$bin" "${here}/${SCRATCH}/libsA"
${PATCHELF} --remove-rpath "$bin"
check_no_stale_note "--remove-rpath" "$bin"

bin="${SCRATCH}/main-shrink"
make_cached "$bin" "${here}/${SCRATCH}/libsA:${here}/${SCRATCH}/libsC"
${PATCHELF} --shrink-rpath --allowed-rpath-prefixes "${here}/${SCRATCH}/libsC" "$bin"
check_no_stale_note "--shrink-rpath" "$bin"

if [ "$failures" != 0 ]; then
    exit 1
fi

echo "PASS"
