#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

: > triage.txt
for f in crashes/crash-*; do
  out=$(./out/patchelf_fuzz "$f" 2>&1 || true)
  kind=$(printf '%s\n' "$out" | grep -m1 -oE 'ERROR: (AddressSanitizer|UndefinedBehaviorSanitizer|libFuzzer): [a-zA-Z_-]+|runtime error: [a-z -]+' || echo unknown)
  frame=$(printf '%s\n' "$out" | grep -m1 -oE 'patchelf\.cc:[0-9]+' || echo '?')
  func=$(printf '%s\n' "$out" | grep -m1 'patchelf\.cc:' | grep -oE 'ElfFile<[^>]*>::[A-Za-z_]+|in [A-Za-z_]+\(' | head -1 | sed 's/ElfFile<[^>]*>:://; s/^in //; s/($//' || true)
  printf '%s\t%s\t%s\t%s\n' "$kind" "$frame" "${func:-?}" "$f" >> triage.txt
done

echo "=== unique signatures ==="
cut -f1-3 triage.txt | sort | uniq -c | sort -rn
echo
echo "=== sample per signature ==="
sort -t$'\t' -k1,3 -u triage.txt
