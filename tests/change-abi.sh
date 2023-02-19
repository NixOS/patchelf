#! /bin/sh -e

SCRATCH=scratch/$(basename "$0" .sh)

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

cp simple-pie "${SCRATCH}/simple-pie"

# Save the old OS ABI
OLDABI=$(../src/patchelf --print-os-abi "${SCRATCH}/simple-pie")
# Ensure it's not empty
test -n "$OLDABI"

# Change OS ABI and verify it has been changed
for ABI in "System V" "HP-UX" "NetBSD" "Linux" "GNU Hurd" "Solaris" "AIX" "IRIX" "FreeBSD" "Tru64" "OpenBSD" "OpenVMS"; do
  echo "Set OS ABI to '$ABI'..."
  ../src/patchelf --set-os-abi "$ABI" "${SCRATCH}/simple-pie"

  echo "Check is OS ABI is '$ABI'..."
  NEWABI=$(../src/patchelf --print-os-abi "${SCRATCH}/simple-pie")
  test "$NEWABI" = "$ABI"
done

# Reset OS ABI to the saved one
../src/patchelf --set-os-abi "$OLDABI" "${SCRATCH}/simple-pie"

# Verify we still can run the executable
"${SCRATCH}/simple-pie"
