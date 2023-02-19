#! /bin/sh
set -e

SCRATCH=scratch/$(basename "$0" .sh)
MAIN_ELF="${SCRATCH}/main"

PATCHELF="../src/patchelf"

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"
cp main "${SCRATCH}"/

echo "Confirming main requires libfoo"
${PATCHELF} --print-needed "${MAIN_ELF}" | grep -q libfoo.so

echo "Testing --add-needed functionality"
${PATCHELF} --add-needed bar.so "${MAIN_ELF}"
${PATCHELF} --print-needed "${MAIN_ELF}" | grep -q bar.so

echo "Testing --remove-needed functionality"
${PATCHELF} --remove-needed bar.so "${MAIN_ELF}"
if ${PATCHELF} --print-needed "${MAIN_ELF}" | grep -q bar.so; then
	echo "ERROR: --remove-needed did not eliminate bar.so!"
	exit 1
fi
