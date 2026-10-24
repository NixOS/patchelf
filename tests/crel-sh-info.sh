#! /bin/sh -e

SCRATCH=scratch/$(basename "$0" .sh)
PATCHELF=$(readlink -f "../src/patchelf")
READELF=${READELF:-readelf}
CLANG=${CLANG:-clang}

skip()
{
    echo "SKIP: $*"
    exit 77
}

command -v "$CLANG" >/dev/null 2>&1 || skip "clang is unavailable"
command -v "$READELF" >/dev/null 2>&1 || skip "readelf is unavailable"

rm -rf "$SCRATCH"
mkdir -p "$SCRATCH"

cat > "$SCRATCH/crel.s" <<'EOF'
.section .note.creltest,"a",%note
.balign 4
target:
    .word 0

.text
.globl _start
_start:
    adrp x0, target
    add x0, x0, :lo12:target
    ret
EOF

build_crel()
{
    "$CLANG" -target aarch64-linux-gnu "$@" -fuse-ld=lld -nostdlib \
        -Wl,--emit-relocs -Wl,-rpath,/x \
        "$SCRATCH/crel.s" -o "$SCRATCH/repro" >/dev/null 2>&1
}

if ! build_crel -Wa,--allow-experimental-crel,--crel; then
    if ! build_crel -Wa,--crel; then
        skip "toolchain does not support the CREL fixture"
    fi
fi

section_index()
{
    "$READELF" -SW "$1" | awk -v name="$2" '
        {
            for (i = 1; i <= NF; ++i) {
                if ($i == name) {
                    idx = $(i - 1)
                    gsub(/\[/, "", idx)
                    gsub(/\]/, "", idx)
                    print idx
                    exit
                }
            }
        }'
}

section_info()
{
    "$READELF" -SW "$1" | awk -v name="$2" '
        {
            for (i = 1; i <= NF; ++i) {
                if ($i == name) {
                    print $(NF - 1)
                    exit
                }
            }
        }'
}

text_before=$(section_index "$SCRATCH/repro" .text)
crel_before=$(section_info "$SCRATCH/repro" .crel.text)
if [ -z "$text_before" ] || [ -z "$crel_before" ]; then
    skip "toolchain did not emit .crel.text"
fi
if [ "$crel_before" != "$text_before" ]; then
    echo "FAIL: CREL fixture does not initially reference .text"
    exit 1
fi

"$PATCHELF" --set-rpath /a/longer/rpath/that/forces/dynstr/to/grow/and/sections/to/move "$SCRATCH/repro"

text_after=$(section_index "$SCRATCH/repro" .text)
crel_after=$(section_info "$SCRATCH/repro" .crel.text)
if [ -z "$text_after" ] || [ -z "$crel_after" ]; then
    echo "FAIL: CREL sections disappeared after rewriting"
    exit 1
fi
if [ "$text_after" = "$text_before" ]; then
    skip "fixture did not cause section reordering"
fi
if [ "$crel_after" != "$text_after" ]; then
    echo "FAIL: .crel.text sh_info no longer references .text"
    exit 1
fi

echo "PASS"
