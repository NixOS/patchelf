SUBDIRS = src tests

EXTRA_DIST = COPYING README patchelf.spec patchelf.spec.in

patchelf.spec: patchelf.spec.in
	sed -e "s^@version\@^$(VERSION)^g" < patchelf.spec.in > patchelf.spec
