AC_INIT([PatchELFmod], m4_esyscmd([echo -n $(cat ./version)]))

AC_CONFIG_SRCDIR([src])
AC_CONFIG_AUX_DIR([build-aux])

AM_INIT_AUTOMAKE([-Wall -Werror dist-bzip2 foreign color-tests parallel-tests])
AC_CHECK_HEADERS([assert.h elf.h errno.h fcntl.h limits.h stdarg.h stdio.h], [], [exit 0], [])

AM_PROG_CC_C_O
AC_PROG_CXX

AC_CONFIG_FILES([
        Makefile \
        man/patchelfmod.1 \
        src/Makefile \
        tests/Makefile \
        patchelfmod.spec
        ])
AC_OUTPUT
