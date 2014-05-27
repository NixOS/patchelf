AC_INIT([PatchELF],
        m4_esyscmd([echo -n $(cat ./version)]),
        [https://github.com/NixOS/patchelf])

AC_CONFIG_SRCDIR([src/patchelf.cpp])

AC_CONFIG_AUX_DIR([build-aux])
AM_PROG_CC_C_O
AM_INIT_AUTOMAKE([-Wall -Werror dist-bzip2 foreign color-tests parallel-tests])

# Checks for programs.
AC_CHECK_PROG(STRIP, strip, [$(which strip) --verbose])
AC_CHECK_PROG(MD5SUM, md5sum, [$(which md5sum)])  # used for tests/backup.sh
AC_CHECK_PROG(MD5, md5, [$(which md5)])
AC_PROG_CXX
AC_PROG_LN_S
AC_PROG_MAKE_SET

# Checks for header files.
AC_HEADER_STDC
AC_CHECK_HEADERS([fcntl.h getopt.h limits.h stdlib.h string.h unistd.h], [], [exit 1], [])

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
                 man/patchelf.1 \
                 patchelf.spec
                 ])
AC_OUTPUT
