#! /bin/sh
set -e
echo "Confirming main requires libfoo"
../src/patchelf --print-needed main | grep -q libfoo.so
