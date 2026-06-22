#! /bin/sh -e
# A binary that already carries a malformed/foreign .note.nixos.ldcache plus a
# resolvable run path reaches the existing-note parse in buildResolutionCache.
# That parse must stay within the note (a note shorter than an Elf_Nhdr must not
# be read past its end and crash patchelf), and the "already present" failure
# must not be polluted by a stale errno (strerror) from the access() probes.
SCRATCH=scratch/$(basename "$0" .sh)
OBJCOPY=${OBJCOPY:-objcopy}
PATCHELF=$(readlink -f "../src/patchelf")

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}/libs"
cp libfoo.so "${SCRATCH}/libs/"

cp main "${SCRATCH}/main"
${PATCHELF} --set-rpath "$(pwd)/${SCRATCH}/libs" "${SCRATCH}/main"

# Inject a 1-byte foreign note under our section name (smaller than an Nhdr).
printf x > "${SCRATCH}/tiny"
${OBJCOPY} --add-section .note.nixos.ldcache="${SCRATCH}/tiny" "${SCRATCH}/main"

# The run path resolves libfoo.so, so buildResolutionCache reaches the
# existing-note parse rather than an earlier bail-out.
set +e
err=$(${PATCHELF} --build-resolution-cache "${SCRATCH}/main" 2>&1 >/dev/null)
ec=$?
set -e
echo "$err"

if [ "$ec" = 139 ] || [ "$ec" = 134 ]; then
    echo "FAIL: patchelf crashed (exit $ec) parsing a malformed note"
    exit 1
fi
if [ "$ec" = 0 ]; then
    echo "FAIL: expected a failure when a note is already present"
    exit 1
fi
if ! echo "$err" | grep -q "already present"; then
    echo "FAIL: expected the 'already present' message, got: $err"
    exit 1
fi
if echo "$err" | grep -q "No such file or directory"; then
    echo "FAIL: error message carries a stale strerror suffix"
    exit 1
fi

echo "PASS"
