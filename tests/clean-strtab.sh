#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)
PATCHELF=$(readlink -f "../src/patchelf")

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

cp libfoo.so "${SCRATCH}/"

cd "${SCRATCH}"

the_string=VERY_SPECIFIC_STRING
check_count() {
    count="$(strings libfoo.so | grep -c $the_string || true)"
    expected=$1
    echo "####### Checking count. Expected: $expected"
    [ "$count" = "$expected" ] || exit 1
}

check_count 0

${PATCHELF} --clean-strtab libfoo.so
check_count 0

${PATCHELF} --add-needed $the_string libfoo.so
check_count 1

${PATCHELF} --remove-needed $the_string libfoo.so
check_count 1

${PATCHELF} --clean-strtab libfoo.so
check_count 0
