AC_INIT(patchelf, "0.1")
AC_CONFIG_SRCDIR(patchelf.c)
AM_INIT_AUTOMAKE

# Change to `1' to produce a `stable' release (i.e., the `preREVISION'
# suffix is not added).
STABLE=0

# Put the revision number in the version.
if test "$STABLE" != "1"; then
    if REVISION=`test -d $srcdir/.svn && svnversion $srcdir 2> /dev/null`; then
        VERSION="${VERSION}pre${REVISION}"
    elif REVISION=`cat $srcdir/svn-revision 2> /dev/null`; then
        VERSION="${VERSION}pre${REVISION}"
    fi
fi

AC_PROG_CC
AC_CONFIG_FILES([Makefile])
AC_OUTPUT
