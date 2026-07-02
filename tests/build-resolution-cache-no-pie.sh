#! /bin/sh -e
# ET_EXEC path: with the section header table ending on a page boundary, the
# in-place SHT rewrite would land the note's own header on top of its Elf_Nhdr.
#
# main-no-pie carries a concrete DT_RPATH baked in at link time (see
# tests/Makefile.am), so --build-resolution-cache can resolve the run path
# straight from the linker output. That matters because, after the
# vaddr-underrun fix, using patchelf to set the run path on a non-PIE binary
# appends the rewritten sections at the end of the file and moves the SHT off
# the end, which would make the pad-to-page layout below impossible to build.
SCRATCH=scratch/$(basename "$0" .sh)
READELF=${READELF:-readelf}
PATCHELF=$(readlink -f "../src/patchelf")
LIBDIR=$(pwd)

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

cp main-no-pie "${SCRATCH}/main"

if ! ${READELF} -h "${SCRATCH}/main" | grep -q "Type:.*EXEC"; then
    echo "SKIP: toolchain did not produce an ET_EXEC binary"
    exit 77
fi

# Push the section header table end onto a page boundary, the layout that used
# to corrupt the note. This needs the SHT at the end of the file, which the
# linker output provides because no patchelf section rewrite has run yet.
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
if ! echo "$strings" | grep -q "${LIBDIR}/libfoo.so"; then
    echo "FAIL: cache does not resolve libfoo.so"
    exit 1
fi

exitCode=0
LD_LIBRARY_PATH="${LIBDIR}" "${SCRATCH}/main" || exitCode=$?
if [ "$exitCode" != 46 ]; then
    echo "FAIL: bad exit code $exitCode (expected 46)"
    exit 1
fi

echo "PASS"
