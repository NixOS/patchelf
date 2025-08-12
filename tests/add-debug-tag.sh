#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)
READELF=${READELF:-readelf}

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

cp libsimple.so "${SCRATCH}"/

# check there is no DT_DEBUG tag
debugTag=$($READELF -d "${SCRATCH}/libsimple.so")
echo ".dynamic before: $debugTag"
if echo "$debugTag" | grep -q DEBUG; then
    echo "failed --add-debug-tag test. Expected no line with (DEBUG), got: $debugTag"
    exit 1
fi

# set DT_DEBUG
../src/patchelf --add-debug-tag "${SCRATCH}/libsimple.so"

# check there is DT_DEBUG tag
debugTag=$($READELF -d "${SCRATCH}/libsimple.so")
echo ".dynamic before: $debugTag"
if ! echo "$debugTag" | grep -q DEBUG; then
    echo "failed --add-debug-tag test. Expected line with (DEBUG), got: $debugTag"
    exit 1
fi
