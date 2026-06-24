/* Test helper: insert zero padding before the section header table so it ends
 * on a 0x10000 boundary (covers every page size patchelf uses). This is the
 * layout that triggers the ET_EXEC note corruption in --build-resolution-cache,
 * where the in-place SHT rewrite would overwrite the note's Elf_Nhdr.
 *
 * The binary under test is native-endian (built by the same toolchain), so
 * fields are read and written directly.
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

    if (shoff + shnum * shentsize != (uint64_t) sz)
        die("section header table is not at end of file");

    long pad = (long) ((ALIGN - (sz % ALIGN)) % ALIGN);
    if (pad == 0) {
        free(buf);
        return 0;
    }

    if (is64)
        ((Elf64_Ehdr *) buf)->e_shoff = shoff + pad;
    else
        ((Elf32_Ehdr *) buf)->e_shoff = (Elf32_Off) (shoff + pad);

    FILE * out = fopen(argv[1], "wb");
    if (!out)
        die("cannot reopen file for writing");

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
