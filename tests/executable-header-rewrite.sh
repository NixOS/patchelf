#! /bin/sh -e

if test "$(uname -m)" != x86_64 || test "$(uname)" != Linux; then
    exit 77
fi

SCRATCH="scratch/$(basename "$0" .sh)"
READELF=${READELF:-readelf}
pageSize=$(getconf PAGESIZE)

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"
interpreter=$(../src/patchelf --print-interpreter many-syms-no-pie)
newInterpreter="$(pwd)/${SCRATCH}/$(printf '%0200d' 0)"
ln -s "${interpreter}" "${newInterpreter}"

check_load_pages() {
    "${READELF}" -lW "$1" | awk '$1 == "LOAD" { print $3, $6 }' | {
        previous_end=0
        while read -r addr size; do
            test "$((addr / pageSize * pageSize))" -ge "${previous_end}"
            previous_end=$(((addr + size + pageSize - 1) / pageSize * pageSize))
        done
        test "${previous_end}" -gt 0
    }
}

check_dynamic_writable() {
    dynamic=$("${READELF}" -lW "$1" | awk '$1 == "DYNAMIC" { print $3, $6 }')
    read -r addr size <<EOF
${dynamic}
EOF
    dynamic_start=$((addr))
    dynamic_end=$((addr + size))
    test "${dynamic_end}" -gt "${dynamic_start}"

    # Check the LOAD permissions, since PT_DYNAMIC's flags do not control
    # the mapping the loader writes DT_DEBUG into.
    "${READELF}" -lW "$1" | awk '$1 == "LOAD" && /W/ { print $3, $6 }' | {
        writable=0
        while read -r addr size; do
            if test "$((addr))" -le "${dynamic_start}" &&
                test "$((addr + size))" -ge "${dynamic_end}"; then
                writable=1
            fi
        done
        test "${writable}" -eq 1
    }
}

# Large symbol tables make the second rewrite extend the small header LOAD
# created for .interp. Without an RPATH, .dynamic must also become writable.
for rpath in present absent; do
    cp many-syms-no-pie "${SCRATCH}/main"
    if test "${rpath}" = absent; then
        ../src/patchelf --remove-rpath "${SCRATCH}/main"
    fi
    ../src/patchelf --set-interpreter "${newInterpreter}" "${SCRATCH}/main"
    ../src/patchelf --set-rpath "$(pwd)" "${SCRATCH}/main"
    check_load_pages "${SCRATCH}/main"
    check_dynamic_writable "${SCRATCH}/main"
    "${SCRATCH}/main"

    # Later growth must reuse the header LOAD without creating overlapping
    # mappings or exhausting the address space through needless LOAD splits.
    for size in 6000 16000; do
        ../src/patchelf --set-rpath "$(pwd):$(printf "%0${size}d" 0)" "${SCRATCH}/main"
        check_load_pages "${SCRATCH}/main"
        check_dynamic_writable "${SCRATCH}/main"
        "${SCRATCH}/main"
    done
done
