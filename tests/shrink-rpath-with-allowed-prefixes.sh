#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"
mkdir -p "${SCRATCH}/libsA"
mkdir -p "${SCRATCH}/libsB"

cp main "${SCRATCH}"/
cp libfoo.so libbar.so "${SCRATCH}/libsA/"
cp libfoo.so libbar.so "${SCRATCH}/libsB/"

oldRPath=$(../src/patchelf --print-rpath "${SCRATCH}/main")
if test -z "$oldRPath"; then oldRPath="/oops"; fi
pathA="$(pwd)/${SCRATCH}/libsA"
pathB="$(pwd)/${SCRATCH}/libsB"
../src/patchelf --force-rpath --set-rpath "$oldRPath:$pathA:$pathB" "${SCRATCH}/main"

cp "${SCRATCH}"/main "${SCRATCH}/mainA"
cp "${SCRATCH}"/main "${SCRATCH}/mainB"

../src/patchelf --shrink-rpath "${SCRATCH}/main"
../src/patchelf --shrink-rpath --allowed-rpath-prefixes "$oldRPath:$pathA" "${SCRATCH}/mainA"
../src/patchelf --shrink-rpath --allowed-rpath-prefixes "$oldRPath:$pathB" "${SCRATCH}/mainB"

check() {
    exe=$1
    mustContain=$2
    mustNotContain=$3

    rpath=$(../src/patchelf --print-rpath "$exe")
    echo "RPATH of $exe after: $rpath"

    if ! echo "$rpath" | grep -q "$mustContain"; then
        echo "RPATH didn't contain '$mustContain' when it should have"
        exit 1
    fi

    if echo "$rpath" | grep -q "$mustNotContain"; then
        echo "RPATH contained '$mustNotContain' when it shouldn't have"
        exit 1
    fi
}

check "${SCRATCH}/main"  "$pathA" "$pathB"
check "${SCRATCH}/mainA" "$pathA" "$pathB"
check "${SCRATCH}/mainB" "$pathB" "$pathA"
