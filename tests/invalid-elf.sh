#! /bin/sh -ue

# Usage: killed_by_signal $?
#
# Returns true if the exit code indicates that the program was killed
# by a signal. This works because the exit code of processes that were
# killed by a signal is 128 plus the signal number.
killed_by_signal() {
    [ "$1" -ge 128 ]
}

# Directory of committed input files (real-world crash repros that can't
# be regenerated).
TEST_DIR=$(dirname "$(readlink -f "$0")")/invalid-elf

# Directory of fixtures generated below.
SCRATCH=scratch/$(basename "$0" .sh)
rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

# --- Generated fixtures ---
# Derive single-field corruptions from a stable committed ELF64-LE binary so
# each one reaches exactly the constructor check it is named after.
base="$TEST_DIR/../no-rpath-prebuild/no-rpath-amd64"

read_le() { # file decoffset width
    # Assemble byte-by-byte so host endianness is irrelevant (the base ELF is
    # little-endian, but this test runs on big-endian hosts too).
    od -An -t u1 -j "$2" -N "$3" "$1" \
        | awk '{v=0; for(i=NF;i>=1;i--) v=v*256+$i; print v}'
}
poke() { # file decoffset hexbytes
    printf '%b' "$3" | dd of="$1" bs=1 seek="$2" conv=notrunc status=none
}

shoff=$(read_le "$base" 40 8)
shstrndx=$(read_le "$base" 62 2)
shdr=$((shoff + shstrndx * 64))
shstrtab_off=$(read_le "$base" $((shdr + 24)) 8)
shstrtab_size=$(read_le "$base" $((shdr + 32)) 8)

cp "$base" "$SCRATCH/invalid-shrstrtab-idx"
poke "$SCRATCH/invalid-shrstrtab-idx" 62 '\377\377'

cp "$base" "$SCRATCH/invalid-shrstrtab-size"
poke "$SCRATCH/invalid-shrstrtab-size" $((shdr + 32)) '\377\377\377\377\377\377\377\177'

cp "$base" "$SCRATCH/invalid-shrstrtab-zero"
poke "$SCRATCH/invalid-shrstrtab-zero" $((shdr + 32)) '\0\0\0\0\0\0\0\0'

cp "$base" "$SCRATCH/invalid-shrstrtab-nonterm"
poke "$SCRATCH/invalid-shrstrtab-nonterm" $((shstrtab_off + shstrtab_size - 1)) 'A'

cp "$base" "$SCRATCH/invalid-shdr-name"
poke "$SCRATCH/invalid-shdr-name" $((shoff + 64)) '\377\377\377\177'

cp "$base" "$SCRATCH/invalid-shentsize"
poke "$SCRATCH/invalid-shentsize" 58 '\060\000'

# --- Test cases ---
# Each test case is listed here as <directory>:<filename>. The names should
# roughly indicate what makes the given ELF file invalid.
TEST_CASES="
    $SCRATCH:invalid-shrstrtab-idx
    $SCRATCH:invalid-shrstrtab-size
    $SCRATCH:invalid-shrstrtab-zero
    $SCRATCH:invalid-shrstrtab-nonterm
    $SCRATCH:invalid-shdr-name
    $SCRATCH:invalid-shentsize
    $TEST_DIR:invalid-phdr-offset
    $TEST_DIR:invalid-phdr-issue-64
"

# shellcheck disable=SC2034
invalid_shrstrtab_idx_MSG='string table index out of bounds'
# shellcheck disable=SC2034
invalid_shrstrtab_size_MSG='data region extends past file end'
# shellcheck disable=SC2034
invalid_shrstrtab_zero_MSG='string table size is zero'
# shellcheck disable=SC2034
invalid_shrstrtab_nonterm_MSG='string table is not zero terminated'
# shellcheck disable=SC2034
invalid_shdr_name_MSG='section name offset out of bounds'
# shellcheck disable=SC2034
invalid_shentsize_MSG='section headers have wrong size'
# shellcheck disable=SC2034
invalid_phdr_offset_MSG='program header table out of bounds'
# shellcheck disable=SC2034
invalid_phdr_issue_64_MSG='program header table out of bounds'

FAILED_TESTS=""

for tcase in $TEST_CASES; do
    dir=${tcase%:*}
    name=${tcase#*:}
    file="$dir/$name"
    if [ ! -r "$file" ]; then
	echo "Cannot read test case: $file"
	exit 1
    fi

    ../src/patchelf --output /dev/null "$file" && res=$? || res=$?
    if killed_by_signal "$res"; then
	FAILED_TESTS="$FAILED_TESTS $name"
    fi

    var=$(echo "$name-MSG" | tr '-' '_')
    msg=
    eval "msg=\${$var}"
    ../src/patchelf --output /dev/null "$file" 2>&1 |
        grep "$msg" >/dev/null 2>/dev/null
done

if [ -z "$FAILED_TESTS" ]; then
    exit 0
else
    echo "Failed tests: $FAILED_TESTS"
    exit 1
fi
