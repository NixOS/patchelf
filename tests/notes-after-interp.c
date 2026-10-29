/* Several 4-byte aligned notes that notes-after-interp.ld groups into one
   PT_NOTE directly after .interp, like Go binaries. */
#define NOTE(name)                                   \
    __asm__(".section .note." #name ",\"a\",%note\n" \
            ".p2align 2\n"                           \
            ".long 4, 4, 1\n"                        \
            ".asciz \"Tst\"\n"                       \
            ".long 0\n"                              \
            ".previous\n");

NOTE(one)
NOTE(two)
NOTE(three)

int main(void)
{
    return 0;
}
