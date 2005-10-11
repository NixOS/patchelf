#! /bin/sh -e

./simple

oldInterpreter=$(../src/patchelf --print-interpreter ./simple)
echo "current interpreter is $oldInterpreter"

rm -rf scratch
mkdir -p scratch

cp simple scratch/
../src/patchelf --set-interpreter /oops scratch/simple

echo "running with missing interpreter..."
if scratch/simple; then
    echo "simple works, but it shouldn't"
    exit 1
fi
