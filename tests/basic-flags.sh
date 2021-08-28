#! /bin/sh -e

set -x
../src/patchelf --version | grep -q patchelf
../src/patchelf --help 2>&1 | grep -q patchelf
../src/patchelf 2>&1 | grep -q patchelf
