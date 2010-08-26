#! /bin/sh -e

rm -rf scratch
mkdir -p scratch

cp no-rpath scratch/

oldRPath=$(../src/patchelf --print-rpath scratch/no-rpath)
if test -n "$oldRPath"; then exit 1; fi
../src/patchelf \
  --set-interpreter "$(../src/patchelf --print-interpreter ../src/patchelf)" \
  --set-rpath /foo:/bar:/xxxxxxxxxxxxxxx scratch/no-rpath

newRPath=$(../src/patchelf --print-rpath scratch/no-rpath)
if ! echo "$newRPath" | grep -q '/foo:/bar'; then
    echo "incomplete RPATH"
    exit 1
fi

if [ "$(uname -m)" = i686 -a "$(uname -s)" = Linux ]; then
    cd scratch && ./no-rpath
fi
