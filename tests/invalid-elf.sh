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
# byte offset of field $2 in section header $1
shdr_field() { echo $((shoff + $1 * 64 + $2)); }
shstrtab_off=$(read_le "$base" "$(shdr_field "$shstrndx" 24)" 8)
shstrtab_size=$(read_le "$base" "$(shdr_field "$shstrndx" 32)" 8)
# section indices in $base (committed binary, stable)
dynstr=7 verneed=9 dynamic=22
dynamic_off=$(read_le "$base" "$(shdr_field $dynamic 24)" 8)
dynstr_off=$(read_le "$base" "$(shdr_field $dynstr 24)" 8)
dynstr_size=$(read_le "$base" "$(shdr_field $dynstr 32)" 8)
verneed_off=$(read_le "$base" "$(shdr_field $verneed 24)" 8)
dynamic_size=$(read_le "$base" "$(shdr_field $dynamic 32)" 8)
gnuhash=5
gnuhash_off=$(read_le "$base" "$(shdr_field $gnuhash 24)" 8)
printf 'puts puts2\n' > "$SCRATCH/sym-map"

fixture() { cp "$base" "$SCRATCH/$1"; poke "$SCRATCH/$1" "$2" "$3"; }

fixture invalid-shrstrtab-idx     62                                  '\377\377'
fixture invalid-shrstrtab-size    "$(shdr_field "$shstrndx" 32)"      '\377\377\377\377\377\377\377\177'
fixture invalid-shrstrtab-zero    "$(shdr_field "$shstrndx" 32)"      '\0\0\0\0\0\0\0\0'
fixture invalid-shrstrtab-nonterm $((shstrtab_off + shstrtab_size - 1)) 'A'
fixture invalid-shdr-name         "$(shdr_field 1 0)"                 '\377\377\377\177'
fixture invalid-shentsize         58                                  '\060\000'
fixture invalid-dynamic-offset    "$(shdr_field $dynamic 24)"         '\377\377\377\377\377\377\377\177'
fixture invalid-dynamic-unaligned "$(shdr_field $dynamic 24)"         '\001\0\0\0\0\0\0\0'
fixture invalid-dynstr-idx        $((dynamic_off + 8))                '\377\377\377\377\377\377\377\177'
fixture invalid-dynstr-noterm     $((dynstr_off + dynstr_size - 1))   'A'
fixture invalid-verneed-file      $((verneed_off + 4))                '\377\377\377\177'
fixture invalid-unnamed-section   "$(shdr_field 1 0)"                 '\0\0\0\0'
fixture invalid-gnuhash-buckets   "$gnuhash_off"                      '\0\0\0\0'
fixture invalid-gnuhash-maskwords $((gnuhash_off + 8))                '\377\377\377\177'
# sh_addralign==0 is *valid* per the ELF spec; must be handled, not rejected.
fixture valid-note-addralign-zero "$(shdr_field 2 48)"                '\0\0\0\0\0\0\0\0'

# .dynamic with no DT_NULL terminator
cp "$base" "$SCRATCH/invalid-dynamic-noterm"
dd if=/dev/zero bs=1 count="$dynamic_size" 2>/dev/null | tr '\0' '\377' \
    | dd of="$SCRATCH/invalid-dynamic-noterm" bs=1 seek="$dynamic_off" conv=notrunc status=none

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
    $SCRATCH:invalid-dynamic-offset
    $SCRATCH:invalid-dynamic-unaligned
    $SCRATCH:invalid-dynstr-idx
    $SCRATCH:invalid-dynstr-noterm
    $SCRATCH:invalid-verneed-file
    $SCRATCH:invalid-dynamic-noterm
    $SCRATCH:invalid-unnamed-section
    $SCRATCH:invalid-gnuhash-buckets
    $SCRATCH:invalid-gnuhash-maskwords
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
invalid_dynamic_offset_MSG='data offset extends past file end'
# shellcheck disable=SC2034
invalid_dynamic_offset_ARGS='--print-needed'
# shellcheck disable=SC2034
invalid_dynamic_unaligned_MSG='section content is not naturally aligned'
# shellcheck disable=SC2034
invalid_dynamic_unaligned_ARGS='--print-needed'
# shellcheck disable=SC2034
invalid_dynstr_idx_MSG='string table index out of bounds'
# shellcheck disable=SC2034
invalid_dynstr_idx_ARGS='--print-needed'
# shellcheck disable=SC2034
invalid_dynstr_noterm_MSG='string table is not NUL-terminated'
# shellcheck disable=SC2034
invalid_dynstr_noterm_ARGS='--print-needed'
# shellcheck disable=SC2034
invalid_verneed_file_MSG='string table index out of bounds'
# shellcheck disable=SC2034
invalid_verneed_file_ARGS='--replace-needed libc.so.6 libx.so'
# shellcheck disable=SC2034
invalid_dynamic_noterm_MSG='setSubstr: write extends past end of section'
# shellcheck disable=SC2034
invalid_dynamic_noterm_ARGS='--add-debug-tag'
# shellcheck disable=SC2034
invalid_unnamed_section_MSG='warning: .* refers to an unnamed section'
# shellcheck disable=SC2034
invalid_unnamed_section_ARGS='--set-rpath /x'
# shellcheck disable=SC2034
invalid_gnuhash_buckets_MSG='hash table header out of range'
# shellcheck disable=SC2034
invalid_gnuhash_buckets_ARGS="--rename-dynamic-symbols $SCRATCH/sym-map"
# shellcheck disable=SC2034
invalid_gnuhash_maskwords_MSG='hash table header out of range'
# shellcheck disable=SC2034
invalid_gnuhash_maskwords_ARGS="--rename-dynamic-symbols $SCRATCH/sym-map"
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

    var=$(echo "$name" | tr '-' '_')
    msg=; args=
    eval "msg=\${${var}_MSG}"
    eval "args=\${${var}_ARGS:-}"

    # shellcheck disable=SC2086 # args is a deliberate word list
    ../src/patchelf $args --output /dev/null "$file" && res=$? || res=$?
    if killed_by_signal "$res"; then
	FAILED_TESTS="$FAILED_TESTS $name"
    fi

    # shellcheck disable=SC2086
    ../src/patchelf $args --output /dev/null "$file" 2>&1 |
        grep "$msg" >/dev/null 2>/dev/null
done

# This input is valid; it must be edited successfully, not rejected.
../src/patchelf --set-rpath /x --output /dev/null "$SCRATCH/valid-note-addralign-zero"

if [ -z "$FAILED_TESTS" ]; then
    exit 0
else
    echo "Failed tests: $FAILED_TESTS"
    exit 1
fi
