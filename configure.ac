AC_INIT([PatchELF],
        m4_esyscmd([echo -n $(cat ./version)]),
        [https://github.com/NixOS/patchelf])

#AC_CONFIG_HEADERS(config.h)
AC_CONFIG_SRCDIR([src/patchelf.cc])

AC_CONFIG_AUX_DIR([build-aux])
AM_PROG_CC_C_O
AM_INIT_AUTOMAKE([-Wall -Werror dist-bzip2 foreign color-tests parallel-tests])

# Checks for programs.
AC_PROG_CXX
AC_PROG_LN_S
AC_PROG_MAKE_SET

# Checks for header files.
AC_HEADER_STDC
AC_CHECK_HEADERS([fcntl.h limits.h stdlib.h string.h unistd.h], [], [exit 1], [])

# Checks for libraries.
AC_CHECK_HEADERS([attr/libattr.h attr/error_context.h])
AC_SEARCH_LIBS(attr_copy_file, attr)
AC_CHECK_FUNCS([attr_copy_file])

AC_CHECK_HEADERS([sys/acl.h acl/libacl.h])
AC_SEARCH_LIBS(perm_copy_file, acl)
AC_CHECK_FUNCS([perm_copy_file])

# Checks for typedefs, structures, and compiler characteristics.
AC_HEADER_STDBOOL
AC_TYPE_MODE_T
AC_TYPE_OFF_T
AC_TYPE_SIZE_T

# Checks for library functions.
AC_FUNC_ERROR_AT_LINE
AC_FUNC_MALLOC
AC_CHECK_FUNCS([memmove memset strchr])

AC_CONFIG_FILES([Makefile \
                 src/Makefile \
                 tests/Makefile \
                 patchelf.spec
                 ])
AC_OUTPUT
