#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
#include <string.h>
#include <errno.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <limits.h>

#include <elf.h>


static char * fileName = 0;
static char * newInterpreter = 0;
static int doShrinkRPath = 0;


#define MAX_PHEADERS 128
#define MAX_SHEADERS 128
#define MAX_NEEDED 1024


static off_t fileSize, maxSize;
static unsigned char * contents = 0;
static Elf32_Ehdr * hdr;
static Elf32_Phdr phdrs[MAX_PHEADERS];
static Elf32_Shdr shdrs[MAX_SHEADERS];
static unsigned int nrNeededLibs = 0;
static char * neededLibs[MAX_NEEDED];
static int neededLibFound[MAX_NEEDED];
static unsigned int freeOffset;
static unsigned int firstPage;

static int changed = 0;
static int rewriteHeaders = 0;


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


static void readFile(char * fileName, mode_t * fileMode)
{
    struct stat st;
    if (stat(fileName, &st) != 0) error("stat");
    fileSize = st.st_size;
    *fileMode = st.st_mode;
    maxSize = fileSize + 128 * 1024;
    
    contents = malloc(fileSize + maxSize);
    if (!contents) abort();

    int fd = open(fileName, O_RDONLY);
    if (fd == -1) error("open");

    if (read(fd, contents, fileSize) != fileSize) error("read");
    
    close(fd);
}


static void writeFile(char * fileName, mode_t fileMode)
{
    char fileName2[PATH_MAX];
    if (snprintf(fileName2, sizeof(fileName2),
            "%s_patchelf_tmp", fileName) >= sizeof(fileName2))
        error("file name too long");
    
    int fd = open(fileName2, O_CREAT | O_TRUNC | O_WRONLY, 0700);
    if (fd == -1) error("open");

    if (write(fd, contents, fileSize) != fileSize) error("write");
    
    if (close(fd) != 0) error("close");

    if (chmod(fileName2, fileMode) != 0) error("chmod");

    if (rename(fileName2, fileName) != 0) error("rename");
}


static unsigned int roundUp(unsigned int n, unsigned int m)
{
    return ((n - 1) / m + 1) * m;
}


static void shiftFile(void)
{
    /* Move the entire contents of the file one page further. */
    unsigned int oldSize = fileSize;
    growFile(fileSize + 4096);
    memmove(contents + 4096, contents, oldSize);
    memset(contents + sizeof(Elf32_Ehdr), 0, 4096 - sizeof(Elf32_Ehdr));

    /* Update the ELF header. */
    hdr->e_shoff += 4096;

    /* Update the offsets in the section headers. */
    int i;
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

    freeOffset = sizeof(Elf32_Ehdr);

    rewriteHeaders = 1;
}


static void setInterpreter(void)
{
    /* Find the PT_INTERP segment and replace it by a new one that
       contains the new interpreter name. */
    if (newInterpreter && hdr->e_type == ET_EXEC) {
        shiftFile();
        int i;
        for (i = 0; i < hdr->e_phnum; ++i) {
            Elf32_Phdr * phdr = phdrs + i;
            if (phdr->p_type == PT_INTERP) {
                fprintf(stderr, "changing interpreter from `%s' to `%s'\n",
                    (char *) (contents + phdr->p_offset), newInterpreter);
                unsigned int interpOffset = freeOffset;
                unsigned int interpSize = strlen(newInterpreter) + 1;
                freeOffset += roundUp(interpSize, 4);
                phdr->p_offset = interpOffset;
                growFile(phdr->p_offset + interpSize);
                phdr->p_vaddr = phdr->p_paddr = firstPage + interpOffset % 4096;
                phdr->p_filesz = phdr->p_memsz = interpSize;
                strncpy(contents + interpOffset,
                    newInterpreter, interpSize);
                changed = 1;
                break;
            }
        }
    }
}


static void concat(char * dst, char * src)
{
    if (*dst) strcat(dst, ":");
    strcat(dst, src);
}


static void shrinkRPath(void)
{
    /* Shrink the RPATH. */
    if (doShrinkRPath) {

        /* Find the .dynamic section. */
        int i, dynSec = 0;
        for (i = 0; i < hdr->e_shnum; ++i)
            if (shdrs[i].sh_type == SHT_DYNAMIC) dynSec = i;
        
        if (!dynSec) {
            fprintf(stderr, "no dynamic section, so no RPATH to shrink\n");
            return;
        }

        /* Find the DT_STRTAB entry in the dynamic section. */
        Elf32_Dyn * dyn = (Elf32_Dyn *) (contents + shdrs[dynSec].sh_offset);
        Elf32_Addr strTabAddr = 0;
        for ( ; dyn->d_tag != DT_NULL; dyn++)
            if (dyn->d_tag == DT_STRTAB) strTabAddr = dyn->d_un.d_ptr;

        if (!strTabAddr) {
            fprintf(stderr, "strange: no string table\n");
            return;
        }

        /* Nasty: map the virtual address for the string table back to
           a offset in the file. */
        char * strTab = 0;
        for (i = 0; i < hdr->e_phnum; ++i)
            if (phdrs[i].p_vaddr <= strTabAddr &&
                strTabAddr < phdrs[i].p_vaddr + phdrs[i].p_filesz)
            {
                strTab = contents +
                    strTabAddr - phdrs[i].p_vaddr + phdrs[i].p_offset;
            }

        if (!strTab) error("could not reverse map DT_STRTAB");

        /* Walk through the dynamic section, look for the RPATH
           entry. */
        dyn = (Elf32_Dyn *) (contents + shdrs[dynSec].sh_offset);
        Elf32_Dyn * rpathEntry = 0;
        char * rpath = 0;
        for ( ; dyn->d_tag != DT_NULL; dyn++) {
            if (dyn->d_tag == DT_RPATH) {
                rpathEntry = dyn;
                rpath = strTab + dyn->d_un.d_val;
            }
            else if (dyn->d_tag == DT_NEEDED) {
                if (nrNeededLibs == MAX_NEEDED)
                    error("too many needed libraries");
                neededLibs[nrNeededLibs++] = strTab + dyn->d_un.d_val;
            }
        }

        if (!rpath) {
            fprintf(stderr, "no RPATH to shrink\n");
            return;
        }

        /* For each directory in the RPATH, check if it contains any
           needed library. */
        for (i = 0; i < nrNeededLibs; ++i)
            neededLibFound[i] = 0;

        char * newRPath = malloc(strlen(rpath) + 1);
        *newRPath = 0;

        char * pos = rpath;
        while (*pos) {
            char * end = strchr(pos, ':');
            if (!end) end = strchr(pos, 0);

            /* Get the name of the directory. */
            char dirName[PATH_MAX];
            if (end - pos >= PATH_MAX) error("library name too long");
            strncpy(dirName, pos, end - pos);
            dirName[end - pos] = 0;
            if (*end == ':') ++end;
            pos = end;

            /* Non-absolute entries are allowed (e.g., the special
               "$ORIGIN" hack). */
            if (*dirName != '/') {
                concat(newRPath, dirName);
                continue;
            }

            /* For each library that we haven't found yet, see if it
               exists in this directory. */
            int j;
            int libFound = 0;
            for (j = 0; j < nrNeededLibs; ++j)
                if (!neededLibFound[j]) {
                    char libName[PATH_MAX];
                    if (snprintf(libName, sizeof(libName), "%s/%s", dirName, neededLibs[j])
                        >= sizeof(libName))
                        error("file name too long");
                    struct stat st;
                    if (stat(libName, &st) == 0) {
                        neededLibFound[j] = 1;
                        libFound = 1;
                    }
                }

            if (!libFound)
                fprintf(stderr, "removing directory `%s' from RPATH\n", dirName);
            else
                concat(newRPath, dirName);
        }

        if (strcmp(rpath, newRPath) != 0) {
            assert(strlen(newRPath) <= strlen(rpath));
            /* Zero out the previous rpath to prevent retained
               dependencies in Nix. */
            memset(rpath, 0, strlen(rpath));
            strcpy(rpath, newRPath);
            changed = 1;
        }
    }
}


static void patchElf(void)
{
    fprintf(stderr, "patching ELF file `%s'\n", fileName);

    mode_t fileMode;
    
    readFile(fileName, &fileMode);

    /* Check the ELF header for basic validity. */
    if (fileSize < sizeof(Elf32_Ehdr)) error("missing ELF header");

    hdr = (Elf32_Ehdr *) contents;

    if (memcmp(hdr->e_ident, ELFMAG, 4) != 0)
        error("not an ELF executable");

    if (contents[EI_CLASS] != ELFCLASS32 ||
        contents[EI_DATA] != ELFDATA2LSB ||
        contents[EI_VERSION] != EV_CURRENT)
        error("ELF executable is not 32-bit, little-endian, version 1");

    if (hdr->e_type != ET_EXEC && hdr->e_type != ET_DYN)
        error("wrong ELF type");
    
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

    firstPage = 0x08047000;

    /* Do what we're supposed to do. */
    setInterpreter();
    shrinkRPath();

    if (rewriteHeaders) {
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
    }

    if (changed)
        writeFile(fileName, fileMode);
    else
        fprintf(stderr, "nothing changed in `%s'\n", fileName);
}


int main(int argc, char * * argv)
{
    if (argc <= 1) {
        fprintf(stderr, "syntax: %s [--interpreter FILENAME] [--shrink-rpath] FILENAME\n", argv[0]);
        return 1;
    }

    int i;
    for (i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--interpreter") == 0) {
            if (++i == argc) error("missing argument");
            newInterpreter = argv[i];
        }
        else if (strcmp(argv[i], "--shrink-rpath") == 0) {
            doShrinkRPath = 1;
        }
        else break;
    }

    if (i == argc) error("missing filename");
    fileName = argv[i];
    
    patchElf();

    return 0;
}
