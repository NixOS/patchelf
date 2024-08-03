#! /bin/sh -e
SCRATCH="scratch/$(basename "$0" .sh)"
PATCHELF="$(readlink -f "../src/patchelf")"
READELF="${READELF:-readelf}"
MAIN=symver
LIBNEW=libsymver.so
LIBOLD=libsymver-old.so


rm -rf "$SCRATCH"
mkdir -p "$SCRATCH"

cp $MAIN $LIBNEW $LIBOLD "${SCRATCH}/"

cd "$SCRATCH"

fail() {
    echo $1
    "$READELF" -a -W $MAIN
    "$READELF" -a -W $LIBNEW
    "$READELF" -a -W $LIBOLD
    exit $2
}

# sanity check
exit_code=0
LD_LIBRARY_PATH="$PWD" ./${MAIN} || exit_code=$?
if [ $exit_code -ne 0 ]; then
  fail "basic check" $exit_code
fi

# replace with old version
mv $LIBOLD $LIBNEW

# should NOT run before patch
exit_code=0
LD_LIBRARY_PATH="$PWD" ./${MAIN} || exit_code=$?
if [ $exit_code -eq 0 ]; then
  fail "patch check" 1
fi

${PATCHELF} --remove-needed-version $LIBNEW V2 \
            --remove-needed-version $LIBNEW VER $MAIN || fail "patchelf" -1 

# should run after removing version
exit_code=0
LD_LIBRARY_PATH="$PWD" ./${MAIN} || exit_code=$?
if [ $exit_code -ne 0 ]; then
  fail "patch check" $exit_code
fi
