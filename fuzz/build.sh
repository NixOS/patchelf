#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

: "${CXX:=clang++}"
SAN=${SAN:-address,undefined}

mkdir -p corpus out

# Seed: prefix each test ELF with every op byte.
if [ -z "$(ls -A corpus 2>/dev/null)" ]; then
  i=0
  for f in ../tests/main ../tests/simple ../tests/libfoo.so ../tests/libbar.so ../tests/no-rpath-prebuild/no-rpath-*; do
    [ -f "$f" ] || continue
    for op in $(seq 0 9); do
      { printf '%b' "\\x$(printf %02x "$op")"; cat "$f"; } > "corpus/seed-$i"
      i=$((i+1))
    done
  done
  echo "seeded $i corpus files"
fi

"$CXX" -std=c++17 -g -O1 -fno-omit-frame-pointer \
  -fsanitize=fuzzer,"$SAN" \
  -fno-sanitize-recover=undefined \
  -DNDEBUG \
  -I../src \
  fuzz.cc -o out/patchelf_fuzz

echo "run: ./out/patchelf_fuzz corpus -max_len=65536 -rss_limit_mb=4096"
