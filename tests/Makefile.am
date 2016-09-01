LIBS =

check_PROGRAMS = simple main main-scoped big-dynstr no-rpath

no_rpath_arch_TESTS = \
  no-rpath-amd64.sh \
  no-rpath-armel.sh \
  no-rpath-armhf.sh \
  no-rpath-hurd-i386.sh \
  no-rpath-i386.sh \
  no-rpath-ia64.sh \
  no-rpath-kfreebsd-amd64.sh \
  no-rpath-kfreebsd-i386.sh \
  no-rpath-mips.sh \
  no-rpath-mipsel.sh \
  no-rpath-powerpc.sh \
  no-rpath-s390.sh \
  no-rpath-sh4.sh \
  no-rpath-sparc.sh

src_TESTS = \
  plain-fail.sh plain-run.sh shrink-rpath.sh set-interpreter-short.sh \
  set-interpreter-long.sh set-rpath.sh no-rpath.sh big-dynstr.sh \
  set-rpath-library.sh soname.sh shrink-rpath-with-allowed-prefixes.sh

build_TESTS = \
  $(no_rpath_arch_TESTS)

TESTS = $(src_TESTS) $(build_TESTS)

EXTRA_DIST = no-rpath-prebuild $(src_TESTS) no-rpath-prebuild.sh

TESTS_ENVIRONMENT = PATCHELF_DEBUG=1

$(no_rpath_arch_TESTS): no-rpath-prebuild.sh
	@ln -s $< $@

CLEANFILES = big-dynstr.c
clean-local:
	$(RM) -r scratch $(no_rpath_arch_TESTS)

# by default, use -fpic to compile
AM_CFLAGS = -fpic
LDFLAGS_local = -Wl,--disable-new-dtags -Wl,-rpath-link=. -L. $(AM_LDFLAGS)
LDFLAGS_sharedlib = -Wl,--disable-new-dtags -shared -L. $(AM_LDFLAGS)
export NIX_DONT_SET_RPATH=1
export NIX_LDFLAGS=

simple_SOURCES = simple.c
# no -fpic for simple.o
simple_CFLAGS =

main_SOURCES = main.c
main_LDADD = -lfoo $(AM_LDADD)
main_DEPENDENCIES = libfoo.so
main_LDFLAGS = $(LDFLAGS_local)

main_scoped_SOURCES = main.c
main_scoped_LDADD = -lfoo-scoped $(AM_LDADD)
main_scoped_DEPENDENCIES = libfoo-scoped.so
main_scoped_LDFLAGS = $(LDFLAGS_local)

big-dynstr.c: main.c
	cat $< > big-dynstr.c
	for i in $$(seq 1 2000); do echo "void f$$i(void) { };" >> big-dynstr.c; done

nodist_big_dynstr_SOURCES = big-dynstr.c
big_dynstr_LDADD = -lfoo $(AM_LDADD)
big_dynstr_DEPENDENCIES = libfoo.so
big_dynstr_LDFLAGS = $(LDFLAGS_local)

# declare local shared libraries as programs as:
# - without libtool, only archives (static libraries) can be built by automake
# - with libtool, it is difficult to control options
# - with libtool, it is not possible to compile convenience *dynamic* libraries :-(
check_PROGRAMS += libfoo.so libfoo-scoped.so libbar.so libbar-scoped.so libsimple.so

libfoo_so_SOURCES = foo.c
libfoo_so_LDADD = -lbar $(AM_LDADD)
libfoo_so_DEPENDENCIES = libbar.so
libfoo_so_LDFLAGS = $(LDFLAGS_sharedlib)

libfoo_scoped_so_SOURCES = foo.c
libfoo_scoped_so_LDADD = -lbar-scoped $(AM_LDADD)
libfoo_scoped_so_DEPENDENCIES = libbar-scoped.so
libfoo_scoped_so_LDFLAGS = $(LDFLAGS_sharedlib)

libbar_so_SOURCES = bar.c
libbar_so_LDFLAGS = $(LDFLAGS_sharedlib) -Wl,-rpath,`pwd`/no-such-path

libbar_scoped_so_SOURCES = bar.c
libbar_scoped_so_LDFLAGS = $(LDFLAGS_sharedlib)

libsimple_so_SOURCES = simple.c
libsimple_so_LDFLAGS = $(LDFLAGS_sharedlib)

no_rpath_SOURCES = no-rpath.c
# no -fpic for no-rpath.o
no_rpath_CFLAGS =
