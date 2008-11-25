#! /bin/sh -e
aclocal
#autoheader
automake --add-missing --copy --foreign
autoconf --force
