#! /bin/sh -e
# Rebuilding when a note is already present but does not match the freshly
# resolved descriptor must fail loudly. The error must say the note is already
# present and must not carry a stale strerror suffix from the access() probes.
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
    note_present "$1" && return
    ${OBJCOPY} --add-section .note.nixos.ldcache="${SCRATCH}/stale-note" "$1"
    if ! note_present "$1"; then
        echo "FAIL: test setup did not create a stale resolution cache note in $1"
        exit 1
    fi
}

failures=0

expect_stale_failure() {
    label=$1
    bin=$2
    set +e
    err=$(${PATCHELF} --build-resolution-cache "$bin" 2>&1 >/dev/null)
    ec=$?
    set -e
    echo "$err"
    if [ "$ec" = 139 ] || [ "$ec" = 134 ]; then
        echo "FAIL: ${label}: patchelf crashed (exit $ec)"
        failures=$((failures + 1))
        return
    fi
    if [ "$ec" = 0 ]; then
        echo "FAIL: ${label}: stale resolution cache survived"
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

# Stale note + nothing to resolve (early bail-outs).
bin="${SCRATCH}/main-no-rpath"
make_cached "$bin"
${PATCHELF} --remove-rpath "$bin"
ensure_stale_note "$bin"
expect_stale_failure "no-runpath rebuild" "$bin"

bin="${SCRATCH}/main-unresolved"
make_cached "$bin"
${PATCHELF} --set-rpath "$(pwd)/${SCRATCH}/empty" "$bin"
ensure_stale_note "$bin"
expect_stale_failure "unresolved-library rebuild" "$bin"

# Malformed foreign note shorter than an Elf_Nhdr: the existing-note parse must
# stay in bounds and fall through to the failure.
bin="${SCRATCH}/main-malformed"
cp main "$bin"
${PATCHELF} --set-rpath "$(pwd)/${SCRATCH}/libsA" "$bin"
printf x > "${SCRATCH}/tiny"
${OBJCOPY} --add-section .note.nixos.ldcache="${SCRATCH}/tiny" "$bin"
expect_stale_failure "malformed-note rebuild" "$bin"

if [ "$failures" != 0 ]; then
    exit 1
fi

echo "PASS"
