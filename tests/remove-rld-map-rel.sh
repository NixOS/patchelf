#! /bin/sh -e
# Regression: removing a .dynamic entry (--remove-rpath / --remove-needed)
# compacts the array in place, which moves DT_MIPS_RLD_MAP_REL to an earlier
# slot. Its value is an offset *relative to the slot's own address*, so it must
# be adjusted by the distance moved or the dynamic linker writes the debug
# pointer into whatever happens to precede .rld_map.
#
# The check is the loader's invariant
#   .dynamic_addr + index(tag) * sizeof(Elf_Dyn) + d_val == .rld_map_addr
# computed from readelf, so it runs on any host without executing the binary.

SCRATCH=scratch/$(basename "$0" .sh)
READELF=${READELF:-readelf}
PATCHELF=../src/patchelf

if ! ${READELF} -d main | grep -q MIPS_RLD_MAP_REL; then
    echo "No MIPS_RLD_MAP_REL dynamic section entry, skipping"
    exit 77
fi

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

# One readelf pass; awk emits a shell arithmetic expression so hex stays in
# the shell (POSIX awk has no hex literals). The -S index "[ N]"/"[NN]" is
# stripped first so the section name is always $1.
check() {
    off=$(( $(${READELF} -SWd "$1" | sed 's/^ *\[[ 0-9]*\]//' | awk '
        $1 == ".dynamic"   { dyn = $3; ent = $6 }
        $1 == ".rld_map"   { rld = $3 }
        /^ 0x/             { i++ }
        /MIPS_RLD_MAP_REL/ { slot = i-1; val = $NF }
        END { printf "0x%s + %d * 0x%s + %s - 0x%s\n", dyn, slot, ent, val, rld }') ))
    [ "$off" -eq 0 ] && return
    echo "$1: DT_MIPS_RLD_MAP_REL misses .rld_map by $off bytes"
    return 1
}

# Sanity: the freshly linked binary satisfies the invariant.
check main

# DT_NEEDED entries come first, so removing one shifts every later entry down.
cp main "${SCRATCH}/needed"
${PATCHELF} --remove-needed libfoo.so "${SCRATCH}/needed"
check "${SCRATCH}/needed"

# Same for --remove-rpath; only meaningful when the toolchain emitted one.
if [ -n "$(${PATCHELF} --print-rpath main)" ]; then
    cp main "${SCRATCH}/rpath"
    ${PATCHELF} --remove-rpath "${SCRATCH}/rpath"
    check "${SCRATCH}/rpath"
fi
