#! /bin/sh -e
# Linux < 5.18 computes AT_PHDR as load_bias + e_phoff and ignores PT_PHDR.
# When patchelf has to grow a PIE executable it moves the program headers into
# a new PT_LOAD segment, which must then have vaddr == file offset, otherwise
# ld.so is handed a bogus phdr pointer and the program crashes at startup.
SCRATCH=scratch/$(basename "$0" .sh)
READELF=${READELF:-readelf}

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

# Large enough to force the file to grow.
printf '=%.0s' $(seq 1 4096) > "${SCRATCH}/foo.bin"

check() {
    exe="${SCRATCH}/$1"
    cp "$1" "$exe"
    ../src/patchelf --add-rpath @"${SCRATCH}/foo.bin" "$exe"

    phoff=$(LC_ALL=C ${READELF} -h "$exe" | sed -n 's/.*Start of program headers: *\([0-9]*\).*/\1/p')
    # PHDR line: Type Offset VirtAddr ...
    phdr_vaddr=$(LC_ALL=C ${READELF} -lW "$exe" | awk '$1 == "PHDR" { print $3 }')
    phdr_vaddr=$((phdr_vaddr))
    if [ "$phdr_vaddr" != "$phoff" ]; then
        echo "$1: PT_PHDR vaddr ($phdr_vaddr) != e_phoff ($phoff)" >&2
        exit 1
    fi

    "$exe"
}

# simple-pie has a large .bss, so the last page lies above the file size.
check simple-pie
