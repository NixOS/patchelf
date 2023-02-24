#! /bin/sh -e

SCRATCH=scratch/$(basename "$0" .sh)
PATCHELF=$(readlink -f "../src/patchelf")

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

cp simple "${SCRATCH}/"
cp libfoo.so "${SCRATCH}/"
cp libbar.so "${SCRATCH}/"

cd "${SCRATCH}"

${PATCHELF} --add-needed ./libbar.so simple

###############################################################################
# Test that repeatedly modifying a string inside a shared library does not
# corrupt it due to the addition of multiple PT_LOAD entries
###############################################################################
load_segments_before=$(readelf -W -l libbar.so | grep -c LOAD)

for _ in $(seq 1 100)
do
    ${PATCHELF} --set-soname ./libbar.so libbar.so
    ${PATCHELF} --set-soname libbar.so libbar.so
    ./simple || exit 1
done

load_segments_after=$(readelf -W -l libbar.so | grep -c LOAD)

###############################################################################
# To be even more strict, check that we don't add too many extra LOAD entries
###############################################################################
echo "Segments before: ${load_segments_before} and after: ${load_segments_after}"
if [ "${load_segments_after}" -gt $((load_segments_before + 2)) ]
then
    exit 1
fi
