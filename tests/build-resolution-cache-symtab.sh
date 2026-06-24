#! /bin/sh -e
# Regression: an rpath edit on a cached binary rewrites headers twice
# (removeResolutionCache + rewriteSections). The st_shndx remap is keyed on
# sectionsByOldIndex; without refreshing that map the second pass double-remaps
# SECTION symbols. The corruption is silent at runtime, so compare the sorted
# multiset of SECTION-symbol names against the unpatched binary (sorted because
# patchelf may legitimately reorder .symtab/.dynsym).
SCRATCH=scratch/$(basename "$0" .sh)
READELF=${READELF:-readelf}
PATCHELF=$(readlink -f "../src/patchelf")

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}/libs"

cp main-emit-relocs "${SCRATCH}/main"
cp libfoo.so "${SCRATCH}/libs/"
cp libbar.so "${SCRATCH}/libs/"

section_syms() {
    ${READELF} -sW "$1" 2>/dev/null | awk '$4=="SECTION"{print ($7=="UND"?"UND":$8)}' | sort
}

section_syms "${SCRATCH}/main" > "${SCRATCH}/expected"
# Some toolchains strip SECTION symbols despite -Wl,--emit-relocs.
if [ "$(wc -l < "${SCRATCH}/expected")" -lt 5 ]; then
    echo "SKIP: fixture has no SECTION symbols to check"
    exit 77
fi

${PATCHELF} --set-rpath "$(pwd)/${SCRATCH}/libs" "${SCRATCH}/main"
${PATCHELF} --build-resolution-cache "${SCRATCH}/main"
if ! ${READELF} -SW "${SCRATCH}/main" | grep -q "\.note\.nixos\.ldcache"; then
    echo "FAIL: test setup did not create a resolution cache note"
    exit 1
fi

# Grow .dynstr so rewriteSections() runs after removeResolutionCache().
${PATCHELF} --set-rpath "$(pwd)/${SCRATCH}/libs:$(pwd)/${SCRATCH}/libs-padding-to-grow-dynstr-xxxxxxxxxxxxxxxxxxxx" "${SCRATCH}/main"

section_syms "${SCRATCH}/main" > "${SCRATCH}/actual"
if ! diff -u "${SCRATCH}/expected" "${SCRATCH}/actual"; then
    echo "FAIL: SECTION symbols no longer describe their own sections (symbol table corrupted)"
    exit 1
fi

exitCode=0
LD_LIBRARY_PATH="$(pwd)/${SCRATCH}/libs" "${SCRATCH}/main" || exitCode=$?
if [ "$exitCode" != 46 ]; then
    echo "FAIL: bad exit code $exitCode (expected 46)"
    exit 1
fi

echo "PASS"
