#!/bin/sh -e
# Property: applying patchelf to a valid, runnable binary keeps it runnable.
#
# Each case builds a dynamic executable with randomized layout/link options.
# It then applies a random sequence of patchelf operations.
# The binary is run after each one.
# A case that fails to build or run before patching is skipped, not failed.
#
# Point PATCHELF at a sanitizer build for deeper checks, e.g.
#   g++ -std=c++17 -g -fsanitize=address,undefined -Isrc -o /tmp/pe \
#       src/patchelf.cc
#   PATCHELF=/tmp/pe ITERS=500 tests/property-rewrite.sh

PATCHELF=${PATCHELF:-../src/patchelf}
CC=${CC:-cc}
CXX=${CXX:-c++}
ITERS=${ITERS:-25}
SEED=${SEED:-$$}

WORK=$(mktemp -d "${TMPDIR:-/tmp}/patchelf-property.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

# Seeded xorshift32. rnd must not run in a subshell or the state is lost, so
# it writes the global rng and RND; callers read RND/PICK, never $(rnd).
rng=$(( SEED & 0xffffffff )); [ "$rng" -ne 0 ] || rng=2463534242
rnd() {
    rng=$(( (rng ^ (rng << 13)) & 0xffffffff ))
    rng=$(( rng ^ (rng >> 17) ))
    rng=$(( (rng ^ (rng << 5)) & 0xffffffff ))
    RND=$rng
}
pick() { rnd; _i=$(( RND % $# + 1 )); eval "PICK=\${$_i}"; }
rand_layout() {
    pick "-Wl,-z,max-page-size=0x1000" "-Wl,-z,max-page-size=0x4000" \
         "-Wl,-z,max-page-size=0x200000" "-Wl,-z,separate-code" \
         "-Wl,-z,noseparate-code" "-Wl,-z,relro,-z,now" "-Wl,-z,norelro" \
         "-Wl,--hash-style=sysv" "-Wl,--hash-style=gnu" "-Wl,--hash-style=both" \
         "-Wl,--build-id=none" "-Wl,--build-id=sha1" "-Wl,-z,noexecstack" \
         "-Wl,--enable-new-dtags" "-Wl,--disable-new-dtags" \
         "-Wl,-z,pack-relative-relocs" "-fcf-protection=full" ""
}

# Long string for rpath/needed edits.
# It grows .dynstr and relocates sections to the end of the file.
# That is the invasive rewrite path, not an edit that fits in slack.
LONG=$(printf '%0200d' 0 | tr 0 r)

# Stronger oracle than "exit 0", to catch corruption that still runs.
# Deps resolve via LD_LIBRARY_PATH, so rpath edits don't change findability.
# Binding is eager and loader warnings are on.
# The exact output is required.
run_app() { # $1=binary $2=libdir -> 0 iff it ran cleanly and printed 42
    ( cd / || exit 1
      err=$(LD_LIBRARY_PATH="$2" LD_BIND_NOW=1 LD_WARN=1 \
            timeout 10 "$1" 2>"$WORK/run.err"); rc=$?
      [ "$rc" -eq 0 ] && [ "$err" = 42 ] && [ ! -s "$WORK/run.err" ] )
}

# Versioned symbol: main gets a .gnu.version_r entry naming libdep's soname.
# replace-needed/soname must rewrite that entry.
# TLS plus a constructor add PT_TLS and init-array structure to keep consistent.
cat > "$WORK/dep.c" <<'EOF'
static __thread int tls_counter;
__attribute__((constructor)) static void init(void) { tls_counter++; }
int dep_value(void) { return 42 + tls_counter - tls_counter; }
EOF
cat > "$WORK/dep.map" <<'EOF'
LIBDEP_1.0 { global: dep_value; local: *; };
EOF
# The address table makes relative relocations.
# With -z pack-relative-relocs they become a DT_RELR/.relr.dyn section.
# patchelf has no RELR-specific code, so it must survive a generic relocate.
cat > "$WORK/main.c" <<'EOF'
#include <stdio.h>
int dep_value(void);
int main(void);
static void *const reltab[] = { (void *)dep_value, (void *)main, (void *)reltab };
int main(void) { if (!reltab[2]) return 1; printf("%d", dep_value()); return 0; }
EOF
# C++ variant: adds .eh_frame_hdr/PT_GNU_EH_FRAME, global ctors and versioned
# libstdc++ deps. Throwing then catching forces an unwind, so a corrupted
# .eh_frame_hdr aborts instead of printing 42 -- something "runs OK" misses.
cat > "$WORK/main.cpp" <<'EOF'
#include <cstdio>
extern "C" int dep_value();
int main() { int r = 0; try { throw dep_value(); } catch (int v) { r = v; } printf("%d", r); return 0; }
EOF
have_cxx=""; if command -v "$CXX" >/dev/null; then have_cxx=1; fi

# Different linkers lay binaries out differently and have triggered distinct
# patchelf bugs (e.g. lld's .init/PHT placement). Use whichever exist;
# "default" means no -fuse-ld flag.
linkers=default
for ld in bfd gold lld mold; do
    echo 'int main(void){return 0;}' \
        | "$CC" -fuse-ld="$ld" -xc - -o "$WORK/ldtest" 2>/dev/null \
        && linkers="$linkers $ld"
done

# The dependency is fixed, so build it once; only the app varies per case.
"$CC" -O0 -shared -fPIC -Wl,-soname,libdep.so.0 \
    -Wl,--version-script="$WORK/dep.map" \
    -o "$WORK/libdep.so.0" "$WORK/dep.c" || { echo "cannot build dep"; exit 77; }

echo "seed=$SEED iters=$ITERS linkers='$linkers' work=$WORK"
# Count tested cases toward ITERS and retry skips (a linker may reject a layout
# option, e.g. gold and -z separate-code). Cap attempts so it can't loop.
fails=0 skipped=0 tested=0 attempt=0
while [ "$tested" -lt "$ITERS" ] && [ "$attempt" -lt "$((ITERS * 20))" ]; do
    attempt=$((attempt + 1)); it=$attempt
    d="$WORK/c$it"; mkdir -p "$d"
    pick "-pie -fPIE" "-no-pie -fno-pie"; pie=$PICK
    rand_layout; lo1=$PICK; rand_layout; lo2=$PICK

    cp "$WORK/libdep.so.0" "$d/libdep.so.0"
    ln -sf libdep.so.0 "$d/libdep.so"
    cp "$WORK/libdep.so.0" "$d/libextra.so.0"   # resolvable target for add-needed
    comp=$CC src=$WORK/main.c
    rnd; [ -n "$have_cxx" ] && [ "$(( RND % 2 ))" -eq 0 ] && comp=$CXX src=$WORK/main.cpp
    # shellcheck disable=SC2086  # word splitting of linker list is intended
    pick $linkers; ld=$PICK; ldf=""; [ "$ld" = default ] || ldf="-fuse-ld=$ld"
    # shellcheck disable=SC2086  # word splitting of flag lists is intended
    if ! "$comp" -O0 $pie $lo1 $lo2 $ldf -o "$d/app" "$src" \
            -L"$d" -ldep -Wl,-rpath,"$d" 2>/dev/null; then
        skipped=$((skipped + 1)); continue
    fi

    # Run with the binary's own runpath added, so rpath edits exercise the
    # rewrite without making toolchain libs (libgcc_s, libstdc++) unfindable.
    origrun=$($PATCHELF --print-rpath "$d/app" 2>/dev/null || true)
    libpath="$d${origrun:+:$origrun}"

    if ! run_app "$d/app" "$libpath"; then
        skipped=$((skipped + 1)); continue
    fi

    # Self-extracting archives and signatures append data past the ELF.
    # patchelf relocates sections to EOF, so this is a distinct path.
    # The payload need not stay at EOF, but its bytes must survive.
    # Count the marker now and re-check after the ops.
    trailer="" tcount=0
    rnd; if [ "$(( RND % 2 ))" -eq 0 ]; then
        yes PROPTRAILER | head -c 65536 >> "$d/app"
        trailer=1; tcount=$(grep -ac PROPTRAILER "$d/app")
    fi

    interp=$($PATCHELF --print-interpreter "$d/app" 2>/dev/null || true)
    dep=libdep.so.0          # current DT_NEEDED name we control
    log="$d/ops.log"; : > "$log"
    rnd; nops=$(( RND % 6 + 1 )); broke=""; o=0
    while [ "$o" -lt "$nops" ]; do
        o=$((o + 1))
        rnd; case $(( RND % 8 )) in
        0) pick /lib/x "/lib/$LONG"; set -- --set-rpath "$PICK:$d" ;;
        1) pick /lib/y "/lib/$LONG"; set -- --add-rpath "$PICK" ;;
        2) set -- --remove-rpath ;;
        3) set -- --shrink-rpath ;;
        4) [ -n "$interp" ] || continue; set -- --set-interpreter "$interp" ;;
        5)  pick libextra.so.0 "lib$LONG.so.0"; nm=$PICK
            [ "$nm" = libextra.so.0 ] || ln -sf libextra.so.0 "$d/$nm"
            set -- --add-needed "$nm" ;;
        6) set -- --remove-needed libextra.so.0 ;;
        7)  # "dep.so.0" is a suffix of the original; it hits the .dynstr
            # suffix-reuse path. The others force a fresh (long) string.
            pick "dep.so.0" "renamed.so.0" "lib$LONG.so.0"; new=$PICK
            [ "$new" != "$dep" ] || continue
            ln -sf libdep.so.0 "$d/$new"
            set -- --replace-needed "$dep" "$new"; dep="$new" ;;
        esac
        echo "$*" >> "$log"
        if ! $PATCHELF "$@" "$d/app" 2>>"$log"; then
            broke="patchelf failed: $*"; break
        fi
        if ! run_app "$d/app" "$libpath"; then
            broke="binary broken after: $*"; break
        fi
        if [ -n "$trailer" ] && [ "$(grep -ac PROPTRAILER "$d/app")" -lt "$tcount" ]; then
            broke="trailing payload lost after: $*"; break
        fi
    done

    if [ -n "$broke" ]; then
        fails=$((fails + 1))
        echo "FAIL case $it: $broke"
        echo "  comp=$comp ld=$ld pie=$pie layout='$lo1 $lo2'"
        echo "  op sequence:"; sed 's/^/    /' "$log"
        keep="property-fail-$SEED-$it"; rm -rf "$keep"; cp -r "$d" "$keep"
        echo "  artifacts: $keep"
    fi
    tested=$((tested + 1))
done

echo "done: $((tested - fails)) passed, $fails failed, $skipped skipped, $attempt attempts (seed=$SEED)"
[ "$fails" -eq 0 ]
