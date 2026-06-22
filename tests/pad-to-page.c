/* Test helper: page-align an ELF's section header table.
 *
 * Inserts zero padding immediately before the section header table (SHT) so
 * that the SHT (which the test toolchain places at the end of the file) ends on
 * a 0x10000 boundary. Only e_shoff needs adjusting, since every section's data
 * lives before the SHT.
 *
 * This reproduces, deterministically, the file layout that triggers the
 * ET_EXEC note corruption in `patchelf --build-resolution-cache`: the note is
 * placed at roundUp(fileSize, pageSize), which then coincides with where the
 * grown section header table is rewritten in place, so the note's own section
 * header overwrites its Elf_Nhdr. Aligning to 0x10000 covers every page size
 * patchelf uses (0x1000 / 0x2000 / 0x10000).
 *
 * The binary under test is built by the same toolchain that builds this helper,
 * so it is native-endian; fields are read and written directly.
 */
#include <elf.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ALIGN 0x10000UL

static void die(const char * msg)
{
    fprintf(stderr, "pad-to-page: %s\n", msg);
    exit(2);
}

int main(int argc, char ** argv)
{
    if (argc != 2)
        die("usage: pad-to-page ELF");

    FILE * f = fopen(argv[1], "rb");
    if (!f)
        die("cannot open file");
    if (fseek(f, 0, SEEK_END))
        die("seek failed");
    long sz = ftell(f);
    if (sz < (long) sizeof(Elf64_Ehdr))
        die("file too small");
    rewind(f);

    unsigned char * buf = malloc(sz);
    if (!buf)
        die("out of memory");
    if (fread(buf, 1, sz, f) != (size_t) sz)
        die("short read");
    fclose(f);

    if (memcmp(buf, ELFMAG, SELFMAG) != 0)
        die("not an ELF file");

    /* Read e_shoff / e_shentsize / e_shnum for the file's ELF class. */
    uint64_t shoff;
    uint64_t shentsize;
    uint64_t shnum;
    int is64 = buf[EI_CLASS] == ELFCLASS64;
    if (is64) {
        Elf64_Ehdr * eh = (Elf64_Ehdr *) buf;
        shoff = eh->e_shoff;
        shentsize = eh->e_shentsize;
        shnum = eh->e_shnum;
    } else {
        Elf32_Ehdr * eh = (Elf32_Ehdr *) buf;
        shoff = eh->e_shoff;
        shentsize = eh->e_shentsize;
        shnum = eh->e_shnum;
    }

    /* The trigger requires the SHT to sit at the end of the file. */
    if (shoff + shnum * shentsize != (uint64_t) sz)
        die("section header table is not at end of file");

    long pad = (long) ((ALIGN - (sz % ALIGN)) % ALIGN);
    if (pad == 0) {
        free(buf);
        return 0; /* already page-aligned: trigger already holds */
    }

    /* Bump e_shoff by the padding we insert before the SHT. */
    if (is64)
        ((Elf64_Ehdr *) buf)->e_shoff = shoff + pad;
    else
        ((Elf32_Ehdr *) buf)->e_shoff = (Elf32_Off) (shoff + pad);

    FILE * out = fopen(argv[1], "wb");
    if (!out)
        die("cannot reopen file for writing");

    /* pad is in [0, ALIGN), so a single ALIGN-sized buffer covers it. */
    static const unsigned char zero[ALIGN] = {0};
    if (fwrite(buf, 1, shoff, out) != shoff)
        die("write failed");
    if (fwrite(zero, 1, (size_t) pad, out) != (size_t) pad)
        die("write failed");
    if (fwrite(buf + shoff, 1, sz - shoff, out) != (size_t) (sz - shoff))
        die("write failed");

    fclose(out);
    free(buf);
    return 0;
}
