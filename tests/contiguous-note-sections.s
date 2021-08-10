/*
 * Testcase for error:
 * patchelf: cannot normalize PT_NOTE segment: non-contiguous SHT_NOTE sections
 */
.section ".note.my-section0", "a", %note
    .align 4
    .long 1f - 0f              /* name length (not including padding) */
    .long 3f - 2f              /* desc length (not including padding) */
    .long 1                    /* type = NT_VERSION */
0:  .asciz "my-version-12345" /* name */
1:  .align 4
2:  .long 1                    /* desc - toolchain version number, 32-bit LE */
3:  .align 4

.section ".note.my-section1", "a", %note
    .align 8
    .long 1f - 0f              /* name length (not including padding) */
    .long 3f - 2f              /* desc length (not including padding) */
    .long 1                    /* type = NT_VERSION */
0:  .asciz "my-version-1" /* name */
1:  .align 4
2:  .long 1                    /* desc - toolchain version number, 32-bit LE */
3:  .align 4
