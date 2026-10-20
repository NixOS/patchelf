/* Native-endian ELF fixture and helper for section-index sh_info fields.
 * Empty CREL streams let this test run without an experimental LLVM assembler.
 * The non-allocated test sections are metadata, not dynamic relocations.
 */
#include "../src/elf.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const unsigned char crel[] __attribute__((section(".crel.test"), used)) = {0};
static const unsigned char info[] __attribute__((section(".info.test"), used)) = {0};
static const unsigned char zero[] __attribute__((section(".zero.test"), used)) = {0};
static const unsigned char count[] __attribute__((section(".count.test"), used)) = {0};

#define TEST_SHT_CREL 20

static void die(const char * msg)
{
    fprintf(stderr, "section-info: %s\n", msg);
    exit(1);
}

#define CHECK_ELF(BITS) do { \
    Elf##BITS##_Ehdr * eh = (Elf##BITS##_Ehdr *) buf; \
    if (eh->e_shentsize != sizeof(Elf##BITS##_Shdr) || \
        eh->e_shoff > (size_t) sz || \
        eh->e_shnum > ((size_t) sz - eh->e_shoff) / sizeof(Elf##BITS##_Shdr) || \
        eh->e_shstrndx >= eh->e_shnum) \
        die("invalid section header table"); \
    Elf##BITS##_Shdr * sh = (Elf##BITS##_Shdr *) (buf + eh->e_shoff); \
    Elf##BITS##_Shdr * str = &sh[eh->e_shstrndx]; \
    if (str->sh_offset > (size_t) sz || str->sh_size > (size_t) sz - str->sh_offset) \
        die("invalid section name table"); \
    char * names = (char *) buf + str->sh_offset; \
    unsigned int text = 0, symtab = 0, found = 0; \
    for (unsigned int i = 1; i < eh->e_shnum; ++i) { \
        if (sh[i].sh_name >= str->sh_size || \
            !memchr(names + sh[i].sh_name, 0, str->sh_size - sh[i].sh_name)) \
            die("invalid section name"); \
        if (!strcmp(names + sh[i].sh_name, ".text")) text = i; \
        if (!strcmp(names + sh[i].sh_name, ".symtab")) symtab = i; \
    } \
    if (!text || !symtab) die("missing text or symbol table"); \
    for (unsigned int i = 1; i < eh->e_shnum; ++i) { \
        const char * name = names + sh[i].sh_name; \
        int is_crel = !strcmp(name, ".crel.test"); \
        int is_info = !strcmp(name, ".info.test"); \
        int is_zero = !strcmp(name, ".zero.test"); \
        int is_count = !strcmp(name, ".count.test"); \
        if (!(is_crel || is_info || is_zero || is_count)) continue; \
        ++found; \
        if (prepare) { \
            sh[i].sh_flags = is_count ? 0 : SHF_INFO_LINK; \
            sh[i].sh_type = is_crel ? TEST_SHT_CREL : SHT_PROGBITS; \
            sh[i].sh_info = is_count ? 42 : is_zero ? 0 : text; \
            sh[i].sh_link = is_crel ? symtab : 0; \
            sh[i].sh_entsize = 0; \
        } else { \
            if (sh[i].sh_type != (is_crel ? TEST_SHT_CREL : SHT_PROGBITS) || \
                sh[i].sh_flags != (is_count ? 0 : SHF_INFO_LINK) || \
                sh[i].sh_info != (is_count ? 42 : is_zero ? 0 : text) || \
                sh[i].sh_link != (is_crel ? symtab : 0)) \
                die(name); \
        } \
    } \
    if (found != 4) die("missing fixture sections"); \
    printf("%u\n", text); \
} while (0)

int main(int argc, char ** argv)
{
    if (argc != 3 || (strcmp(argv[1], "prepare") && strcmp(argv[1], "check")))
        die("usage: section-info prepare|check ELF");
    int prepare = !strcmp(argv[1], "prepare");
    FILE * f = fopen(argv[2], "rb");
    if (!f || fseek(f, 0, SEEK_END)) die("cannot open file");
    long sz = ftell(f);
    if (sz < (long) sizeof(Elf64_Ehdr)) die("file too small");
    rewind(f);
    unsigned char * buf = malloc(sz);
    if (!buf || fread(buf, 1, sz, f) != (size_t) sz) die("short read");
    fclose(f);
    if (memcmp(buf, ELFMAG, SELFMAG)) die("not an ELF file");
    unsigned short endian = 1;
    if (buf[EI_DATA] != (*(unsigned char *) &endian ? ELFDATA2LSB : ELFDATA2MSB))
        die("fixture must have native byte order");
    if (buf[EI_CLASS] == ELFCLASS64) CHECK_ELF(64);
    else if (buf[EI_CLASS] == ELFCLASS32) CHECK_ELF(32);
    else die("invalid ELF class");
    if (prepare) {
        f = fopen(argv[2], "wb");
        if (!f || fwrite(buf, 1, sz, f) != (size_t) sz || fclose(f))
            die("write failed");
    }
    free(buf);
    return 0;
}
