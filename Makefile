default: runtest

patchelf: patchelf.c
	gcc -Wall -o patchelf patchelf.c

test: test.c 
	gcc -Wall -o test test.c

TEST = svn

runtest: $(TEST) patchelf
	readelf -a $(TEST) > dump1
#	./patchelf --interpreter /nix/store/42de22963bca8f234ad54b01118215df-glibc-2.3.2/lib/ld-linux.so.2 \
#	  --shrink-rpath $(TEST)
	./patchelf --shrink-rpath $(TEST)
	readelf -a new.exe > dump2
