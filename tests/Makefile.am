check_PROGRAMS = main simple

TESTS = plain-run.sh shrink.sh set-interpreter-short.sh \
  set-interpreter-long.sh set-rpath.sh no-rpath.sh $(XFAIL_TESTS)

XFAIL_TESTS = plain-fail.sh


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

clean-local:
	$(RM) *.o libfoo.so libbar.so main


EXTRA_DIST = main.c foo.c bar.c no-rpath $(TESTS)
