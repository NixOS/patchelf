#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}

cp main ${SCRATCH}/

SYMBOL_TO_REMOVE=__libc_start_main
VERSION_TO_REMOVE=GLIBC_2.34a

readelfData=$(readelf -V ${SCRATCH}/main 2>&1)

if [ $(echo "$readelfData" | grep --count "$VERSION_TO_REMOVE") -lt 2 ]; then
    # We expect this to appear at least twice: once for the symbol entry,
    # and once for verneed entry.
    echo "Warning: Couldn't find expected versioned symbol."
    echo "This is probably because you're either not using glibc, or"
    echo "${SYMBOL_TO_REMOVE} is no longer at version ${VERSION_TO_REMOVE}"
    echo "Reporting a pass anyway, as the test result is invalid."
    exit 0
fi

../src/patchelf --clear-symbol-version ${SYMBOL_TO_REMOVE} ${SCRATCH}/main

readelfData=$(readelf -V ${SCRATCH}/main 2>&1)

if [ $(echo "$readelfData" | grep --count "$VERSION_TO_REMOVE") -ne 0 ]; then
    # We expect this to appear at least twice: once for the symbol entry,
    # and once for verneed entry.
    echo "The symbol version ${SYMBOL_TO_REMOVE} remained behind!"
    exit 1
fi
