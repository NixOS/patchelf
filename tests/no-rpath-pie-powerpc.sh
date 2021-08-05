#! /bin/sh -e
set -x
SCRATCH=scratch/no-rpath-pie-powerpc

no_rpath_bin="${srcdir}/no-rpath-prebuild/no-rpath-pie-powerpc"

if [ ! -f $no_rpath_bin ]; then
  echo "no 'no-rpath' binary for '$ARCH' in '${srcdir}/no-rpath-prebuild'"
  exit 1
fi

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}

cp $no_rpath_bin ${SCRATCH}/no-rpath

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

# Tests for powerpc PIE endianness regressions
readelfData=$(readelf -l ${SCRATCH}/no-rpath 2>&1)

if [ $(echo "$readelfData" | grep --count "PHDR") != 1 ]; then
  # Triggered if PHDR errors appear on stderr
  echo "Unexpected number of occurences of PHDR in readelf results"
  exit 1
fi

virtAddr=$(echo "$readelfData" | grep "PHDR" | awk '{print $3}')
if [ "$virtAddr" != "0x00000034" ]; then
  # Triggered if the virtual address is the incorrect endianness
  echo "Unexpected virt addr, expected [0x00000034] got [$virtAddr]"
  exit 1
fi

echo "$readelfData" | grep "LOAD" | while read -r line ; do
  align=$(echo "$line" | awk '{print $NF}')
  if [ "$align" != "0x10000" ]; then
    # Triggered if the target arch was not detected properly
    echo "Unexpected Align for LOAD segment, expected [0x10000] got [$align]"
    echo "Load segment: [$line]"
    exit 1
  fi
done

