#! /bin/sh -e
# A shared library linked with a max-page-size larger than the runtime page
# size, like RHEL-style distro builds, gets its rewritten dynamic sections
# appended as a new LOAD segment. patchelf used to round both the segment's
# file offset and its virtual address up to the alignment, padding small
# libraries out to whole mebibytes. Only the difference between the two has
# to be a multiple of the alignment, so the rewrite must stay tight.
SCRATCH=scratch/$(basename "$0" .sh)

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

cp libmaxpage.so "${SCRATCH}/"

before=$(wc -c < "${SCRATCH}/libmaxpage.so")

# A soname longer than anything in .dynstr forces the relocation path.
../src/patchelf --set-soname libmaxpage-0123456789abcdef.so.1 "${SCRATCH}/libmaxpage.so"

newSoname=$(../src/patchelf --print-soname "${SCRATCH}/libmaxpage.so")
if test "$newSoname" != libmaxpage-0123456789abcdef.so.1; then
    echo "failed --set-soname test. Expected newSoname: libmaxpage-0123456789abcdef.so.1, got: $newSoname"
    exit 1
fi

after=$(wc -c < "${SCRATCH}/libmaxpage.so")
# The rewrite must stay below the next 2 MiB boundary.
limit=$(( (before + 2097151) / 2097152 * 2097152 ))
if test "$after" -gt "$limit"; then
    echo "file grew from $before to $after bytes, rewrite padded to the alignment"
    exit 1
fi
