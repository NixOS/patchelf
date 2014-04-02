AC_INIT([PatchELFmod], m4_esyscmd([echo -n $(cat ./version)]))
AC_CONFIG_SRCDIR([src/patchelfmod.cpp])
AC_CONFIG_AUX_DIR([build-aux])
AM_INIT_AUTOMAKE([-Wall -Werror dist-bzip2 foreign color-tests parallel-tests])

AM_PROG_CC_C_O
AC_PROG_CXX

AC_CONFIG_FILES([Makefile man/patchelfmod.1 src/Makefile tests/Makefile patchelfmod.spec])
AC_OUTPUT
