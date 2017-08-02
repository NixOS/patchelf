AC_PREREQ([2.62])
AC_INIT([patchelf], m4_esyscmd([printf $(cat ./version)]))
AC_CONFIG_SRCDIR([src/patchelf.cc])
AC_CONFIG_AUX_DIR([build-aux])
AM_INIT_AUTOMAKE([1.11.1 -Wall -Werror dist-bzip2 foreign color-tests parallel-tests])

AM_PROG_CC_C_O
AC_PROG_CXX

PAGESIZE=auto
AC_ARG_WITH([page-size],
   AS_HELP_STRING([--with-page-size=SIZE], [Specify default pagesize (default auto)]),
   PAGESIZE=$withval
)

if test "$PAGESIZE" = auto; then
    if type -p getconf &>/dev/null; then
        PAGESIZE=$(getconf PAGESIZE || getconf PAGE_SIZE)
    fi
    if test "$PAGESIZE" = auto -o -z "$PAGESIZE"; then
        PAGESIZE=4096
    fi
fi

AC_DEFINE_UNQUOTED(PAGESIZE, ${PAGESIZE})
AC_MSG_RESULT([Setting page size to ${PAGESIZE}])

AC_CONFIG_FILES([Makefile src/Makefile tests/Makefile patchelf.spec])
AC_OUTPUT
