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


static off_t fileSize, maxSize = 128 * 1024;
static unsigned char * contents = 0;


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


//char newInterpreter[] = "/lib/ld-linux.so.2";
char newInterpreter[] = "/nix/store/42de22963bca8f234ad54b01118215df-glibc-2.3.2/lib/ld-linux.so.2";


static void patchElf(char * fileName)
{
    fprintf(stderr, "patching %s\n", fileName);

    readFile(fileName);

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
        error("missing program header");
    
    if (hdr->e_shoff + hdr->e_shnum * hdr->e_shentsize > fileSize)
        error("missing program header");

    /* Find the PT_INTERP segment. */
    Elf32_Phdr * phdr = (Elf32_Phdr *) (contents + hdr->e_phoff);

    int i;
    for (i = 0; i < hdr->e_phnum; ++i, ++phdr) {
        fprintf(stderr, "segment type %d at %x\n", phdr->p_type, phdr->p_offset);
        if (phdr->p_type == PT_INTERP) {
            fprintf(stderr, "found interpreter (%s)\n",
                (char *) (contents + phdr->p_offset));
            unsigned int segLen = strlen(newInterpreter) + 1;
            phdr->p_offset = fileSize;
            growFile(phdr->p_offset + segLen);
            phdr->p_vaddr = phdr->p_paddr = 0x08048000 + phdr->p_offset;
            phdr->p_filesz = phdr->p_memsz = segLen;
            strncpy(contents + phdr->p_offset, newInterpreter, segLen);
        }
    }

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
