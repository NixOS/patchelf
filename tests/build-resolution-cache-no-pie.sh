#! /bin/sh -e
# ET_EXEC path: with the section header table ending on a page boundary, the
# in-place SHT rewrite would land the note's own header on top of its Elf_Nhdr.
SCRATCH=scratch/$(basename "$0" .sh)
READELF=${READELF:-readelf}
PATCHELF=$(readlink -f "../src/patchelf")

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"/libs

cp main-no-pie "${SCRATCH}/main"
cp libfoo.so "${SCRATCH}/libs/"
cp libbar.so "${SCRATCH}/libs/"

if ! ${READELF} -h "${SCRATCH}/main" | grep -q "Type:.*EXEC"; then
    echo "SKIP: toolchain did not produce an ET_EXEC binary"
    exit 77
fi

${PATCHELF} --set-rpath "$(pwd)/${SCRATCH}/libs" "${SCRATCH}/main"
./pad-to-page "${SCRATCH}/main"

${PATCHELF} --build-resolution-cache "${SCRATCH}/main"

# readelf warns "invalid namesz" when the Elf_Nhdr has been clobbered.
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

strings=$(${READELF} -p .note.nixos.ldcache "${SCRATCH}/main")
echo "$strings"
if ! echo "$strings" | grep -q "${SCRATCH}/libs/libfoo.so"; then
    echo "FAIL: cache does not resolve libfoo.so"
    exit 1
fi

exitCode=0
LD_LIBRARY_PATH="$(pwd)/${SCRATCH}/libs" "${SCRATCH}/main" || exitCode=$?
if [ "$exitCode" != 46 ]; then
    echo "FAIL: bad exit code $exitCode (expected 46)"
    exit 1
fi

echo "PASS"
