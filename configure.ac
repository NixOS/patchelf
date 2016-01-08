AC_INIT([patchelf], m4_esyscmd([printf $(cat ./version)]))
AC_CONFIG_SRCDIR([src/patchelf.cc])
AC_CONFIG_AUX_DIR([build-aux])
AM_INIT_AUTOMAKE([-Wall -Werror dist-bzip2 foreign color-tests parallel-tests])

AM_PROG_CC_C_O
AC_PROG_CXX

AC_CHECK_HEADERS([elf.h])
AC_CHECK_FUNCS([sysconf])

AC_CONFIG_FILES([Makefile src/Makefile tests/Makefile patchelf.spec])
AC_OUTPUT
