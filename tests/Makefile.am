LIBS =

check_PROGRAMS = simple-pie simple simple-execstack main too-many-strtab main-scoped big-dynstr no-rpath contiguous-note-sections

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
  set-interpreter-long.sh set-rpath.sh add-rpath.sh no-rpath.sh big-dynstr.sh \
  set-rpath-library.sh soname.sh shrink-rpath-with-allowed-prefixes.sh \
  set-rpath-rel-map.sh \
  force-rpath.sh \
  plain-needed.sh \
  output-flag.sh \
  too-many-strtab.sh \
  no-rpath-pie-powerpc.sh \
  build-id.sh \
  invalid-elf.sh \
  endianness.sh \
  contiguous-note-sections.sh \
  no-gnu-hash.sh \
  change-abi.sh \
  grow-file.sh \
  no-dynamic-section.sh \
  args-from-file.sh \
  basic-flags.sh \
  set-empty-rpath.sh \
  phdr-corruption.sh \
  replace-needed.sh \
  replace-add-needed.sh \
  add-debug-tag.sh \
  repeated-updates.sh \
  empty-note.sh \
  print-execstack.sh \
  modify-execstack.sh \
  rename-dynamic-symbols.sh \
  overlapping-segments-after-rounding.sh \
  shared-rpath.sh \
  short-first-segment.sh \
  empty-note.sh

build_TESTS = \
  $(no_rpath_arch_TESTS)

TESTS = $(src_TESTS) $(build_TESTS)

EXTRA_DIST = no-rpath-prebuild $(src_TESTS) no-rpath-prebuild.sh invalid-elf endianness empty-note \
			 overlapping-segments-after-rounding short-first-segment.gz

TESTS_ENVIRONMENT = PATCHELF_DEBUG=1 STRIP=$(STRIP) OBJDUMP=$(OBJDUMP) READELF=$(READELF) OBJCOPY=$(OBJCOPY)

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
simple_LDFLAGS = -Wl,-z,noexecstack

simple_pie_SOURCES = simple.c
simple_pie_CFLAGS = -fPIC -pie

simple_execstack_SOURCES = simple.c
simple_execstack_CFLAGS =
simple_execstack_LDFLAGS = -Wl,-z,execstack

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
	i=1; while [ $$i -le 2000 ]; do echo "void f$$i(void) { };"; i=$$(($$i + 1)); done >> big-dynstr.c

nodist_big_dynstr_SOURCES = big-dynstr.c
big_dynstr_LDADD = -lfoo $(AM_LDADD)
big_dynstr_DEPENDENCIES = libfoo.so
big_dynstr_LDFLAGS = $(LDFLAGS_local)

# somehow bug does not trigger if we use
# normal autotools rules to build the program:
# https://github.com/NixOS/patchelf/pull/303
libbig-dynstr.so: big-dynstr.c
	$(CC) -fPIC -shared -o $@ $<
libbig-dynstr.debug: libbig-dynstr.so
	$(STRIP) --only-keep-debug libbig-dynstr.so -o libbig-dynstr.debug
check_DATA = libbig-dynstr.debug


# declare local shared libraries as programs as:
# - without libtool, only archives (static libraries) can be built by automake
# - with libtool, it is difficult to control options
# - with libtool, it is not possible to compile convenience *dynamic* libraries :-(
check_PROGRAMS += libfoo.so libfoo-scoped.so libbar.so libbar-scoped.so libsimple.so libsimple-execstack.so libbuildid.so libtoomanystrtab.so \
                  phdr-corruption.so many-syms-main libmany-syms.so liboveralign.so libshared-rpath.so

libbuildid_so_SOURCES = simple.c
libbuildid_so_LDFLAGS = $(LDFLAGS_sharedlib) -Wl,--build-id

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
libsimple_so_LDFLAGS = $(LDFLAGS_sharedlib) -Wl,-z,noexecstack

liboveralign_so_SOURCES = simple.c
liboveralign_so_LDFLAGS = $(LDFLAGS_sharedlib) -Wl,-z,max-page-size=0x10000

libshared_rpath_so_SOURCES = shared-rpath.c
libshared_rpath_so_LDFLAGS = $(LDFLAGS_sharedlib) -Wl,-rpath=a_symbol_name

libsimple_execstack_so_SOURCES = simple.c
libsimple_execstack_so_LDFLAGS = $(LDFLAGS_sharedlib) -Wl,-z,execstack

too_many_strtab_SOURCES = too-many-strtab.c too-many-strtab2.s
libtoomanystrtab_so_SOURCES = too-many-strtab.c too-many-strtab2.s
libtoomanystrtab_so_LDFLAGS = $(LDFLAGS_sharedlib)

many_syms_main_SOURCES = many-syms-main.c 
many_syms_main_LDFLAGS = $(LDFLAGS_local) 
many_syms_main_LDADD = -lmany-syms $(AM_LDADD)
many_syms_main_DEPENDENCIES = libmany-syms.so
many_syms_main_CFLAGS = -pie
libmany_syms_so_SOURCES = many-syms.c
libmany_syms_so_LDFLAGS = $(LDFLAGS_sharedlib)

no_rpath_SOURCES = no-rpath.c
# no -fpic for no-rpath.o
no_rpath_CFLAGS =

contiguous_note_sections_SOURCES = contiguous-note-sections.s contiguous-note-sections.ld
contiguous_note_sections_LDFLAGS = -nostdlib -T $(srcdir)/contiguous-note-sections.ld
contiguous_note_sections_CFLAGS = -pie

phdr_corruption_so_SOURCES = void.c phdr-corruption.ld
phdr_corruption_so_LDFLAGS = -nostdlib -shared -Wl,-T$(srcdir)/phdr-corruption.ld
phdr_corruption_so_CFLAGS =

many-syms.c:
	i=1; while [ $$i -le 2000 ]; do echo "void f$$i() {};"; i=$$(($$i + 1)); done > $@

many-syms-main.c:
	echo "int main() {" > $@
	i=1; while [ $$i -le 2000 ]; do echo "void f$$i(); f$$i();"; i=$$(($$i + 1)); done >> $@
	echo "}" >> $@

