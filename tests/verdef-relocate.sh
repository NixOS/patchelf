#! /bin/sh -e
# Regression test: DT_VERDEF must follow .gnu.version_d when it is relocated.
#
# rewriteHeaders() updates DT_VERSYM and DT_VERNEED after moving sections but
# used to leave DT_VERDEF at the pre-relocation address. glibc then walks a
# stale verdef chain in _dl_check_map_versions and the process can die before
# main(). See https://github.com/NixOS/patchelf/issues/664.
#
# Reproducing needs an object that DEFINES symbol versions (so it has
# .gnu.version_d at all) and a layout in which patchelf has to move that
# section. The existing tests only ever patch objects that merely *require*
# versions, i.e. .gnu.version_r, which was already handled.
#
# Whether .gnu.version_d ends up in the way is a property of the linker's
# section ordering, not of its name, so probe for the layout rather than
# hardcoding a linker: lld puts .dynstr after the .gnu.version* sections,
# GNU ld and gold put it before. If no available linker produces a build
# where the section actually moves, there is nothing to assert: skip.

PATCHELF=${PATCHELF:-../src/patchelf}
READELF=${READELF:-readelf}
CC=${CC:-cc}

SCRATCH=scratch/$(basename "$0" .sh)
rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

cat > "${SCRATCH}/vexe.c" <<'EOF'
#include <stdio.h>
int exported_api(void) { return 42; }
int main(void) { printf("%d", exported_api()); return 0; }
EOF

cat > "${SCRATCH}/vexe.map" <<'EOF'
MYAPP_1.0 { global: exported_api; local: *; };
EOF

# Long enough that the rpath cannot be edited in place: .dynstr grows, the
# dynamic cluster is relocated, and .gnu.version_d is evicted with it.
LONG=$(printf '%0200d' 0 | tr 0 r)

# readelf pads the section address but not the dynamic tag value, so these
# are compared with $(( )) arithmetic, never as strings.  In `-SW` output the
# "[ 5]" index splits into two fields while "[12]" does not, so the name is
# located by scanning rather than by a fixed column.
verdef_tag() {  # -> DT_VERDEF value, empty if absent
    ${READELF} -dW "$1" | awk '$2 == "(VERDEF)" { print $3 }'
}
verdef_addr() { # -> .gnu.version_d sh_addr, empty if absent
    ${READELF} -SW "$1" | awk '
        { for (i = 1; i < NF; i++) if ($i == ".gnu.version_d") { print "0x"$(i+2); exit } }'
}

found=
for ld in default lld mold bfd gold; do
    ldflag=
    if [ "$ld" != default ]; then
        ldflag=-fuse-ld=$ld
        echo 'int main(void){return 0;}' \
            | ${CC} "$ldflag" -xc - -o "${SCRATCH}/ldprobe" 2>/dev/null || continue
    fi

    exe="${SCRATCH}/vexe-$ld"
    # -rdynamic + a version script is what gives an EXECUTABLE its own
    # .gnu.version_d; non-PIE selects the rewriteSectionsExecutable() path.
    # shellcheck disable=SC2086 # $ldflag is one optional word, not a path
    ${CC} -O0 -no-pie -fno-pie $ldflag -rdynamic \
        -Wl,--version-script="${SCRATCH}/vexe.map" \
        -o "$exe" "${SCRATCH}/vexe.c" 2>/dev/null || continue

    before=$(verdef_addr "$exe")
    [ -n "$before" ] || continue
    [ "$(./"$exe")" = 42 ] || continue

    ${PATCHELF} --set-rpath "/lib/$LONG" "$exe"

    after=$(verdef_addr "$exe")
    if [ "$((before))" = "$((after))" ]; then
        echo "linker '$ld': .gnu.version_d not relocated, nothing to check"
        continue
    fi

    found=$ld
    tag=$(verdef_tag "$exe")
    echo "linker '$ld': .gnu.version_d $before -> $after, DT_VERDEF $tag"
    if [ -z "$tag" ] || [ "$((tag))" != "$((after))" ]; then
        echo "FAIL: DT_VERDEF is '$tag' but .gnu.version_d moved to $after"
        exit 1
    fi

    # Stale verdef chains do not always crash, so the tag comparison above is
    # the real oracle; still, the binary must keep working.
    out=$(./"$exe") || { echo "FAIL: patched binary did not run"; exit 1; }
    [ "$out" = 42 ] || { echo "FAIL: patched binary printed '$out', want 42"; exit 1; }
done

if [ -z "$found" ]; then
    echo "no available linker relocates .gnu.version_d here; skipping"
    exit 77
fi
