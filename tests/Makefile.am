check_PROGRAMS = main simple

TESTS = plain-run.sh shrink.sh set-interpreter-short.sh \
  set-interpreter-long.sh set-rpath.sh $(XFAIL_TESTS)

XFAIL_TESTS = plain-fail.sh


simple_SOURCES = simple.c


main: main.o libfoo.so
	LD_LIBRARY_PATH=. $(CC) -o main main.o -L . -lfoo

main.o: main.c
	$(CC) -fpic -o main.o -c main.c

libfoo.so: foo.o libbar.so
	$(CC) -shared -o libfoo.so foo.o -L . -lbar -Wl,-rpath,`pwd`/no-such-path

foo.o: foo.c
	$(CC) -fpic -o foo.o -c foo.c

libbar.so: bar.o
	$(CC) -shared -o libbar.so bar.o -L .

bar.o: bar.c
	$(CC) -fpic -o bar.o -c bar.c

clean-local:
	$(RM) *.o libfoo.so libbar.so main


EXTRA_DIST = main.c foo.c bar.c $(TESTS)
