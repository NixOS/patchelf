AC_INIT([patchelf], m4_esyscmd([printf $(cat ./version)]))
AC_CONFIG_SRCDIR([src/patchelf.cc])
AC_CONFIG_AUX_DIR([build-aux])
AM_INIT_AUTOMAKE([-Wall -Werror dist-bzip2 foreign color-tests parallel-tests])

AM_PROG_CC_C_O
AC_PROG_CXX

PAGESIZE=auto
AC_ARG_WITH([page-size],
	    AS_HELP_STRING([--with-page-size=SIZE], [Specify default pagesize (default auto)]),
	    PAGESIZE=$withval
	    )

AS_IF([test "x$PAGESIZE" = xauto],
	AS_IF([which getconf &>/dev/null], [
	       PAGESIZE=`getconf PAGESIZE &>/dev/null || getconf PAGE_SIZE &>/dev/null`
	])
	AS_IF([test "x$PAGESIZE" = x], [
	       PAGESIZE=4096
	])
)

AC_DEFINE_UNQUOTED(PAGESIZE, ${PAGESIZE})
AC_MSG_RESULT([Setting page size to ${PAGESIZE}])

AC_CONFIG_FILES([Makefile src/Makefile tests/Makefile patchelf.spec])
AC_OUTPUT
