#! /bin/sh -e

SCRATCH=scratch/$(basename "$0" .sh)

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

cp simple-pie "${SCRATCH}/simple-pie"

# Add a large rpath
printf '=%.0s' $(seq 1 4096) > "${SCRATCH}/foo.bin"

# Grow the file
../src/patchelf --add-rpath @"${SCRATCH}/foo.bin" "${SCRATCH}/simple-pie"

# Make sure we can still run it
"${SCRATCH}/simple-pie"
