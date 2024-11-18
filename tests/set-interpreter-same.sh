#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)

./simple

curInterpreter=$(../src/patchelf --print-interpreter ./simple)
echo "current interpreter is $curInterpreter"

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

cp simple "${SCRATCH}"/

echo "set the same interpreter as the current one"
before_checksum=$(sha256sum "${SCRATCH}/simple")
../src/patchelf --set-interpreter "${curInterpreter}" "${SCRATCH}/simple"
after_checksum=$(sha256sum "${SCRATCH}/simple")

if [ "$before_checksum" != "$after_checksum" ]; then
    echo "--set-interpreter should be NOP, but the file has been changed."
    exit 1
fi

"${SCRATCH}/simple"

dummyInterpreter="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

echo "set the dummy interpreter"
before_checksum=$(sha256sum "${SCRATCH}/simple")
../src/patchelf --set-interpreter "${dummyInterpreter}" "${SCRATCH}/simple"
after_checksum=$(sha256sum "${SCRATCH}/simple")

if [ "$before_checksum" = "$after_checksum" ]; then
    echo "--set-interpreter should be run, but the file has not been changed."
    exit 1
fi

if "${SCRATCH}/simple"; then
    echo "simple works, but it shouldn't"
    exit 1
fi

echo "set the same interpreter as the current one"
before_checksum=$(sha256sum "${SCRATCH}/simple")
../src/patchelf --set-interpreter "${dummyInterpreter}" "${SCRATCH}/simple"
after_checksum=$(sha256sum "${SCRATCH}/simple")

if [ "$before_checksum" != "$after_checksum" ]; then
    echo "--set-interpreter should be NOP, but the file has been changed."
    exit 1
fi

if "${SCRATCH}/simple"; then
    echo "simple works, but it shouldn't"
    exit 1
fi
