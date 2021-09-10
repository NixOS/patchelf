#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}

cp main ${SCRATCH}/
RANDOM_PATH=$(pwd)/${SCRATCH}/$RANDOM
echo -n ${RANDOM_PATH} >> ${SCRATCH}/add-rpath

! ../src/patchelf --print-rpath ${SCRATCH}/main | grep $RANDOM_PATH
../src/patchelf --add-rpath @${SCRATCH}/add-rpath ${SCRATCH}/main
../src/patchelf --print-rpath ${SCRATCH}/main | grep $RANDOM_PATH
