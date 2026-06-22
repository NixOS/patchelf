#! /bin/sh -e
# Editing a cached binary's dependency set must drop the now-stale resolution
# cache note: the note resolves this binary's DT_NEEDED entries, so changing
# them invalidates it. A no-op edit that does not change the dependency set must
# leave the valid note in place.
SCRATCH=scratch/$(basename "$0" .sh)
READELF=${READELF:-readelf}
PATCHELF=$(readlink -f "../src/patchelf")

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}/libs"
cp libfoo.so libbar.so "${SCRATCH}/libs/"

note_present() {
    ${READELF} -SW "$1" | grep -q "\.note\.nixos\.ldcache"
}

make_cached() {
    cp main "$1"
    ${PATCHELF} --set-rpath "$(pwd)/${SCRATCH}/libs" "$1"
    ${PATCHELF} --build-resolution-cache "$1"
    if ! note_present "$1"; then
        echo "FAIL: test setup did not create a resolution cache note in $1"
        exit 1
    fi
}

failures=0

check_dropped() {
    if note_present "$2"; then
        echo "FAIL: stale resolution cache survived $1"
        failures=$((failures + 1))
    fi
}

check_kept() {
    if ! note_present "$2"; then
        echo "FAIL: valid resolution cache wrongly dropped by $1"
        failures=$((failures + 1))
    fi
}

# A real change to the dependency set drops the note.
bin="${SCRATCH}/main-add"
make_cached "$bin"
${PATCHELF} --add-needed libbar.so "$bin"
check_dropped "--add-needed" "$bin"

bin="${SCRATCH}/main-remove"
make_cached "$bin"
${PATCHELF} --remove-needed libfoo.so "$bin"
check_dropped "--remove-needed" "$bin"

bin="${SCRATCH}/main-replace"
make_cached "$bin"
${PATCHELF} --replace-needed libfoo.so libqux.so "$bin"
check_dropped "--replace-needed" "$bin"

# A no-op edit (the named library is not a dependency) keeps the valid note.
bin="${SCRATCH}/main-noop-remove"
make_cached "$bin"
${PATCHELF} --remove-needed libabsent.so "$bin"
check_kept "--remove-needed (absent lib)" "$bin"

bin="${SCRATCH}/main-noop-replace"
make_cached "$bin"
${PATCHELF} --replace-needed libabsent.so libwhatever.so "$bin"
check_kept "--replace-needed (absent lib)" "$bin"

if [ "$failures" != 0 ]; then
    exit 1
fi

echo "PASS"
