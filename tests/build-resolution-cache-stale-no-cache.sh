#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)
READELF=${READELF:-readelf}
OBJCOPY=${OBJCOPY:-objcopy}
PATCHELF=$(readlink -f "../src/patchelf")

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}/libsA" "${SCRATCH}/empty"
printf stale > "${SCRATCH}/stale-note"

cp libfoo.so "${SCRATCH}/libsA/"

note_present() {
    ${READELF} -SW "$1" | grep -q "\.note\.nixos\.ldcache"
}

make_cached() {
    cp main "$1"
    ${PATCHELF} --set-rpath "$(pwd)/${SCRATCH}/libsA" "$1"
    ${PATCHELF} --build-resolution-cache "$1"
    if ! note_present "$1"; then
        echo "FAIL: test setup did not create a resolution cache note in $1"
        exit 1
    fi
}

ensure_stale_note() {
    if note_present "$1"; then
        return
    fi
    ${OBJCOPY} --add-section .note.nixos.ldcache="${SCRATCH}/stale-note" "$1"
    if ! note_present "$1"; then
        echo "FAIL: test setup did not create a stale resolution cache note in $1"
        exit 1
    fi
}

failures=0

# Rebuilding when a note is present but nothing can be resolved must fail and
# leave the stale note untouched. Assert the message too: it must say the note
# is already present, and must not carry a stale strerror suffix (the access()
# probes set errno; the failure path has to clear it).
expect_stale_failure() {
    label=$1
    bin=$2
    set +e
    err=$(${PATCHELF} --build-resolution-cache "$bin" 2>&1 >/dev/null)
    ec=$?
    set -e
    if [ "$ec" = 0 ]; then
        echo "FAIL: stale resolution cache survived ${label}"
        failures=$((failures + 1))
        return
    fi
    if ! echo "$err" | grep -q "already present"; then
        echo "FAIL: ${label}: expected 'already present', got: $err"
        failures=$((failures + 1))
    fi
    if echo "$err" | grep -q "No such file or directory"; then
        echo "FAIL: ${label}: error message carries a stale strerror suffix"
        failures=$((failures + 1))
    fi
}

bin="${SCRATCH}/main-no-rpath"
make_cached "$bin"
${PATCHELF} --remove-rpath "$bin"
ensure_stale_note "$bin"
expect_stale_failure "no-runpath rebuild path" "$bin"

bin="${SCRATCH}/main-unresolved"
make_cached "$bin"
${PATCHELF} --set-rpath "$(pwd)/${SCRATCH}/empty" "$bin"
ensure_stale_note "$bin"
expect_stale_failure "unresolved-library rebuild path" "$bin"

if [ "$failures" != 0 ]; then
    exit 1
fi

echo "PASS"
