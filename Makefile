default: runtest

patchelf: patchelf.c
	gcc -Wall -o patchelf patchelf.c

test: test.c 
	gcc -Wall -o test test.c

runtest: test patchelf
	readelf -a test > dump1
	./patchelf test
	readelf -a new.exe > dump2
