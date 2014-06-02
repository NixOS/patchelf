SUBDIRS = src tests

man/patchelf.1.gz:
	gzip -9fk man/patchelf.1

man1_MANS = man/patchelf.1.gz

doc_DATA = AUTHORS BUGS README.md

strip: all
	$(STRIP) src/patchelf

test: check

CLEANFILES = man/patchelf.1.gz
