#include <string>
#include <vector>
#include <map>
#include <algorithm>

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


const unsigned int pageSize = 4096;


static string fileName;

static off_t fileSize, maxSize;
static unsigned char * contents = 0;
static Elf32_Ehdr * hdr;
static vector<Elf32_Phdr> phdrs;
static vector<Elf32_Shdr> shdrs;

static bool changed = false;

typedef string SectionName;
typedef map<SectionName, string> ReplacedSections;

static ReplacedSections replacedSections;

static string sectionNames; /* content of the .shstrtab section */


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


static void shiftFile(unsigned int extraPages, Elf32_Addr startPage)
{
    /* Move the entire contents of the file `extraPages' pages
       further. */
    unsigned int oldSize = fileSize;
    unsigned int shift = extraPages * pageSize;
    growFile(fileSize + extraPages * pageSize);
    memmove(contents + extraPages * pageSize, contents, oldSize);
    memset(contents + sizeof(Elf32_Ehdr), 0, shift - sizeof(Elf32_Ehdr));

    /* Adjust the ELF header. */
    hdr->e_phoff = sizeof(Elf32_Ehdr);
    hdr->e_shoff += shift;
    
    /* Update the offsets in the section headers. */
    for (int i = 0; i < hdr->e_shnum; ++i)
        shdrs[i].sh_offset += shift;
    
    /* Update the offsets in the program headers. */
    for (int i = 0; i < hdr->e_phnum; ++i)
        phdrs[i].p_offset += shift;

    /* Add a segment that maps the new program/section headers and
       PT_INTERP segment into memory.  Otherwise glibc will choke. */
    phdrs.resize(hdr->e_phnum + 1);
    hdr->e_phnum++;
    Elf32_Phdr & phdr = phdrs[hdr->e_phnum - 1];
    phdr.p_type = PT_LOAD;
    phdr.p_offset = 0;
    phdr.p_vaddr = phdr.p_paddr = startPage;
    phdr.p_filesz = phdr.p_memsz = shift;
    phdr.p_flags = PF_R;
    phdr.p_align = 4096;
}


static void checkPointer(void * p, unsigned int size)
{
    unsigned char * q = (unsigned char *) p;
    assert(q >= contents && q + size <= contents + fileSize);
}


static string getSectionName(const Elf32_Shdr & shdr)
{
    return string(sectionNames.c_str() + shdr.sh_name);
}


static Elf32_Shdr & findSection(const SectionName & sectionName)
{
    for (unsigned int i = 1; i < hdr->e_shnum; ++i)
        if (getSectionName(shdrs[i]) == sectionName) return shdrs[i];
    error("cannot find section");
}


static string & replaceSection(const SectionName & sectionName,
    unsigned int size)
{
    ReplacedSections::iterator i = replacedSections.find(sectionName);
    string s;
    
    if (i != replacedSections.end()) {
        s = string(i->second);
    } else {
        Elf32_Shdr & shdr = findSection(sectionName);
        s = string((char *) contents + shdr.sh_offset, shdr.sh_size);
    }
    
    s.resize(size);
    replacedSections[sectionName] = s;

    return replacedSections[sectionName];
}


static void rewriteSections()
{
    if (replacedSections.empty()) return;

    for (ReplacedSections::iterator i = replacedSections.begin();
         i != replacedSections.end(); ++i)
        fprintf(stderr, "replacing section `%s' with size `%d', content `%s'\n",
            i->first.c_str(), i->second.size(), i->second.c_str());

    
    /* What is the index of the last replaced section? */
    unsigned int lastReplaced = 0;
    for (unsigned int i = 1; i < hdr->e_shnum; ++i) {
        string sectionName = getSectionName(shdrs[i]);
        if (replacedSections.find(sectionName) != replacedSections.end()) {
            printf("using replaced section `%s'\n", sectionName.c_str());
            lastReplaced = i;
        }
    }

    assert(lastReplaced != 0);

    fprintf(stderr, "last replaced is %d\n", lastReplaced);
    
    /* Try to replace all section before that, as far as possible.
       Stop when we reach an irreplacable section (such as one of type
       SHT_PROGBITS).  These cannot be moved in virtual address space
       since that would invalidate absolute references to them. */
    assert(lastReplaced + 1 < shdrs.size()); /* !!! I'm lazy. */
    off_t startOffset = shdrs[lastReplaced + 1].sh_offset;
    Elf32_Addr startAddr = shdrs[lastReplaced + 1].sh_addr;
    for (unsigned int i = 1; i <= lastReplaced; ++i) {
        Elf32_Shdr & shdr(shdrs[i]);
        string sectionName = getSectionName(shdr);
        fprintf(stderr, "looking at section `%s'\n", sectionName.c_str());
        if (replacedSections.find(sectionName) != replacedSections.end()) continue;
        if (shdr.sh_type == SHT_PROGBITS && sectionName != ".interp") {
            startOffset = shdr.sh_offset;
            startAddr = shdr.sh_addr;
            lastReplaced = i - 1;
            break;
        } else {
            fprintf(stderr, "replacing section `%s' which is in the way\n", sectionName.c_str());
            replaceSection(sectionName, shdr.sh_size);
        }
    }

    fprintf(stderr, "first reserved offset/addr is %d/0x%x\n",
        startOffset, startAddr);
    Elf32_Addr startPage = startAddr / pageSize * pageSize;

    /* Right now we assume that the section headers are somewhere near
       the end, which appears to be the case most of the time.
       Therefore its not accidentally overwritten by the replaced
       sections. !!!  Fix this. */
    assert(hdr->e_shoff >= startOffset);

    
    /* Compute the total space needed for the replaced sections, the
       ELF header, and the program headers. */
    off_t neededSpace = sizeof(Elf32_Ehdr) + phdrs.size() * sizeof(Elf32_Phdr);
    for (ReplacedSections::iterator i = replacedSections.begin();
         i != replacedSections.end(); ++i)
        neededSpace += roundUp(i->second.size(), 4);

    fprintf(stderr, "needed space is %d\n", neededSpace);

    /* If we need more space at the start of the file, then grow the
       file by the minimum number of pages and adjust internal
       offsets. */
    if (neededSpace > startOffset) {

        /* We also need an additional program header, so adjust for that. */
        if (neededSpace > startOffset) neededSpace += sizeof(Elf32_Phdr);
        fprintf(stderr, "needed space is %d\n", neededSpace);
        
        unsigned int neededPages = roundUp(neededSpace - startOffset, pageSize) / pageSize;
        fprintf(stderr, "needed pages is %d\n", neededPages);
        if (neededPages * pageSize > startPage)
            error("virtual address space underrun!");
        startPage -= neededPages * pageSize;

        shiftFile(neededPages, startPage);
    }


    /* Write out the replaced sections. */
    Elf32_Off curOff = sizeof(Elf32_Ehdr) + phdrs.size() * sizeof(Elf32_Phdr);
    for (ReplacedSections::iterator i = replacedSections.begin();
         i != replacedSections.end(); ++i)
    {
        fprintf(stderr, "rewriting section `%s' to offset %d\n",
            i->first.c_str(), curOff);
        memcpy(contents + curOff, (unsigned char *) i->second.c_str(),
            i->second.size());

        /* Update the section header for this section. */
        Elf32_Shdr & shdr = findSection(i->first);
        shdr.sh_offset = curOff;
        shdr.sh_addr = startPage + curOff;
        shdr.sh_size = i->second.size();
        shdr.sh_addralign = 4;

        /* If this is the .interp section, then the PT_INTERP segment
           has to be synced with it. */
        for (int j = 0; j < phdrs.size(); ++j)
            if (phdrs[j].p_type == PT_INTERP) {
                phdrs[j].p_offset = shdr.sh_offset;
                phdrs[j].p_vaddr = phdrs[j].p_paddr = shdr.sh_addr;
                phdrs[j].p_filesz = phdrs[j].p_memsz = shdr.sh_size;
            }
            
        curOff += roundUp(i->second.size(), 4);
    }

    assert(curOff == neededSpace);


    /* Rewrite the program header table. */

    /* If the is a segment for the program header table, update it.
       (According to the ELF spec, it must be the first entry.) */
    if (phdrs[0].p_type == PT_PHDR) {
        phdrs[0].p_offset = hdr->e_phoff;
        phdrs[0].p_vaddr = phdrs[0].p_paddr = startPage + hdr->e_phoff;
        phdrs[0].p_filesz = phdrs[0].p_memsz = phdrs.size() * sizeof(Elf32_Phdr);
    }

    for (int i = 0; i < phdrs.size(); ++i)
        * ((Elf32_Phdr *) (contents + hdr->e_phoff) + i) = phdrs[i];

    /* Rewrite the section header table. */
    assert(hdr->e_shnum == shdrs.size());
    for (int i = 1; i < hdr->e_shnum; ++i)
        * ((Elf32_Shdr *) (contents + hdr->e_shoff) + i) = shdrs[i];
}


static void setSubstr(string & s, unsigned int pos, const string & t)
{
    assert(pos + t.size() <= s.size());
    copy(t.begin(), t.end(), s.begin() + pos);
}


static void setInterpreter(const string & newInterpreter)
{
    string & section = replaceSection(".interp", newInterpreter.size() + 1);
    setSubstr(section, 0, newInterpreter + '\0');
    changed = true;
}


#if 0
static void setInterpreter()
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


static void shrinkRPath()
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
#endif


static void parseElf()
{
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

    /* Get the section header string table section (".shstrtab").  Its
       index in the section header table is given by e_shstrndx field
       of the ELF header. */
    unsigned int shstrtabIndex = hdr->e_shstrndx;
    assert(shstrtabIndex < shdrs.size());
    unsigned int shstrtabSize = shdrs[shstrtabIndex].sh_size;
    char * shstrtab = (char * ) contents + shdrs[shstrtabIndex].sh_offset;
    checkPointer(shstrtab, shstrtabSize);

    assert(shstrtabSize > 0);
    assert(shstrtab[shstrtabSize - 1] == 0);

    sectionNames = string(shstrtab, shstrtabSize);
}


static string newInterpreter;

static bool doShrinkRPath = false;
static bool printRPath = false;
static bool printInterpreter = false;


static void patchElf()
{
    if (!printInterpreter && !printRPath)
        fprintf(stderr, "patching ELF file `%s'\n", fileName.c_str());

    mode_t fileMode;
    
    readFile(fileName, &fileMode);

    parseElf();


    if (printInterpreter) {
        Elf32_Shdr & shdr = findSection(".interp");
        string interpreter((char *) contents + shdr.sh_offset, shdr.sh_size);
        printf("%s\n", interpreter.c_str());
    }
    
    if (newInterpreter != "")
        setInterpreter(newInterpreter);

    
    if (changed){
        rewriteSections();

        writeFile(fileName, fileMode);
    }
    
#if 0    
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
        hdr->e_shoff = freeOffset;
        freeOffset += hdr->e_shnum * sizeof(Elf32_Shdr);
        for (int i = 0; i < hdr->e_shnum; ++i)
            * ((Elf32_Shdr *) (contents + hdr->e_shoff) + i) = shdrs[i];

        if (freeOffset > 4096) error("ran out of space in page 0");
    }
#endif
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
