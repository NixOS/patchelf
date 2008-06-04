AC_INIT(patchelf, "0.4")
AC_CONFIG_SRCDIR(Makefile.am)
AM_INIT_AUTOMAKE([dist-bzip2 foreign])

# Change to `1' to produce a `stable' release (i.e., the `preREVISION'
# suffix is not added).
STABLE=1

# Put the revision number in the version.
if test "$STABLE" != "1"; then
    if REVISION=`test -d $srcdir/.svn && svnversion $srcdir 2> /dev/null`; then
        VERSION="${VERSION}pre${REVISION}"
    elif REVISION=`cat $srcdir/svn-revision 2> /dev/null`; then
        VERSION="${VERSION}pre${REVISION}"
    fi
fi

AC_PROG_CC
AC_PROG_CXX

AC_CONFIG_FILES([Makefile src/Makefile tests/Makefile])
AC_OUTPUT
