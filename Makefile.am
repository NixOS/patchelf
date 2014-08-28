SUBDIRS = src tests

EXTRA_DIST = COPYING README patchelf.spec version $(man1_MANS)

man1_MANS = patchelf.1

doc_DATA = README

strip: all
	$(STRIP) src/patchelf

test: check

install-data-hook:
	gzip -9f $(DESTDIR)/$(mandir)/man1/patchelf.1
