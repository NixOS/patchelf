#! /bin/sh -e

if test "$(uname -m)" != x86_64 || test "$(uname)" != Linux; then
    exit 77
fi

SCRATCH="scratch/$(basename "$0" .sh)"
READELF=${READELF:-readelf}

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"
cp notes-after-interp "${SCRATCH}/main"

# Eight bytes longer than the original, so the first rewrite only moves
# .interp and always splits off a header LOAD with little slack.
interpreter=$(../src/patchelf --print-interpreter notes-after-interp)
newInterpreter="$(dirname "${interpreter}")/////////$(basename "${interpreter}")"
../src/patchelf --set-interpreter "${newInterpreter}" "${SCRATCH}/main"

# The second rewrite moves the notes and splits their PT_NOTE, so the program
# header table grows past that slack. The header LOAD must grow with it.
../src/patchelf --set-rpath "$(pwd):$(printf '%0200d' 0)" "${SCRATCH}/main"

check_phdr_covered() {
    phdr=$("${READELF}" -lW "${SCRATCH}/main" | awk '$1 == "PHDR" { print $2, $5 }')
    read -r phdr_offset phdr_size <<EOF
${phdr}
EOF
    phdr_end=$((phdr_offset + phdr_size))
    "${READELF}" -lW "${SCRATCH}/main" | awk '$1 == "LOAD" { print $2, $5 }' | {
        covered=0
        while read -r offset size; do
            if test "$((offset))" -le "$((phdr_offset))" &&
                test "$((offset + size))" -ge "${phdr_end}"; then
                covered=1
            fi
        done
        test "${covered}" -eq 1
    }
}

check_phdr_covered

"${SCRATCH}/main"

# A third rewrite must also preserve coverage when the header LOAD grows.
../src/patchelf --add-rpath "$(printf '%06000d' 0)" "${SCRATCH}/main"
check_phdr_covered
"${SCRATCH}/main"
