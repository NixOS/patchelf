#! /bin/sh -e
# Regression test for https://github.com/NixOS/patchelf/issues/622.
#
# Patching a non-PIE binary in a way that grows the program header table
# used to shift every LOAD segment's p_vaddr down by one or more pages,
# producing LOAD segments below the input's lowest p_vaddr. On systems
# where vm.mmap_min_addr equals that lowest p_vaddr (riscv64-linux on
# Ubuntu, x86_64 with hardened sysctls, NixOS initrd with raised
# mmap_min_addr), the kernel refuses the fixed-address mmap and the
# patched binary fails to load.
#
# This test asserts that after patching a non-PIE binary, the lowest
# LOAD p_vaddr is not below the original lowest LOAD p_vaddr.

SCRATCH=scratch/$(basename "$0" .sh)

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"
cp simple "${SCRATCH}/simple"

# Confirm the fixture is actually non-PIE; otherwise the test is silently
# meaningless.
if ! readelf -h "${SCRATCH}/simple" | grep -qE 'Type:\s+EXEC'; then
    echo "skipping test: simple is not a non-PIE EXEC on this toolchain" >&2
    exit 77
fi

# Smallest LOAD p_vaddr from `readelf -lW`. The address is the third
# whitespace-separated column on LOAD lines.
lowest_load_vaddr() {
    readelf -lW "$1" \
        | awk '/^  LOAD/ { print strtonum($3) }' \
        | sort -n \
        | head -1
}

pre=$(lowest_load_vaddr "${SCRATCH}/simple")
echo "pre-patch lowest LOAD vaddr: $(printf '0x%x' "$pre")"

# Force the program header table to grow by adding a long rpath. Combined
# with what's already in the binary this is enough to overflow the
# original PHT space and force a layout change.
long_rpath=$(printf '/very/long/rpath/segment%.0s' $(seq 1 16))
../src/patchelf --force-rpath --set-rpath "$long_rpath" "${SCRATCH}/simple"

post=$(lowest_load_vaddr "${SCRATCH}/simple")
echo "post-patch lowest LOAD vaddr: $(printf '0x%x' "$post")"

if [ "$post" -lt "$pre" ]; then
    echo "FAIL: post-patch lowest LOAD vaddr 0x$(printf '%x' "$post") is below" \
         "pre-patch lowest LOAD vaddr 0x$(printf '%x' "$pre")"
    exit 1
fi

# The patched binary should still load and run correctly. This catches
# layout problems that pass the static check above (e.g. PT_PHDR.p_vaddr
# pointing outside any LOAD segment).
exitCode=0
(cd "${SCRATCH}" && ./simple) || exitCode=$?

if [ "$exitCode" != 0 ]; then
    echo "FAIL: patched binary exited with code $exitCode"
    exit 1
fi

echo "PASS"
