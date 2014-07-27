#! /bin/sh -e
SCRATCH=scratch/$(basename $0 .sh)

rm -rf ${SCRATCH}
mkdir -p ${SCRATCH}

cp main ${SCRATCH}/

../src/patchelf -d --set-rpath /set/RPath ${SCRATCH}/main
if test $(which md5sum) != ""; then
    original=$(md5sum --binary ${SCRATCH}/main | cut -d ' ' -f1)
elif test $(which md5) != ""; then
    original=$(md5 -q ${SCRATCH}/main)
else
    echo "no md5 tool found"
    exit 0
fi

../src/patchelf -d --backup --set-rpath /set/new/RPath ${SCRATCH}/main
if test $(which md5sum) != ""; then
    backup=$(md5sum --binary ${SCRATCH}/main~orig | cut -d ' ' -f1)
elif test $(which md5) != ""; then
    backup=$(md5 -q ${SCRATCH}/main~orig)
fi

echo "md5 original: $original"
echo "md5 backup:   $backup"
if test $original != $backup; then
    echo "something went wrong!"
    exit 1
fi
