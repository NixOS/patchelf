#! /bin/sh -e
# Non-PIE executable linked with a max-page-size larger than the runtime page.
# On 32-bit targets patchelf used to relocate .dynamic into the read-only first
# LOAD segment, so the loader segfaulted writing DT_DEBUG. The bug does not
# reproduce on 64-bit, so the check is scoped to ELF32.
SCRATCH=scratch/$(basename "$0" .sh)
READELF=${READELF:-readelf}

skip() { echo "SKIP: $1"; exit 77; }
hdr=$(${READELF} -h large-page)
case $hdr in *Class:*ELF32*) ;; *) skip "not a 32-bit binary" ;; esac
case $hdr in *Type:*EXEC*)  ;; *) skip "toolchain did not produce ET_EXEC" ;; esac
# 32-bit ARM's default image base is 0x10000, so the 2 MiB page alignment makes
# the linker emit a LOAD at vaddr 0. Under qemu-user that hits the host's
# mmap_min_addr and the unpatched binary already cannot run, so the test is not
# meaningful there. (i386's 0x08048000 base leaves room and exercises the fix.)
case $hdr in *'Machine:'*' ARM'*) skip "ARM image base is below max-page-size" ;; esac

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"
cp large-page "${SCRATCH}/app"
cp libfoo.so libbar.so "${SCRATCH}/"

# --add-needed grows .dynamic, forcing patchelf to relocate it. The binary must
# still run: the loader writes DT_DEBUG into .dynamic, which segfaults if it
# landed in a read-only segment.
../src/patchelf --add-needed libfoo.so "${SCRATCH}/app"
LD_LIBRARY_PATH="${SCRATCH}" "${SCRATCH}/app"
