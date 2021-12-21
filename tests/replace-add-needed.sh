#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)
PATCHELF=$(readlink -f "../src/patchelf")

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}

cp simple ${SCRATCH}/
cp libfoo.so ${SCRATCH}/
cp libbar.so ${SCRATCH}/


cd ${SCRATCH}

libcldd=$(ldd ./simple | grep -oP "(?<=libc.so.6 => )[^ ]+")

# We have to set the soname on these libraries
${PATCHELF} --set-soname libbar.so ./libbar.so

# Add a libbar.so so we can rewrite it later
${PATCHELF} --add-needed libbar.so ./simple

${PATCHELF} --replace-needed libc.so.6 ${libcldd} \
            --replace-needed libbar.so $(readlink -f ./libbar.so) \
            --add-needed $(readlink -f ./libfoo.so) \
            ./simple

exitCode=0
./simple || exitCode=$?

if test "$exitCode" != 0; then
    ldd ./simple
    exit 1
fi
