#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)
READELF=${READELF:-readelf}
PATCHELF=$(readlink -f "../src/patchelf")

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"/libsA
mkdir -p "${SCRATCH}"/libsB
mkdir -p "${SCRATCH}"/libsC

cp main "${SCRATCH}"/
cp libfoo.so "${SCRATCH}/libsA/"
cp libbar.so "${SCRATCH}/libsB/"
cp libfoo.so "${SCRATCH}/libsC/"

${PATCHELF} --set-rpath "$(pwd)/${SCRATCH}/libsA:$(pwd)/${SCRATCH}/libsB" "${SCRATCH}/main"
${PATCHELF} --build-resolution-cache "${SCRATCH}/main"

# The note must be present and owned by "NixOS".
notes=$(${READELF} -n "${SCRATCH}/main")
echo "$notes"
if ! echo "$notes" | grep -q "NixOS"; then
    echo "FAIL: no NixOS note found"
    exit 1
fi

# There must be exactly one allocated .note.nixos.ldcache section ...
sections=$(${READELF} -SW "${SCRATCH}/main")
count=$(echo "$sections" | grep -c "\.note\.nixos\.ldcache")
if [ "$count" != 1 ]; then
    echo "FAIL: expected 1 .note.nixos.ldcache section, got $count"
    exit 1
fi
if ! echo "$sections" | grep "\.note\.nixos\.ldcache" | grep -q " A "; then
    echo "FAIL: .note.nixos.ldcache is not allocated (SHF_ALLOC)"
    exit 1
fi

# ... covered by a PT_NOTE program header (so the loader can find it) ...
if ! ${READELF} -lW "${SCRATCH}/main" | grep -q "NOTE"; then
    echo "FAIL: no PT_NOTE program header"
    exit 1
fi

# ... and the descriptor must reference the resolved dependency.
strings=$(${READELF} -p .note.nixos.ldcache "${SCRATCH}/main")
echo "$strings"
if ! echo "$strings" | grep -q "libfoo.so"; then
    echo "FAIL: cache does not reference libfoo.so"
    exit 1
fi
if ! echo "$strings" | grep -q "${SCRATCH}/libsA/libfoo.so"; then
    echo "FAIL: cache does not resolve libfoo.so to libsA"
    exit 1
fi

# Building again is idempotent: it must not add a second note.
${PATCHELF} --build-resolution-cache "${SCRATCH}/main"
count=$(${READELF} -SW "${SCRATCH}/main" | grep -c "\.note\.nixos\.ldcache")
if [ "$count" != 1 ]; then
    echo "FAIL: not idempotent, got $count note sections"
    exit 1
fi

# DT_RPATH (no DT_RUNPATH) must also get a cache.
cp main "${SCRATCH}/main-rpath"
${PATCHELF} --force-rpath --set-rpath "$(pwd)/${SCRATCH}/libsA" "${SCRATCH}/main-rpath"
if ${READELF} -d "${SCRATCH}/main-rpath" | grep -q "RUNPATH"; then
    echo "FAIL: expected DT_RPATH, got DT_RUNPATH"
    exit 1
fi
${PATCHELF} --build-resolution-cache "${SCRATCH}/main-rpath"
if ! ${READELF} -p .note.nixos.ldcache "${SCRATCH}/main-rpath" | grep -q "${SCRATCH}/libsA/libfoo.so"; then
    echo "FAIL: DT_RPATH binary did not get a resolution cache"
    exit 1
fi

# Changing the run path removes the existing cache note; rebuilding afterwards
# writes a fresh note that resolves to the new paths.
cp main "${SCRATCH}/main-stale"
${PATCHELF} --set-rpath "$(pwd)/${SCRATCH}/libsA" "${SCRATCH}/main-stale"
${PATCHELF} --build-resolution-cache "${SCRATCH}/main-stale"
${PATCHELF} --set-rpath "$(pwd)/${SCRATCH}/libsC" "${SCRATCH}/main-stale"
if ${READELF} -SW "${SCRATCH}/main-stale" | grep -q "\.note\.nixos\.ldcache"; then
    echo "FAIL: changing the run path should remove the old resolution cache"
    exit 1
fi
${PATCHELF} --build-resolution-cache "${SCRATCH}/main-stale"
if ! ${READELF} -p .note.nixos.ldcache "${SCRATCH}/main-stale" | grep -q "${SCRATCH}/libsC/libfoo.so"; then
    echo "FAIL: rebuilding after a run path change did not resolve to libsC"
    exit 1
fi

# No run path: warn, write nothing.
cp main "${SCRATCH}/main-norpath"
${PATCHELF} --remove-rpath "${SCRATCH}/main-norpath"
warn=$(${PATCHELF} --build-resolution-cache "${SCRATCH}/main-norpath" 2>&1 >/dev/null)
echo "$warn"
if ! echo "$warn" | grep -q "no DT_NEEDED entries or run path"; then
    echo "FAIL: expected a warning when there is no run path"
    exit 1
fi
if ${READELF} -SW "${SCRATCH}/main-norpath" | grep -q "\.note\.nixos\.ldcache"; then
    echo "FAIL: a cache was written despite no run path"
    exit 1
fi

if ${PATCHELF} --force-rpath --build-resolution-cache "${SCRATCH}/main" 2>/dev/null; then
    echo "FAIL: --build-resolution-cache should be rejected with --force-rpath"
    exit 1
fi

exitCode=0
LD_LIBRARY_PATH="$(pwd)/${SCRATCH}/libsA:$(pwd)/${SCRATCH}/libsB" "${SCRATCH}/main" || exitCode=$?
if [ "$exitCode" != 46 ]; then
    echo "FAIL: bad exit code $exitCode (expected 46)"
    exit 1
fi

echo "PASS"
