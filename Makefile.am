SUBDIRS = src tests

man1_MANS = man/patchelf.1

doc_DATA = README.md COPYING ChangeLog AUTHORS BUGS

strip: all
	$(STRIP) src/patchelf

test: check

install-data-hook:
	gzip -9f $(DESTDIR)/$(mandir)/man1/patchelf.1
