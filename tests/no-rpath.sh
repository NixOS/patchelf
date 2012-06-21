#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}

cp ${srcdir}/no-rpath ${SCRATCH}/

oldRPath=$(../src/patchelf --print-rpath ${SCRATCH}/no-rpath)
if test -n "$oldRPath"; then exit 1; fi
../src/patchelf \
  --set-interpreter "$(../src/patchelf --print-interpreter ../src/patchelf)" \
  --set-rpath /foo:/bar:/xxxxxxxxxxxxxxx ${SCRATCH}/no-rpath

newRPath=$(../src/patchelf --print-rpath ${SCRATCH}/no-rpath)
if ! echo "$newRPath" | grep -q '/foo:/bar'; then
    echo "incomplete RPATH"
    exit 1
fi

if [ "$(uname -m)" = i686 -a "$(uname -s)" = Linux ]; then
    cd ${SCRATCH} && ./no-rpath
fi
