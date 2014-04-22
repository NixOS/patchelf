#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}

cp no-rpath ${SCRATCH}/

oldRPath=$(../src/patchelf -d --print-rpath ${SCRATCH}/no-rpath)
if test -n "$oldRPath"; then exit 1; fi
../src/patchelf -d --set-rpath /foo:/bar:/xxxxxxxxxxxxxxx ${SCRATCH}/no-rpath

newRPath=$(../src/patchelf -d --print-rpath ${SCRATCH}/no-rpath)
if ! echo "$newRPath" | grep -q '/foo:/bar'; then
    echo "incomplete RPATH"
    exit 1
fi

cd ${SCRATCH} && ./no-rpath
