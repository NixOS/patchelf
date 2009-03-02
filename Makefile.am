SUBDIRS = src tests

EXTRA_DIST = COPYING README patchelf.spec patchelf.spec.in version

patchelf.spec: patchelf.spec.in
	sed -e "s^@version\@^$(VERSION)^g" < patchelf.spec.in > patchelf.spec

install-data-local:
	$(INSTALL) -d $(DESTDIR)$(docdir)
	$(INSTALL_DATA) README $(DESTDIR)$(docdir)/
