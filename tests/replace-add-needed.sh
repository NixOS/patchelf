#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)
PATCHELF=$(readlink -f "../src/patchelf")

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

cp simple "${SCRATCH}"/
cp libfoo.so "${SCRATCH}"/
cp libbar.so "${SCRATCH}"/

cd "${SCRATCH}"

libcldd=$(ldd ./simple | awk '/ => / { print $3 }' | grep -E "(libc(-[0-9.]*)*.so|ld-musl)")

# We have to set the soname on these libraries
${PATCHELF} --set-soname libbar.so ./libbar.so

# Add a libbar.so so we can rewrite it later
${PATCHELF} --add-needed libbar.so ./simple

# Make the NEEDED in libfoo the same as simple
# This is a current "bug" in musl
# https://www.openwall.com/lists/musl/2021/12/21/1
${PATCHELF} --replace-needed libbar.so "$(readlink -f ./libbar.so)" ./libfoo.so

${PATCHELF} --replace-needed libc.so.6 "${libcldd}" \
            --replace-needed libbar.so "$(readlink -f ./libbar.so)" \
            --add-needed "$(readlink -f ./libfoo.so)" \
            ./simple

exitCode=0
./simple || exitCode=$?

if test "$exitCode" != 0; then
    ldd ./simple
    exit 1
fi
