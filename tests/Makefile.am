check_PROGRAMS = main simple big-dynstr

TESTS = plain-fail.sh plain-run.sh shrink-rpath.sh set-interpreter-short.sh \
  set-interpreter-long.sh set-rpath.sh no-rpath.sh big-dynstr.sh 

TESTS_ENVIRONMENT = PATCHELF_DEBUG=1


simple_SOURCES = simple.c


main: main.o libfoo.so
	LD_LIBRARY_PATH=. gcc -o main main.o -L . -lfoo

main.o: main.c
	$(CC) -fpic -o main.o -c main.c

libfoo.so: foo.o libbar.so
	$(CC) -shared -o libfoo.so foo.o -L . -lbar

foo.o: foo.c
	$(CC) -fpic -o foo.o -c foo.c

libbar.so: bar.o
	NIX_DONT_SET_RPATH=1 $(CC) -shared -o libbar.so bar.o -L . -Wl,-rpath,`pwd`/no-such-path

bar.o: bar.c
	$(CC) -fpic -o bar.o -c bar.c


big_dynstr_SOURCES = big-dynstr.c

big-dynstr: big-dynstr.o libfoo.so
	LD_LIBRARY_PATH=. gcc -o big-dynstr big-dynstr.o -L . -lfoo

big-dynstr.c: main.c
	cat main.c > big-dynstr.c
	for i in $$(seq 1 2000); do echo "void f$$i(void) { };" >> big-dynstr.c; done


clean-local:
	$(RM) *.o libfoo.so libbar.so main big-dynstr big-dynstr.c


EXTRA_DIST = main.c foo.c bar.c no-rpath $(TESTS)
