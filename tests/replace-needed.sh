#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}

oldNeeded=$(../src/patchelf --print-needed big-dynstr)
oldLibc=$(../src/patchelf --print-needed big-dynstr | grep -v 'foo\.so')
../src/patchelf --output ${SCRATCH}/big-needed --replace-needed ${oldLibc} long_long_very_long_libc.so.6 --replace-needed libfoo.so lf.so big-dynstr

if [ -z "$(../src/patchelf --print-needed ${SCRATCH}/big-needed | grep -Fx "long_long_very_long_libc.so.6")" ]; then
	echo "library long_long_very_long_libc.so.6 not found as NEEDED"
	../src/patchelf --print-needed ${SCRATCH}/big-needed
	exit 1
fi

if [ -z "$(../src/patchelf --print-needed ${SCRATCH}/big-needed | grep -Fx "lf.so")" ]; then
	echo "library lf.so not found as NEEDED"
	../src/patchelf --print-needed ${SCRATCH}/big-needed
	exit 1
fi
