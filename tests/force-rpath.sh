#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}

SCRATCHFILE=${SCRATCH}/libfoo.so
cp libfoo.so $SCRATCHFILE

doit() {
    echo patchelf $*
    ../src/patchelf $* $SCRATCHFILE
}

expect() {
    out=$(echo $(objdump -x $SCRATCHFILE | grep PATH))

    if [ "$out" != "$*" ]; then
        echo "Expected '$*' but got '$out'"
        exit 1
    fi
}

doit --remove-rpath
expect
doit --set-rpath foo
expect RUNPATH foo
doit --force-rpath --set-rpath foo
expect RPATH foo
doit --force-rpath --set-rpath bar
expect RPATH bar
doit --remove-rpath
expect
doit --force-rpath --set-rpath foo
expect RPATH foo
doit --set-rpath foo
expect RUNPATH foo
doit --set-rpath bar
expect RUNPATH bar
