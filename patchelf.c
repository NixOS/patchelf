#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
#include <string.h>
#include <errno.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>

#include <elf.h>


#define MAX_PHEADERS 128
#define MAX_SHEADERS 128


static off_t fileSize, maxSize;
static unsigned char * contents = 0;
static Elf32_Phdr phdrs[MAX_PHEADERS];
static Elf32_Shdr shdrs[MAX_SHEADERS];


static void error(char * msg)
{
    if (errno) perror(msg); else printf("%s\n", msg);
    exit(1);
}


static void growFile(off_t newSize)
{
    if (newSize > maxSize) error("maximum file size exceeded");
    if (newSize <= fileSize) return;
    if (newSize > fileSize)
        memset(contents + fileSize, 0, newSize - fileSize);
    fileSize = newSize;
}


static void readFile(char * fileName)
{
    struct stat st;
    if (stat(fileName, &st) != 0) error("stat");
    fileSize = st.st_size;
    maxSize = fileSize + 128 * 1024;
    
    contents = malloc(fileSize + maxSize);
    if (!contents) abort();

    int fd = open(fileName, O_RDONLY);
    if (fd == -1) error("open");

    if (read(fd, contents, fileSize) != fileSize) error("read");
    
    close(fd);
}


static void writeFile(char * fileName)
{
    int fd = open(fileName, O_CREAT | O_TRUNC | O_WRONLY, 0777);
    if (fd == -1) error("open");

    if (write(fd, contents, fileSize) != fileSize) error("write");
    
    close(fd);
}


static unsigned int roundUp(unsigned int n, unsigned int m)
{
    return ((n - 1) / m + 1) * m;
}


//char newInterpreter[] = "/lib/ld-linux.so.2";
char newInterpreter[] = "/nix/store/42de22963bca8f234ad54b01118215df-glibc-2.3.2/lib/ld-linux.so.2";
//char newInterpreter[] = "/nix/store/2ccde1632ef69ebdb5f21cd2222d19f2-glibc-2.3.3/lib/ld-linux.so.2";


static void patchElf(char * fileName)
{
    fprintf(stderr, "patching %s\n", fileName);

    readFile(fileName);

    /* Check the ELF header for basic validity. */
    if (fileSize < sizeof(Elf32_Ehdr)) error("missing ELF header");

    Elf32_Ehdr * hdr = (Elf32_Ehdr *) contents;

    if (memcmp(hdr->e_ident, ELFMAG, 4) != 0)
        error("not an ELF executable");

    if (contents[EI_CLASS] != ELFCLASS32 ||
        contents[EI_DATA] != ELFDATA2LSB ||
        contents[EI_VERSION] != EV_CURRENT)
        error("ELF executable is not 32-bit, little-endian, version 1");

    if (hdr->e_type != ET_EXEC && hdr->e_type != ET_DYN)
        error("wrong ELF type");
    
    fprintf(stderr, "%d ph entries, %d sh entries\n",
        hdr->e_phnum, hdr->e_shnum);

    if (hdr->e_phoff + hdr->e_phnum * hdr->e_phentsize > fileSize)
        error("missing program headers");
    
    if (hdr->e_shoff + hdr->e_shnum * hdr->e_shentsize > fileSize)
        error("missing section headers");

    if (hdr->e_phentsize != sizeof(Elf32_Phdr))
        error("program headers have wrong size");

    /* Copy the program and section headers. */
    memcpy(phdrs, contents + hdr->e_phoff, hdr->e_phnum * sizeof(Elf32_Phdr));
    memcpy(shdrs, contents + hdr->e_shoff, hdr->e_shnum * sizeof(Elf32_Shdr));

    /* Find the next free virtual address page so that we can add
       segments without messing up other segments. */
    int i;
    unsigned int nextFreePage = 0;
    for (i = 0; i < hdr->e_phnum; ++i) {
        Elf32_Phdr * phdr = phdrs + i;
        unsigned int end = roundUp(phdr->p_vaddr + phdr->p_memsz, 4096);
        if (end > nextFreePage) nextFreePage = end;
    }

    fprintf(stderr, "next free page is %x\n", nextFreePage);

    unsigned int firstPage = 0x08047000;
    
    /* Move the entire contents of the file one page further. */
    unsigned int oldSize = fileSize;
    growFile(fileSize + 4096);
    memmove(contents + 4096, contents, oldSize);
    memset(contents + sizeof(Elf32_Ehdr), 0, 4096 - sizeof(Elf32_Ehdr));

    /* Update the ELF header. */
    hdr->e_shoff += 4096;

    /* Update the offsets in the section headers. */
    for (i = 0; i < hdr->e_shnum; ++i) {
        shdrs[i].sh_offset += 4096;
    }
    
    /* Update the offsets in the program headers. */
    for (i = 0; i < hdr->e_phnum; ++i) {
        phdrs[i].p_offset += 4096;
    }

    /* Add a segment that maps the new program/section headers and
       PT_INTERP segment into memory.  Otherwise glibc will choke. Add
       this after the PT_PHDR segment but before all other PT_LOAD
       segments. */
    for (i = hdr->e_phnum; i > 1; --i)
        phdrs[i] = phdrs[i - 1];
    hdr->e_phnum++;
    Elf32_Phdr * phdr = phdrs + 1;
    phdr->p_type = PT_LOAD;
    phdr->p_offset = 0;
    phdr->p_vaddr = phdr->p_paddr = firstPage;
    phdr->p_filesz = phdr->p_memsz = 4096;
    phdr->p_flags = PF_R;
    phdr->p_align = 4096;

    unsigned int freeOffset = sizeof(Elf32_Ehdr);

    /* Find the PT_INTERP segment and replace it by a new one that
       contains the new interpreter name. */
    unsigned int interpOffset = 0, interpSize = 0, interpAddr = 0;
    for (i = 0; i < hdr->e_phnum; ++i) {
        Elf32_Phdr * phdr = phdrs + i;
        fprintf(stderr, "segment type %d at %x\n", phdr->p_type, phdr->p_offset);
        if (phdr->p_type == PT_INTERP) {
            fprintf(stderr, "found interpreter (%s)\n",
                (char *) (contents + phdr->p_offset));
            interpOffset = freeOffset;
            interpSize = strlen(newInterpreter) + 1;
            freeOffset += roundUp(interpSize, 4);
            interpAddr = firstPage + interpOffset % 4096;
            phdr->p_offset = interpOffset;
            growFile(phdr->p_offset + interpSize);
            phdr->p_vaddr = phdr->p_paddr = interpAddr;
            phdr->p_filesz = phdr->p_memsz = interpSize;
            strncpy(contents + interpOffset,
                newInterpreter, interpSize);
        }
    }
    
    /* Rewrite the program header table. */
    hdr->e_phoff = freeOffset;
    freeOffset += hdr->e_phnum * sizeof(Elf32_Phdr);
    assert(phdrs[0].p_type == PT_PHDR);
    phdrs[0].p_offset = hdr->e_phoff;
    phdrs[0].p_vaddr = phdrs[0].p_paddr = firstPage + hdr->e_phoff % 4096;
    phdrs[0].p_filesz = phdrs[0].p_memsz = hdr->e_phnum * sizeof(Elf32_Phdr);
    memcpy(contents + hdr->e_phoff, phdrs, hdr->e_phnum * sizeof(Elf32_Phdr));

    /* Rewrite the section header table. */
    hdr->e_shoff = freeOffset;
    freeOffset += hdr->e_shnum * sizeof(Elf32_Shdr);
    memcpy(contents + hdr->e_shoff, shdrs, hdr->e_shnum * sizeof(Elf32_Shdr));

    if (freeOffset > 4096) error("ran out of space in page 0");
    
    writeFile("./new.exe");
}


int main(int argc, char * * argv)
{
    if (argc != 2) {
        fprintf(stderr, "syntax: %s FILENAME\n", argv[0]);
        return 1;
    }

    patchElf(argv[1]);

    return 0;
}
