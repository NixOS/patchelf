#! /bin/sh -e
SCRATCH=scratch/$(basename "$0" .sh)
PATCHELF=$(readlink -f "../src/patchelf")
READELF=${READELF:-readelf}

rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"

cp many-syms-main-no-pie libmany-syms.so "${SCRATCH}/"
cd "${SCRATCH}"

###############################################################################
# Regression test: patching an ET_EXEC binary's interpreter, then its RPATH,
# used to be able to corrupt the file so that it crashed on startup.
#
# many-syms-main-no-pie is non-PIE and has a large .dynsym/.dynstr (one entry
# per imported symbol from libmany-syms.so) and no pre-existing RPATH/RUNPATH.
#
# 1. Growing its interpreter is enough to make rewriteSectionsExecutable()
#    split the file into a small "header" PT_LOAD plus the original big
#    PT_LOAD (via shiftFile()).
# 2. Adding an RPATH afterwards adds a new DT_RUNPATH entry, forcing .dynamic
#    and .dynstr to be replaced. This drags .interp/.note*/.gnu.hash/.dynsym
#    along as sections "in the way" that get relocated into the reserved area
#    at the front of the file -- and that area's required size (driven by the
#    large .dynsym/.dynstr) can exceed what the small header PT_LOAD created
#    in step 1 can hold without overlapping the next PT_LOAD segment.
###############################################################################

oldInterpreter=$(${PATCHELF} --print-interpreter ./many-syms-main-no-pie)

# Prepending extra leading slashes yields a longer interpreter string that
# still resolves to the exact same file (the OS collapses duplicate leading
# slashes), while being long enough to force patchelf to grow the file on
# this first invocation.
newInterpreter="$(printf '/%.0s' $(seq 1 200))${oldInterpreter}"

${PATCHELF} --set-interpreter "${newInterpreter}" ./many-syms-main-no-pie
${PATCHELF} --set-rpath "$(pwd)" ./many-syms-main-no-pie

readelfData=$(${READELF} -l ./many-syms-main-no-pie 2>&1)
if echo "$readelfData" | grep -qi "not covered"; then
    echo "ERROR: PT_PHDR is not covered by a PT_LOAD segment"
    echo "$readelfData"
    exit 1
fi

exitCode=0
LD_BIND_NOW=1 LD_LIBRARY_PATH="$(pwd)" ./many-syms-main-no-pie || exitCode=$?
if [ "$exitCode" -ge 128 ]; then
    echo "ERROR: process died with signal $((exitCode - 128)) (exit code $exitCode)"
    exit 1
fi
