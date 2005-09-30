#include <string>
#include <vector>

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

using namespace std;


static string fileName;
static string newInterpreter;

static bool doShrinkRPath = false;
static bool printRPath = false;
static bool printInterpreter = false;


static off_t fileSize, maxSize;
static unsigned char * contents = 0;
static Elf32_Ehdr * hdr;
static vector<Elf32_Phdr> phdrs;
static vector<Elf32_Shdr> shdrs;
static unsigned int freeOffset;
static unsigned int firstPage;

static bool changed = false;
static bool rewriteHeaders = false;


static void error(string msg)
{
    if (errno) perror(msg.c_str()); else printf("%s\n", msg.c_str());
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


static void readFile(string fileName, mode_t * fileMode)
{
    struct stat st;
    if (stat(fileName.c_str(), &st) != 0) error("stat");
    fileSize = st.st_size;
    *fileMode = st.st_mode;
    maxSize = fileSize + 128 * 1024;
    
    contents = (unsigned char *) malloc(fileSize + maxSize);
    if (!contents) abort();

    int fd = open(fileName.c_str(), O_RDONLY);
    if (fd == -1) error("open");

    if (read(fd, contents, fileSize) != fileSize) error("read");
    
    close(fd);
}


static void writeFile(string fileName, mode_t fileMode)
{
    string fileName2 = fileName + "_patchelf_tmp";
    
    int fd = open(fileName2.c_str(),
        O_CREAT | O_TRUNC | O_WRONLY, 0700);
    if (fd == -1) error("open");

    if (write(fd, contents, fileSize) != fileSize) error("write");
    
    if (close(fd) != 0) error("close");

    if (chmod(fileName2.c_str(), fileMode) != 0) error("chmod");

    if (rename(fileName2.c_str(), fileName.c_str()) != 0) error("rename");
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
    phdrs.resize(hdr->e_phnum + 1);
    for (i = hdr->e_phnum; i > 1; --i)
        phdrs[i] = phdrs[i - 1];
    hdr->e_phnum++;
    Elf32_Phdr & phdr = phdrs[1];
    phdr.p_type = PT_LOAD;
    phdr.p_offset = 0;
    phdr.p_vaddr = phdr.p_paddr = firstPage;
    phdr.p_filesz = phdr.p_memsz = 4096;
    phdr.p_flags = PF_R;
    phdr.p_align = 4096;

    freeOffset = sizeof(Elf32_Ehdr);

    rewriteHeaders = true;
}


static void setInterpreter(void)
{
    /* Find the PT_INTERP segment and replace it by a new one that
       contains the new interpreter name. */
    if ((newInterpreter != "" || printInterpreter) && hdr->e_type == ET_EXEC) {
        shiftFile();
        int i;
        for (i = 0; i < hdr->e_phnum; ++i) {
            Elf32_Phdr & phdr = phdrs[i];
            if (phdr.p_type == PT_INTERP) {
                if (printInterpreter) {
                    printf("%s\n", (char *) (contents + phdr.p_offset));
                    exit(0);
                }
                fprintf(stderr, "changing interpreter from `%s' to `%s'\n",
                    (char *) (contents + phdr.p_offset), newInterpreter.c_str());
                unsigned int interpOffset = freeOffset;
                unsigned int interpSize = newInterpreter.size() + 1;
                freeOffset += roundUp(interpSize, 4);
                phdr.p_offset = interpOffset;
                growFile(phdr.p_offset + interpSize);
                phdr.p_vaddr = phdr.p_paddr = firstPage + interpOffset % 4096;
                phdr.p_filesz = phdr.p_memsz = interpSize;
                strncpy((char *) contents + interpOffset,
                    newInterpreter.c_str(), interpSize);
                changed = true;
                break;
            }
        }
    }
}


static void concatToRPath(string & rpath, const string & path)
{
    if (!rpath.empty()) rpath += ":";
    rpath += path;
}


static void shrinkRPath(void)
{
    /* Shrink the RPATH. */
    if (doShrinkRPath || printRPath) {

        static vector<string> neededLibs;
        
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
                strTab = (char *) contents +
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
            else if (dyn->d_tag == DT_NEEDED)
                neededLibs.push_back(string(strTab + dyn->d_un.d_val));
        }

        if (printRPath) {
            printf("%s\n", rpath ? rpath : "");
            exit(0);
        }
        
        if (!rpath) {
            fprintf(stderr, "no RPATH to shrink\n");
            return;
        }

        /* For each directory in the RPATH, check if it contains any
           needed library. */
        static vector<bool> neededLibFound(neededLibs.size(), false);

        string newRPath;

        char * pos = rpath;
        while (*pos) {
            char * end = strchr(pos, ':');
            if (!end) end = strchr(pos, 0);

            /* Get the name of the directory. */
            string dirName(pos, end - pos);
            if (*end == ':') ++end;
            pos = end;

            /* Non-absolute entries are allowed (e.g., the special
               "$ORIGIN" hack). */
            if (dirName[0] != '/') {
                concatToRPath(newRPath, dirName);
                continue;
            }

            /* For each library that we haven't found yet, see if it
               exists in this directory. */
            int j;
            bool libFound = false;
            for (j = 0; j < neededLibs.size(); ++j)
                if (!neededLibFound[j]) {
                    string libName = dirName + "/" + neededLibs[j];
                    struct stat st;
                    if (stat(libName.c_str(), &st) == 0) {
                        neededLibFound[j] = true;
                        libFound = true;
                    }
                }

            if (!libFound)
                fprintf(stderr, "removing directory `%s' from RPATH\n", dirName.c_str());
            else
                concatToRPath(newRPath, dirName);
        }

        if (string(rpath) != newRPath) {
            assert(newRPath.size() <= strlen(rpath));
            /* Zero out the previous rpath to prevent retained
               dependencies in Nix. */
            memset(rpath, 0, strlen(rpath));
            strcpy(rpath, newRPath.c_str());
            changed = true;
        }
    }
}


static void patchElf(void)
{
    if (!printInterpreter && !printRPath)
        fprintf(stderr, "patching ELF file `%s'\n", fileName.c_str());

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
    for (int i = 0; i < hdr->e_phnum; ++i)
        phdrs.push_back(* ((Elf32_Phdr *) (contents + hdr->e_phoff) + i));
    
    for (int i = 0; i < hdr->e_shnum; ++i)
        shdrs.push_back(* ((Elf32_Shdr *) (contents + hdr->e_shoff) + i));

    /* Find the next free virtual address page so that we can add
       segments without messing up other segments. */
    int i;
    unsigned int nextFreePage = 0;
    for (i = 0; i < hdr->e_phnum; ++i) {
        Elf32_Phdr & phdr = phdrs[i];
        unsigned int end = roundUp(phdr.p_vaddr + phdr.p_memsz, 4096);
        if (end > nextFreePage) nextFreePage = end;
    }

    firstPage = 0x08047000;

    /* Do what we're supposed to do. */
    setInterpreter();
    shrinkRPath();

    assert(!printInterpreter && !printRPath);
    
    if (rewriteHeaders) {
        /* Rewrite the program header table. */
        hdr->e_phoff = freeOffset;
        freeOffset += hdr->e_phnum * sizeof(Elf32_Phdr);
        assert(phdrs[0].p_type == PT_PHDR);
        phdrs[0].p_offset = hdr->e_phoff;
        phdrs[0].p_vaddr = phdrs[0].p_paddr = firstPage + hdr->e_phoff % 4096;
        phdrs[0].p_filesz = phdrs[0].p_memsz = hdr->e_phnum * sizeof(Elf32_Phdr);
        for (int i = 0; i < hdr->e_phnum; ++i)
            * ((Elf32_Phdr *) (contents + hdr->e_phoff) + i) = phdrs[i];

        /* Rewrite the section header table. */
        hdr->e_shoff = freeOffset;
        freeOffset += hdr->e_shnum * sizeof(Elf32_Shdr);
        for (int i = 0; i < hdr->e_shnum; ++i)
            * ((Elf32_Shdr *) (contents + hdr->e_shoff) + i) = shdrs[i];

        if (freeOffset > 4096) error("ran out of space in page 0");
    }

    if (changed)
        writeFile(fileName, fileMode);
    else
        fprintf(stderr, "nothing changed in `%s'\n", fileName.c_str());
}


int main(int argc, char * * argv)
{
    if (argc <= 1) {
        fprintf(stderr, "syntax: %s\n\
  [--interpreter FILENAME]\n\
  [--print-interpreter]\n\
  [--shrink-rpath]\n\
  [--print-rpath]\n\
  FILENAME\n", argv[0]);
        return 1;
    }

    int i;
    for (i = 1; i < argc; ++i) {
        string arg(argv[i]);
        if (arg == "--interpreter") {
            if (++i == argc) error("missing argument");
            newInterpreter = argv[i];
        }
        else if (arg == "--print-interpreter") {
            printInterpreter = true;
        }
        else if (arg == "--shrink-rpath") {
            doShrinkRPath = true;
        }
        else if (arg == "--print-rpath") {
            printRPath = true;
        }
        else break;
    }

    if (i == argc) error("missing filename");
    fileName = argv[i];

    patchElf();

    return 0;
}
