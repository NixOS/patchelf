AC_INIT([patchelf], m4_esyscmd([echo -n $(cat ./version)]))
AC_CONFIG_SRCDIR([src/patchelf.cc])
AC_CONFIG_AUX_DIR([build-aux])
AM_INIT_AUTOMAKE([-Wall -Werror dist-bzip2 foreign color-tests parallel-tests])

AM_PROG_CC_C_O
AC_PROG_CXX

AC_CHECK_HEADERS([attr/libattr.h attr/error_context.h])
AC_SEARCH_LIBS(attr_copy_file, attr)
AC_CHECK_FUNCS([attr_copy_file])

AC_CHECK_HEADERS([sys/acl.h acl/libacl.h])
AC_SEARCH_LIBS(perm_copy_file, acl)
AC_CHECK_FUNCS([perm_copy_file])

AC_CONFIG_FILES([Makefile src/Makefile tests/Makefile patchelf.spec])
AC_OUTPUT
