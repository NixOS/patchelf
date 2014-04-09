#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}

cp main ${SCRATCH}/

cd ${SCRATCH}/

../../../src/patchelfmod --force-rpath --set-rpath /set/RPath main

md5sum --binary --tag main > main.md5

../../../src/patchelfmod --backup --force-rpath --set-rpath /set/new/RPath main

sed 's/main/main~orig/g' main.md5 > main~orig.md5
md5sum --check main~orig.md5
