#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)
OBJDUMP=${OBJDUMP:-objdump}

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

SCRATCHFILE=${SCRATCH}/libfoo.so
cp libfoo.so "$SCRATCHFILE"

doit() {
    set +x
    ../src/patchelf "$@" "$SCRATCHFILE"
    set -x
}

expect() {
    out=$("$OBJDUMP" -x "$SCRATCHFILE" | grep PATH || true)

    for i in $out; do
        if [ "$i" != "$1" ]; then
            echo "Expected '$*' but got '$out'"
            exit 1
        fi
        shift
    done
}

doit --remove-rpath
expect ""
doit --set-rpath foo
expect RUNPATH foo
doit --update-rpath --force-rpath 
expect RPATH foo
doit --update-rpath
expect RUNPATH foo
