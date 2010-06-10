SUBDIRS = src tests

EXTRA_DIST = COPYING README patchelf.spec patchelf.spec.in version $(man1_MANS)

patchelf.spec: patchelf.spec.in
	sed -e "s^@version\@^$(VERSION)^g" < patchelf.spec.in > patchelf.spec

man1_MANS = patchelf.1

install-data-local:
	$(INSTALL) -d $(DESTDIR)$(docdir)
	$(INSTALL_DATA) README $(DESTDIR)$(docdir)/
