#! /bin/sh -e

PATCHELF=$(readlink -f "../src/patchelf")
SCRATCH="scratch/$(basename "$0" .sh)"
NM=${NM:-nm}
STRINGS=${STRINGS:-strings}

LIB_NAME="${PWD}/libshared-rpath.so"

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"
cd "${SCRATCH}"

has_x() {
    ${STRINGS} "$1" | grep -c "XXXXXXXX"
}

${NM} -D "${LIB_NAME}" | grep a_symbol_name
previous_cnt="$(${STRINGS} "${LIB_NAME}" | grep -c a_symbol_name)"

echo "#### Number of a_symbol_name strings in the library: $previous_cnt"

echo "#### Rename the rpath to something larger than the original"
# Pathelf should detect that the rpath string is shared with the symbol name string and avoid
# tainting the string with Xs
"${PATCHELF}" --set-rpath a_very_big_rpath_that_is_larger_than_original  --output liblarge-rpath.so "${LIB_NAME}"

echo "#### Checking symbol is still there"
${NM} -D liblarge-rpath.so | grep a_symbol_name

echo "#### Checking there are no Xs"
[ "$(has_x liblarge-rpath.so)" -eq 0 ] || exit 1

current_cnt="$(${STRINGS} liblarge-rpath.so | grep -c a_symbol_name)"
echo "#### Number of a_symbol_name strings in the modified library: $current_cnt"
[ "$current_cnt" -eq "$previous_cnt" ] || exit 1

echo "#### Rename the rpath to something shorter than the original"
# Pathelf should detect that the rpath string is shared with the symbol name string and avoid
# overwriting the existing string
"${PATCHELF}" --set-rpath shrt_rpth  --output libshort-rpath.so "${LIB_NAME}"

echo "#### Checking symbol is still there"
${NM} -D libshort-rpath.so | grep a_symbol_name

echo "#### Number of a_symbol_name strings in the modified library: $current_cnt"
current_cnt="$(${STRINGS} libshort-rpath.so | grep -c a_symbol_name)"
[ "$current_cnt" -eq "$previous_cnt" ] || exit 1

echo "#### Now liblarge-rpath.so should have its own rpath, so it should be allowed to taint it"
"${PATCHELF}" --set-rpath a_very_big_rpath_that_is_larger_than_original__even_larger  --output liblarge-rpath2.so liblarge-rpath.so
[ "$(has_x liblarge-rpath2.so)" -eq 1 ] || exit 1
