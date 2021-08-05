#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)
PATCHELF="../src/patchelf"

for arch in ppc64 ppc64le; do
    rm -rf ${SCRATCH}
    mkdir -p ${SCRATCH}

    cp endianness/${arch}/main endianness/${arch}/libtest.so ${SCRATCH}/

    rpath="${PWD}/${SCRATCH}"

    # set rpath to scratch dir
    ${PATCHELF} --output ${SCRATCH}/main-rpath --set-rpath $rpath ${SCRATCH}/main

    # attempt to shrink rpath, should not result in empty rpath
    ${PATCHELF} --output ${SCRATCH}/main-shrunk --shrink-rpath --debug ${SCRATCH}/main-rpath 

    # check whether rpath is still present
    if ! ${PATCHELF} --print-rpath ${SCRATCH}/main-shrunk | grep -q "$rpath"; then
        echo "rpath was removed for ${arch}"
	exit 1
    fi
done
