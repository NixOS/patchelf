#! /bin/sh -e
# Regression test: editing a cached binary's run path must not corrupt the
# symbol table.
#
# When a binary already carries a resolution cache note, an rpath edit first
# calls removeResolutionCache() (which rewrites the headers) and then, if the
# new run path grows .dynstr, rewriteSections() rewrites the headers a second
# time. The symbol-table st_shndx remap is keyed on sectionsByOldIndex, which
# is built once at parse and never rebuilt, so running it twice double-remaps
# every symbol whose section moved: a SECTION symbol ends up describing the
# wrong section (and one is shifted to UND).
#
# The corruption is silent -- the binary still loads and runs, and readelf -a
# reports no error -- so this test checks the symbol table directly. Correct
# patching preserves the set of sections described by SECTION symbols: each
# named SECTION symbol keeps pointing at a section of the same name, so the
# multiset of those names must stay identical to the unpatched binary.
#
# We compare the *sorted* multiset, not readelf's listing order: patchelf sorts
# sections by file offset, so a run-path edit can legitimately swap the
# positions of .symtab and .dynsym in the section header table. That reorders
# how readelf -sW concatenates the two tables without moving any symbol to a
# wrong section, and an order-sensitive check would flag it as a false failure
# (seen on non-x86 toolchains whose layout triggers the swap).
SCRATCH=scratch/$(basename "$0" .sh)
READELF=${READELF:-readelf}
PATCHELF=$(readlink -f "../src/patchelf")

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}/libs"

cp main-emit-relocs "${SCRATCH}/main"
cp libfoo.so "${SCRATCH}/libs/"
cp libbar.so "${SCRATCH}/libs/"

# The fixture must retain named SECTION symbols in .symtab for this test to
# mean anything; some toolchains strip them despite -Wl,--emit-relocs.
section_syms() {
    ${READELF} -sW "$1" 2>/dev/null | awk '$4=="SECTION"{print ($7=="UND"?"UND":$8)}' | sort
}

section_syms "${SCRATCH}/main" > "${SCRATCH}/expected"
if [ "$(wc -l < "${SCRATCH}/expected")" -lt 5 ]; then
    echo "SKIP: fixture has no SECTION symbols to check"
    exit 77
fi

# Cache the binary against a short run path that resolves libfoo.so.
${PATCHELF} --set-rpath "$(pwd)/${SCRATCH}/libs" "${SCRATCH}/main"
${PATCHELF} --build-resolution-cache "${SCRATCH}/main"
if ! ${READELF} -SW "${SCRATCH}/main" | grep -q "\.note\.nixos\.ldcache"; then
    echo "FAIL: test setup did not create a resolution cache note"
    exit 1
fi

# Edit the run path with a longer string so .dynstr has to grow: this is the
# path that rewrites the headers twice.
${PATCHELF} --set-rpath "$(pwd)/${SCRATCH}/libs:$(pwd)/${SCRATCH}/libs-padding-to-grow-dynstr-xxxxxxxxxxxxxxxxxxxx" "${SCRATCH}/main"

# Removing the cache note must not corrupt the symbol table.
section_syms "${SCRATCH}/main" > "${SCRATCH}/actual"
if ! diff -u "${SCRATCH}/expected" "${SCRATCH}/actual"; then
    echo "FAIL: SECTION symbols no longer describe their own sections (symbol table corrupted)"
    exit 1
fi

# Belt and suspenders: the binary must still load and run.
exitCode=0
LD_LIBRARY_PATH="$(pwd)/${SCRATCH}/libs" "${SCRATCH}/main" || exitCode=$?
if [ "$exitCode" != 46 ]; then
    echo "FAIL: bad exit code $exitCode (expected 46)"
    exit 1
fi

echo "PASS"
