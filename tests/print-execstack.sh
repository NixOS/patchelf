#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)
PATCHELF=$(readlink -f "../src/patchelf")

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

cp simple "${SCRATCH}"/
cp simple-execstack "${SCRATCH}"/

cd "${SCRATCH}"

if ! ${PATCHELF} --print-execstack simple | grep -q 'execstack: -'; then
	echo "wrong execstack detection"
	${PATCHELF} --print-execstack simple
	exit 1
fi

if ! ${PATCHELF} --print-execstack simple-execstack | grep -q 'execstack: X'; then
	echo "wrong execstack detection"
	${PATCHELF} --print-execstack simple-execstack
	exit 1
fi
