/* DT_INIT points at this symbol (in .text) via -Wl,-init, while crti.o
   still contributes a separate .init section. */
void my_init(void) { }
