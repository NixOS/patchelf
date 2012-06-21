#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)

./simple

oldInterpreter=$(../src/patchelf --print-interpreter ./simple)
echo "current interpreter is $oldInterpreter"

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}

cp simple ${SCRATCH}/
../src/patchelf --set-interpreter /oops ${SCRATCH}/simple

echo "running with missing interpreter..."
if ${SCRATCH}/simple; then
    echo "simple works, but it shouldn't"
    exit 1
fi
