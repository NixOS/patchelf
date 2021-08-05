all:
	$(CC) -xc -nostdlib -shared -o libtest.so - <<< 'void test() {}'
	$(CC) -xc -nostdlib -L. -ltest -o main - <<< 'void _start() {}'
