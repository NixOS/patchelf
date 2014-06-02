SUBDIRS = src tests

man1_MANS = man/patchelf.1

doc_DATA = AUTHORS BUGS README.md

strip: all
	$(STRIP) src/patchelf

test: check

install-data-hook:
	gzip -9f $(DESTDIR)/$(mandir)/man1/patchelf.1
