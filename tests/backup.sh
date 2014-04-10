#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}

cp main ${SCRATCH}/

../src/patchelfmod --set-rpath /set/RPath ${SCRATCH}/main
original=$(md5sum --binary ${SCRATCH}/main | cut -d ' ' -f1)

../src/patchelfmod --backup --set-rpath /set/new/RPath ${SCRATCH}/main
backup=$(md5sum --binary ${SCRATCH}/main~orig | cut -d ' ' -f1)

echo "md5 original: $original"
echo "md5 backup:   $backup"
if test $original != $backup; then
    echo "something went wrong!"
    exit 1
fi
