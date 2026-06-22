#! /bin/sh -e
# Regression test for the "?dir" search-hint path of --build-resolution-cache.
#
# patchelf normally resolves each DT_NEEDED soname to an absolute "=<path>" in
# the note. But some run path directories cannot be resolved at patch time:
#
#   * a directory containing a dynamic-string token ($ORIGIN, $LIB, $PLATFORM)
#     is only known once the loader expands it at runtime;
#   * a directory holding a glibc-hwcaps/ subtree may carry a CPU-optimized
#     variant of the library that the loader selects at runtime.
#
# For those, patchelf must record a "?<dir>" hint -- telling the loader to
# search the directory itself -- instead of baking in a path it cannot know is
# correct. This is why the "?dir" branch exists; the cases below exercise it.
SCRATCH=scratch/$(basename "$0" .sh)
READELF=${READELF:-readelf}
PATCHELF=$(readlink -f "../src/patchelf")

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}/libs"

cp libfoo.so "${SCRATCH}/libs/"

descriptor() {
    ${READELF} -p .note.nixos.ldcache "$1"
}

# --- $ORIGIN token: unresolvable until the loader expands it ---
cp main "${SCRATCH}/main-origin"
# $ORIGIN is a literal loader token; it must reach patchelf unexpanded.
# shellcheck disable=SC2016
${PATCHELF} --set-rpath '$ORIGIN/libs' "${SCRATCH}/main-origin"
${PATCHELF} --build-resolution-cache "${SCRATCH}/main-origin"

d=$(descriptor "${SCRATCH}/main-origin")
echo "$d"
# shellcheck disable=SC2016
if ! echo "$d" | grep -qF '?$ORIGIN/libs'; then
    echo "FAIL: \$ORIGIN run path was not recorded as a '?' search hint"
    exit 1
fi
# shellcheck disable=SC2016
if echo "$d" | grep -qF '=$ORIGIN/libs'; then
    echo "FAIL: \$ORIGIN run path was wrongly baked into an absolute '=' path"
    exit 1
fi

# --- glibc-hwcaps directory: the loader picks a CPU-specific variant ---
# libfoo.so is physically present in this directory, so without the glibc-hwcaps
# guard patchelf would resolve it to an absolute "=path"; the guard must force a
# "?" hint regardless.
mkdir -p "${SCRATCH}/hw/glibc-hwcaps"
cp libfoo.so "${SCRATCH}/hw/"
cp main "${SCRATCH}/main-hwcaps"
${PATCHELF} --set-rpath "$(pwd)/${SCRATCH}/hw" "${SCRATCH}/main-hwcaps"
${PATCHELF} --build-resolution-cache "${SCRATCH}/main-hwcaps"

d=$(descriptor "${SCRATCH}/main-hwcaps")
echo "$d"
if ! echo "$d" | grep -qF "?$(pwd)/${SCRATCH}/hw"; then
    echo "FAIL: glibc-hwcaps directory was not recorded as a '?' search hint"
    exit 1
fi
if echo "$d" | grep -qF "=$(pwd)/${SCRATCH}/hw/libfoo.so"; then
    echo "FAIL: library under a glibc-hwcaps dir was wrongly resolved to a path"
    exit 1
fi

echo "PASS"
