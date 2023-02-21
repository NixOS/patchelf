#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)

./simple

oldInterpreter=$(../src/patchelf --print-interpreter ./simple)
echo "current interpreter is $oldInterpreter"

if test "$(uname)" = Linux; then
    echo "running with explicit interpreter..."
    "$oldInterpreter" ./simple
fi

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

newInterpreter="$(pwd)/${SCRATCH}/iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii"
cp simple "${SCRATCH}/"
../src/patchelf --set-interpreter "$newInterpreter" "${SCRATCH}/simple"

echo "running with missing interpreter..."
if "${SCRATCH}"/simple; then
    echo "simple works, but it shouldn't"
    exit 1
fi

echo "running with new interpreter..."
ln -s "$oldInterpreter" "$newInterpreter"
"${SCRATCH}"/simple

if test "$(uname)" = Linux; then
    echo "running with explicit interpreter..."
    "$oldInterpreter" "${SCRATCH}/simple"
fi
