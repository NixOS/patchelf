#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

oldLibc=$(../src/patchelf --print-needed big-dynstr | grep -v 'foo\.so')
../src/patchelf --output "${SCRATCH}/big-needed" --replace-needed "${oldLibc}" long_long_very_long_libc.so.6 --replace-needed libfoo.so lf.so big-dynstr

if ! ../src/patchelf --print-needed "${SCRATCH}/big-needed" | grep -Fxq "long_long_very_long_libc.so.6"; then
	echo "library long_long_very_long_libc.so.6 not found as NEEDED"
	../src/patchelf --print-needed "${SCRATCH}/big-needed"
	exit 1
fi

if ! ../src/patchelf --print-needed "${SCRATCH}/big-needed" | grep -Fxq "lf.so"; then
	echo "library lf.so not found as NEEDED"
	../src/patchelf --print-needed "${SCRATCH}/big-needed"
	exit 1
fi

# A suffix replacement (e.g. basename of a full path) reuses the existing
# .dynstr string instead of appending, so the binary must not grow.
inSize=$(wc -c < big-dynstr)
../src/patchelf --output "${SCRATCH}/suffix-needed" --replace-needed libfoo.so foo.so big-dynstr
if ! ../src/patchelf --print-needed "${SCRATCH}/suffix-needed" | grep -Fxq "foo.so"; then
	echo "library foo.so not found as NEEDED"
	exit 1
fi
if [ "$(wc -c < "${SCRATCH}/suffix-needed")" -gt "${inSize}" ]; then
	echo "suffix replacement grew the binary, .dynstr was relocated"
	exit 1
fi

# A non-suffix replacement must still be appended to .dynstr.
../src/patchelf --output "${SCRATCH}/grow-needed" --replace-needed libfoo.so totallynew.so big-dynstr
if ! ../src/patchelf --print-needed "${SCRATCH}/grow-needed" | grep -Fxq "totallynew.so"; then
	echo "library totallynew.so not found as NEEDED"
	exit 1
fi
