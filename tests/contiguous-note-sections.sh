#! /bin/sh -e

SCRATCH=scratch/$(basename "$0" .sh)

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

cp contiguous-note-sections "${SCRATCH}/"

# Running --set-interpreter on this binary should not produce the following
# error:
# patchelf: cannot normalize PT_NOTE segment: non-contiguous SHT_NOTE sections
../src/patchelf --set-interpreter ld-linux-x86-64.so.2 "${SCRATCH}/contiguous-note-sections"
