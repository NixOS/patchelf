#! /bin/sh -e
# useful when working with git
rm -rf autom4te.cache/ aclocal.m4 configure build-aux/ src/Makefile.in tests/Makefile.in Makefile.in
echo "Removed files generated by autoreconf"
