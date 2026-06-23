#! /bin/sh -e
# Run-path entries that can't be resolved at patch time -- dynamic-string
# tokens ($ORIGIN/$LIB/$PLATFORM) and glibc-hwcaps directories -- must be
# recorded as "?<dir>" search hints, never as absolute "=<path>" entries.
SCRATCH=scratch/$(basename "$0" .sh)
READELF=${READELF:-readelf}
PATCHELF=$(readlink -f "../src/patchelf")

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}/libs"

cp libfoo.so "${SCRATCH}/libs/"

descriptor() {
    ${READELF} -p .note.nixos.ldcache "$1"
}

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

# libfoo.so is present here, so without the hwcaps guard it would resolve to an
# absolute "=path"; the guard must force a "?" hint regardless.
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
