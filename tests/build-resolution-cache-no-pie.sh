#! /bin/sh -e
# Regression test for the ET_EXEC (non-PIE) path of --build-resolution-cache.
#
# The default build-resolution-cache.sh fixture is PIE (ET_DYN), so it only
# exercises rewriteSectionsLibrary(). This test uses a non-PIE executable and
# forces its file size to a page boundary, which triggers the in-place section
# header table rewrite to overwrite the note's Elf_Nhdr (the note's own section
# header lands exactly on the note offset). The note then becomes unparseable.
SCRATCH=scratch/$(basename "$0" .sh)
READELF=${READELF:-readelf}
PATCHELF=$(readlink -f "../src/patchelf")

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"/libs

cp main-no-pie "${SCRATCH}/main"
cp libfoo.so "${SCRATCH}/libs/"
cp libbar.so "${SCRATCH}/libs/"

# The fixture must be a non-PIE executable; if the toolchain ignored -no-pie
# there is nothing to test here.
if ! ${READELF} -h "${SCRATCH}/main" | grep -q "Type:.*EXEC"; then
    echo "SKIP: toolchain did not produce an ET_EXEC binary"
    exit 77
fi

${PATCHELF} --set-rpath "$(pwd)/${SCRATCH}/libs" "${SCRATCH}/main"

# Force the section header table to end on a page boundary, the layout that
# triggers the corruption.
./pad-to-page "${SCRATCH}/main"

${PATCHELF} --build-resolution-cache "${SCRATCH}/main"

# The note must still be present and parseable: readelf prints an "invalid
# namesz" warning when the Elf_Nhdr has been clobbered.
notes=$(${READELF} -n "${SCRATCH}/main" 2>&1)
echo "$notes"
if echo "$notes" | grep -q "invalid namesz"; then
    echo "FAIL: note header was overwritten by the section header table"
    exit 1
fi
if ! echo "$notes" | grep -q "NixOS"; then
    echo "FAIL: no NixOS note found"
    exit 1
fi

# The descriptor must still resolve the dependency.
strings=$(${READELF} -p .note.nixos.ldcache "${SCRATCH}/main")
echo "$strings"
if ! echo "$strings" | grep -q "${SCRATCH}/libs/libfoo.so"; then
    echo "FAIL: cache does not resolve libfoo.so"
    exit 1
fi

# The patched binary must still load and run.
exitCode=0
LD_LIBRARY_PATH="$(pwd)/${SCRATCH}/libs" "${SCRATCH}/main" || exitCode=$?
if [ "$exitCode" != 46 ]; then
    echo "FAIL: bad exit code $exitCode (expected 46)"
    exit 1
fi

echo "PASS"
