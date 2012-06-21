AC_INIT([patchelf], m4_esyscmd([echo -n $(cat ./version)$VERSION_SUFFIX]))
AC_CONFIG_SRCDIR([src/patchelf.cc])
AC_CONFIG_AUX_DIR([build-aux])
AM_INIT_AUTOMAKE([dist-bzip2 foreign])

AC_PROG_CC
AC_PROG_CXX

AC_CONFIG_FILES([Makefile src/Makefile tests/Makefile patchelf.spec])
AC_OUTPUT
