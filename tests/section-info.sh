#! /bin/sh -e
# sh_info can be a section index for types other than SHT_REL/SHT_RELA.
SCRATCH=scratch/$(basename "$0" .sh)
PATCHELF=${PATCHELF:-../src/patchelf}

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"
long_rpath=$(printf '%0200d' 0)

for fixture in section-info section-info-no-pie; do
    bin="${SCRATCH}/${fixture}"
    cp "${fixture}" "${bin}"
    before=$(./section-info prepare "${bin}")
    ./section-info check "${bin}"
    "${PATCHELF}" --set-rpath "/${long_rpath}" "${bin}"
    after=$(./section-info check "${bin}")
    if [ "${before}" = "${after}" ]; then
        echo "FAIL: fixture did not exercise section reordering"
        exit 1
    fi
    "${PATCHELF}" --add-rpath /another/path "${bin}"
    ./section-info check "${bin}"
done
