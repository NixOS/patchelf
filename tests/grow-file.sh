#! /bin/sh -e

SCRATCH=scratch/$(basename $0 .sh)

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}

g++ -x c -fPIC -pie -o ${SCRATCH}/simple simple.c

# Add a 40MB rpath
head -c 40000000 /dev/urandom > ${SCRATCH}/foo.bin

# Grow the file
../src/patchelf --add-rpath @${SCRATCH}/foo.bin ${SCRATCH}/simple
# Make sure we can still run it
${SCRATCH}/simple
