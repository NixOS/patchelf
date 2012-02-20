SUBDIRS = src tests

EXTRA_DIST = COPYING README patchelf.spec version $(man1_MANS)

man1_MANS = patchelf.1

install-data-local:
	$(INSTALL) -d $(DESTDIR)$(docdir)
	$(INSTALL_DATA) $(top_srcdir)/README $(DESTDIR)$(docdir)/
