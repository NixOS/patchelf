AC_PREREQ([2.62])
AC_INIT([patchelf], m4_esyscmd([printf $(cat ./version)]))
AC_CONFIG_SRCDIR([src/patchelf.cc])
AC_CONFIG_AUX_DIR([build-aux])
AM_INIT_AUTOMAKE([1.11.1 -Wall -Werror dist-bzip2 foreign color-tests parallel-tests])
AC_CONFIG_MACRO_DIR([m4])

AC_CHECK_TOOL([STRIP], [strip])
# Those are only used in tests, hence we gracefully degrate if they are not found.
AC_CHECK_TOOL([OBJDUMP], [objdump], [objdump])
AC_CHECK_TOOL([OBJCOPY], [objcopy], [objcopy])
AC_CHECK_TOOL([READELF], [readelf], [readelf])

AM_PROG_CC_C_O
AC_PROG_CXX
AC_LANG([C++])
AM_PROG_AS

DEFAULT_PAGESIZE=auto
AC_ARG_WITH([page-size],
   AS_HELP_STRING([--with-page-size=SIZE], [Specify default pagesize (default auto)]),
   DEFAULT_PAGESIZE=$withval
)

if test "$DEFAULT_PAGESIZE" != auto; then
    AC_DEFINE_UNQUOTED(DEFAULT_PAGESIZE, ${DEFAULT_PAGESIZE})
    AC_MSG_RESULT([Setting page size to ${DEFAULT_PAGESIZE}])
fi

AC_ARG_WITH([asan],
   AS_HELP_STRING([--with-asan], [Build with address sanitizer])
)
AM_CONDITIONAL([WITH_ASAN], [test x"$with_asan" = xyes])

AX_CXX_COMPILE_STDCXX([17], [noext], [])

AC_ARG_WITH([ubsan],
   AS_HELP_STRING([--with-ubsan], [Build with undefined behavior sanitizer])
)
AM_CONDITIONAL([WITH_UBSAN], [test x"$with_ubsan" = xyes])

AC_CONFIG_FILES([Makefile src/Makefile tests/Makefile patchelf.spec])
AC_OUTPUT
