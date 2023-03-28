#! /bin/sh -e

[ "$STRESS" = "1" ] || exit 0

SCRATCH=scratch/$(basename "$0" .sh)
PATCHELF=$(readlink -f "../src/patchelf")

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"
cd "${SCRATCH}"

for lib in /usr/lib*/*.so* /usr/bin/* /usr/libexec/*
do
    if file "$lib" | grep -q -e "ELF.*dynamically"
    then
        echo "==============================================================="
        echo "#### Copying"
        echo "$lib"
        echo "$(file $lib)"
        blib="$(basename "$lib")"
        cp "$lib" "$blib"
        echo "#### chmod"
        chmod +w "$blib"

        echo "#### readelf before"
        readelf -L "$blib" > /dev/null 2> re_before || echo
        echo "#### ldd before"
        ldd "$blib" | sed 's/0x.*//g' > ldd_before

        echo "#### get rpath"
        new_rpath="$(${PATCHELF} --print-rpath "$blib"):XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
        echo "#### new rpath: $new_rpath"
        ${PATCHELF} --force-rpath --set-rpath "$new_rpath" "$blib"

        echo "#### readelf after"
        readelf -L "$blib" > /dev/null 2> re_after || echo
        echo "#### ldd after"
        ldd "$blib" | sed 's/0x.*//g' > ldd_after

        diff re_before re_after
        diff ldd_before ldd_after

        rm "$blib"
    fi
done
