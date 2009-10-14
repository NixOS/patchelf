#include <string>
#include <vector>
#include <map>
#include <algorithm>

#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <assert.h>
#include <string.h>
#include <errno.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <limits.h>

#include "elf.h"

using namespace std;


const unsigned int pageSize = 4096;


static bool debugMode = false;

static bool forceRPath = false;

static string fileName;


off_t fileSize, maxSize;
unsigned char * contents = 0;


#define ElfFileParams class Elf_Ehdr, class Elf_Phdr, class Elf_Shdr, class Elf_Addr, class Elf_Off, class Elf_Dyn
#define ElfFileParamNames Elf_Ehdr, Elf_Phdr, Elf_Shdr, Elf_Addr, Elf_Off, Elf_Dyn


template<ElfFileParams>
class ElfFile
{
    Elf_Ehdr * hdr;
    vector<Elf_Phdr> phdrs;
    vector<Elf_Shdr> shdrs;

    bool littleEndian;

    bool changed;

    typedef string SectionName;
    typedef map<SectionName, string> ReplacedSections;

    ReplacedSections replacedSections;

    string sectionNames; /* content of the .shstrtab section */

    /* Align on 4 or 8 bytes boundaries on 32- or 64-bit platforms
       respectively. */
    unsigned int sectionAlignment;

public:

    ElfFile() 
    {
        changed = false;
        sectionAlignment = sizeof(Elf_Off);
    }

    bool isChanged()
    {
        return changed;
    }
    
    void parse();

private:

    struct CompPhdr
    {
        ElfFile * elfFile;
        bool operator ()(const Elf_Phdr & x, const Elf_Phdr & y)
        {
            if (x.p_type == PT_PHDR) return true;
            if (y.p_type == PT_PHDR) return false;
            return elfFile->rdi(x.p_paddr) < elfFile->rdi(y.p_paddr);
        }
    };

    friend struct CompPhdr;

    void sortPhdrs();

    struct CompShdr 
    {
        ElfFile * elfFile;
        bool operator ()(const Elf_Shdr & x, const Elf_Shdr & y)
        {
            return elfFile->rdi(x.sh_offset) < elfFile->rdi(y.sh_offset);
        }
    };
    
    friend struct CompShdr;

    void sortShdrs();

    void shiftFile(unsigned int extraPages, Elf_Addr startPage);

    string getSectionName(const Elf_Shdr & shdr);

    Elf_Shdr & findSection(const SectionName & sectionName);
    
    Elf_Shdr * findSection2(const SectionName & sectionName);

    unsigned int findSection3(const SectionName & sectionName);

    string & replaceSection(const SectionName & sectionName,
        unsigned int size);

    void writeReplacedSections(Elf_Off & curOff,
        Elf_Addr startAddr, Elf_Off startOffset);
    
    void rewriteHeaders(Elf_Addr phdrAddress);

    void rewriteSectionsLibrary();
    
    void rewriteSectionsExecutable();

public:

    void rewriteSections();

    string getInterpreter();

    void setInterpreter(const string & newInterpreter);

    typedef enum { rpPrint, rpShrink, rpSet } RPathOp;

    void modifyRPath(RPathOp op, string newRPath);

private:
    
    /* Convert an integer in big or little endian representation (as
       specified by the ELF header) to this platform's integer
       representation. */
    template<class I>
    I rdi(I i);

    /* Convert back to the ELF representation. */
    template<class I>
    I wri(I & t, unsigned long long i) 
    {
	t = rdi(i);
        return i;
    }
};


/* !!! G++ creates broken code if this function is inlined, don't know
   why... */
template<ElfFileParams>
template<class I>
I ElfFile<ElfFileParamNames>::rdi(I i) 
{
    I r = 0;
    if (littleEndian) {
        for (unsigned int n = 0; n < sizeof(I); ++n) {
            r |= ((I) *(((unsigned char *) &i) + n)) << (n * 8);
        }
    } else {
        for (unsigned int n = 0; n < sizeof(I); ++n) {
            r |= ((I) *(((unsigned char *) &i) + n)) << ((sizeof(I) - n - 1) * 8);
        }
    }
    return r;
}


/* Ugly: used to erase DT_RUNPATH when using --force-rpath. */
#define DT_IGNORE       0x00726e67


static void debug(const char * format, ...)
{
    if (debugMode) {
        va_list ap;
        va_start(ap, format);
        vfprintf(stderr, format, ap);
        va_end(ap);
    }
}


static void error(string msg)
{
    if (errno) perror(msg.c_str()); else fprintf(stderr, "%s\n", msg.c_str());
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
    maxSize = fileSize + 8 * 1024 * 1024;
    
    contents = (unsigned char *) malloc(fileSize + maxSize);
    if (!contents) abort();

    int fd = open(fileName.c_str(), O_RDONLY);
    if (fd == -1) error("open");

    if (read(fd, contents, fileSize) != fileSize) error("read");
    
    close(fd);
}


static void checkPointer(void * p, unsigned int size)
{
    unsigned char * q = (unsigned char *) p;
    assert(q >= contents && q + size <= contents + fileSize);
}


template<ElfFileParams>
void ElfFile<ElfFileParamNames>::parse()
{
    /* Check the ELF header for basic validity. */
    if (fileSize < (off_t) sizeof(Elf_Ehdr)) error("missing ELF header");

    hdr = (Elf_Ehdr *) contents;

    if (memcmp(hdr->e_ident, ELFMAG, SELFMAG) != 0)
        error("not an ELF executable");

    littleEndian = contents[EI_DATA] == ELFDATA2LSB;
    
    if (rdi(hdr->e_type) != ET_EXEC && rdi(hdr->e_type) != ET_DYN)
        error("wrong ELF type");

    if ((off_t) (rdi(hdr->e_phoff) + rdi(hdr->e_phnum) * rdi(hdr->e_phentsize)) > fileSize)
        error("missing program headers");
    
    if ((off_t) (rdi(hdr->e_shoff) + rdi(hdr->e_shnum) * rdi(hdr->e_shentsize)) > fileSize)
        error("missing section headers");

    if (rdi(hdr->e_phentsize) != sizeof(Elf_Phdr))
        error("program headers have wrong size");

    /* Copy the program and section headers. */
    for (int i = 0; i < rdi(hdr->e_phnum); ++i)
        phdrs.push_back(* ((Elf_Phdr *) (contents + rdi(hdr->e_phoff)) + i));
    
    for (int i = 0; i < rdi(hdr->e_shnum); ++i)
        shdrs.push_back(* ((Elf_Shdr *) (contents + rdi(hdr->e_shoff)) + i));

    /* Get the section header string table section (".shstrtab").  Its
       index in the section header table is given by e_shstrndx field
       of the ELF header. */
    unsigned int shstrtabIndex = rdi(hdr->e_shstrndx);
    assert(shstrtabIndex < shdrs.size());
    unsigned int shstrtabSize = rdi(shdrs[shstrtabIndex].sh_size);
    char * shstrtab = (char * ) contents + rdi(shdrs[shstrtabIndex].sh_offset);
    checkPointer(shstrtab, shstrtabSize);

    assert(shstrtabSize > 0);
    assert(shstrtab[shstrtabSize - 1] == 0);

    sectionNames = string(shstrtab, shstrtabSize);
}


template<ElfFileParams>
void ElfFile<ElfFileParamNames>::sortPhdrs()
{
    /* Sort the segments by offset. */
    CompPhdr comp;
    comp.elfFile = this;
    sort(phdrs.begin(), phdrs.end(), comp);
}


template<ElfFileParams>
void ElfFile<ElfFileParamNames>::sortShdrs()
{
    /* Translate sh_link mappings to section names, since sorting the
       sections will invalidate the sh_link fields. */
    map<SectionName, SectionName> linkage;
    for (unsigned int i = 1; i < rdi(hdr->e_shnum); ++i)
        if (rdi(shdrs[i].sh_link) != 0)
            linkage[getSectionName(shdrs[i])] = getSectionName(shdrs[rdi(shdrs[i].sh_link)]);

    /* Idem for sh_info on certain sections. */
    map<SectionName, SectionName> info;
    for (unsigned int i = 1; i < rdi(hdr->e_shnum); ++i)
        if (rdi(shdrs[i].sh_info) != 0 &&
            (rdi(shdrs[i].sh_type) == SHT_REL || rdi(shdrs[i].sh_type) == SHT_RELA))
            info[getSectionName(shdrs[i])] = getSectionName(shdrs[rdi(shdrs[i].sh_info)]);

    /* Idem for the index of the .shstrtab section in the ELF header. */
    SectionName shstrtabName = getSectionName(shdrs[rdi(hdr->e_shstrndx)]);
    
    /* Sort the sections by offset. */
    CompShdr comp;
    comp.elfFile = this;
    sort(shdrs.begin(), shdrs.end(), comp);

    /* Restore the sh_link mappings. */
    for (unsigned int i = 1; i < rdi(hdr->e_shnum); ++i)
        if (rdi(shdrs[i].sh_link) != 0)
            wri(shdrs[i].sh_link,
                findSection3(linkage[getSectionName(shdrs[i])]));

    /* And the st_info mappings. */
    for (unsigned int i = 1; i < rdi(hdr->e_shnum); ++i)
        if (rdi(shdrs[i].sh_info) != 0 &&
            (rdi(shdrs[i].sh_type) == SHT_REL || rdi(shdrs[i].sh_type) == SHT_RELA))
            wri(shdrs[i].sh_info,
                findSection3(info[getSectionName(shdrs[i])]));

    /* And the .shstrtab index. */
    wri(hdr->e_shstrndx, findSection3(shstrtabName));
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


template<ElfFileParams>
void ElfFile<ElfFileParamNames>::shiftFile(unsigned int extraPages, Elf_Addr startPage)
{
    /* Move the entire contents of the file `extraPages' pages
       further. */
    unsigned int oldSize = fileSize;
    unsigned int shift = extraPages * pageSize;
    growFile(fileSize + extraPages * pageSize);
    memmove(contents + extraPages * pageSize, contents, oldSize);
    memset(contents + sizeof(Elf_Ehdr), 0, shift - sizeof(Elf_Ehdr));

    /* Adjust the ELF header. */
    wri(hdr->e_phoff, sizeof(Elf_Ehdr));
    wri(hdr->e_shoff, rdi(hdr->e_shoff) + shift);
    
    /* Update the offsets in the section headers. */
    for (int i = 1; i < rdi(hdr->e_shnum); ++i)
        wri(shdrs[i].sh_offset, rdi(shdrs[i].sh_offset) + shift);
    
    /* Update the offsets in the program headers. */
    for (int i = 0; i < rdi(hdr->e_phnum); ++i) {
        wri(phdrs[i].p_offset, rdi(phdrs[i].p_offset) + shift);
        if ((phdrs[i].p_vaddr - phdrs[i].p_offset) % phdrs[i].p_align != 0) {
            debug("changing alignment of program header %d from %d to %d\n", i,
                phdrs[i].p_align, pageSize);
            phdrs[i].p_align = pageSize;
        }
    }

    /* Add a segment that maps the new program/section headers and
       PT_INTERP segment into memory.  Otherwise glibc will choke. */
    phdrs.resize(rdi(hdr->e_phnum) + 1);
    wri(hdr->e_phnum, rdi(hdr->e_phnum) + 1);
    Elf_Phdr & phdr = phdrs[rdi(hdr->e_phnum) - 1];
    wri(phdr.p_type, PT_LOAD);
    wri(phdr.p_offset, 0);
    wri(phdr.p_vaddr, wri(phdr.p_paddr, startPage));
    wri(phdr.p_filesz, wri(phdr.p_memsz, shift)); 
    wri(phdr.p_flags, PF_R | PF_W);
    wri(phdr.p_align, 4096);
}


template<ElfFileParams>
string ElfFile<ElfFileParamNames>::getSectionName(const Elf_Shdr & shdr)
{
    return string(sectionNames.c_str() + rdi(shdr.sh_name));
}


template<ElfFileParams>
Elf_Shdr & ElfFile<ElfFileParamNames>::findSection(const SectionName & sectionName)
{
    Elf_Shdr * shdr = findSection2(sectionName);
    if (!shdr)
        error("cannot find section " + sectionName);
    return *shdr;
}


template<ElfFileParams>
Elf_Shdr * ElfFile<ElfFileParamNames>::findSection2(const SectionName & sectionName)
{
    unsigned int i = findSection3(sectionName);
    return i ? &shdrs[i] : 0;
}


template<ElfFileParams>
unsigned int ElfFile<ElfFileParamNames>::findSection3(const SectionName & sectionName)
{
    for (unsigned int i = 1; i < rdi(hdr->e_shnum); ++i)
        if (getSectionName(shdrs[i]) == sectionName) return i;
    return 0;
}


template<ElfFileParams>
string & ElfFile<ElfFileParamNames>::replaceSection(const SectionName & sectionName,
    unsigned int size)
{
    ReplacedSections::iterator i = replacedSections.find(sectionName);
    string s;
    
    if (i != replacedSections.end()) {
        s = string(i->second);
    } else {
        Elf_Shdr & shdr = findSection(sectionName);
        s = string((char *) contents + rdi(shdr.sh_offset), rdi(shdr.sh_size));
    }
    
    s.resize(size);
    replacedSections[sectionName] = s;

    return replacedSections[sectionName];
}


template<ElfFileParams>
void ElfFile<ElfFileParamNames>::writeReplacedSections(Elf_Off & curOff,
    Elf_Addr startAddr, Elf_Off startOffset)
{
    /* Overwrite the old section contents with 'X's.  Do this
       *before* writing the new section contents (below) to prevent
       clobbering previously written new section contents. */
    for (ReplacedSections::iterator i = replacedSections.begin();
         i != replacedSections.end(); ++i)
    {
        string sectionName = i->first;
        Elf_Shdr & shdr = findSection(sectionName);
        memset(contents + rdi(shdr.sh_offset), 'X', rdi(shdr.sh_size));
    }
    
    for (ReplacedSections::iterator i = replacedSections.begin();
         i != replacedSections.end(); ++i)
    {
        string sectionName = i->first;
        Elf_Shdr & shdr = findSection(sectionName);
        debug("rewriting section `%s' from offset %d (size %d) to offset %d (size %d)\n",
            sectionName.c_str(), rdi(shdr.sh_offset), rdi(shdr.sh_size), curOff, i->second.size());

        memcpy(contents + curOff, (unsigned char *) i->second.c_str(),
            i->second.size());

        /* Update the section header for this section. */
        wri(shdr.sh_offset, curOff);
        wri(shdr.sh_addr, startAddr + (curOff - startOffset));
        wri(shdr.sh_size, i->second.size());
        wri(shdr.sh_addralign, sectionAlignment);

        /* If this is the .interp section, then the PT_INTERP segment
           must be sync'ed with it. */
        if (sectionName == ".interp") {
            for (unsigned int j = 0; j < phdrs.size(); ++j)
                if (rdi(phdrs[j].p_type) == PT_INTERP) {
                    phdrs[j].p_offset = shdr.sh_offset;
                    phdrs[j].p_vaddr = phdrs[j].p_paddr = shdr.sh_addr;
                    phdrs[j].p_filesz = phdrs[j].p_memsz = shdr.sh_size;
                }
        }

        /* If this is the .dynamic section, then the PT_DYNAMIC segment
           must be sync'ed with it. */
        if (sectionName == ".dynamic") {
            for (unsigned int j = 0; j < phdrs.size(); ++j)
                if (rdi(phdrs[j].p_type) == PT_DYNAMIC) {
                    phdrs[j].p_offset = shdr.sh_offset;
                    phdrs[j].p_vaddr = phdrs[j].p_paddr = shdr.sh_addr;
                    phdrs[j].p_filesz = phdrs[j].p_memsz = shdr.sh_size;
                }
        }

        curOff += roundUp(i->second.size(), sectionAlignment);
    }

    replacedSections.clear();
}


template<ElfFileParams>
void ElfFile<ElfFileParamNames>::rewriteSectionsLibrary()
{
    /* For dynamic libraries, we just place the replacement sections
       at the end of the file.  They're mapped into memory by a
       PT_LOAD segment located directly after the last virtual address
       page of other segments. */
    Elf_Addr startPage = 0;
    for (unsigned int i = 0; i < phdrs.size(); ++i) {
        Elf_Addr thisPage = roundUp(rdi(phdrs[i].p_vaddr) + rdi(phdrs[i].p_memsz), pageSize);
        if (thisPage > startPage) startPage = thisPage;
    }

    debug("last page is 0x%llx\n", (unsigned long long) startPage);


    /* Compute the total space needed for the replaced sections and
       the program headers. */
    off_t neededSpace = (phdrs.size() + 1) * sizeof(Elf_Phdr);
    for (ReplacedSections::iterator i = replacedSections.begin();
         i != replacedSections.end(); ++i)
        neededSpace += roundUp(i->second.size(), sectionAlignment);
    debug("needed space is %d\n", neededSpace);


    off_t startOffset = roundUp(fileSize, pageSize);

    growFile(startOffset + neededSpace);


    /* Add a segment that maps the replaced sections and program
       headers into memory. */
    phdrs.resize(rdi(hdr->e_phnum) + 1);
    wri(hdr->e_phnum, rdi(hdr->e_phnum) + 1);
    Elf_Phdr & phdr = phdrs[rdi(hdr->e_phnum) - 1];
    wri(phdr.p_type, PT_LOAD);
    wri(phdr.p_offset, startOffset);
    wri(phdr.p_vaddr, wri(phdr.p_paddr, startPage));
    wri(phdr.p_filesz, wri(phdr.p_memsz, neededSpace));
    wri(phdr.p_flags, PF_R | PF_W);
    wri(phdr.p_align, 4096);


    /* Write out the replaced sections. */
    Elf_Off curOff = startOffset + phdrs.size() * sizeof(Elf_Phdr);
    writeReplacedSections(curOff, startPage, startOffset);
    assert((off_t) curOff == startOffset + neededSpace);


    /* Move the program header to the start of the new area. */
    wri(hdr->e_phoff, startOffset);

    rewriteHeaders(startPage);
}


template<ElfFileParams>
void ElfFile<ElfFileParamNames>::rewriteSectionsExecutable()
{
    /* Sort the sections by offset, otherwise we won't correctly find
       all the sections before the last replaced section. */
    sortShdrs();


    /* What is the index of the last replaced section? */
    unsigned int lastReplaced = 0;
    for (unsigned int i = 1; i < rdi(hdr->e_shnum); ++i) {
        string sectionName = getSectionName(shdrs[i]);
        if (replacedSections.find(sectionName) != replacedSections.end()) {
            debug("using replaced section `%s'\n", sectionName.c_str());
            lastReplaced = i;
        }
    }

    assert(lastReplaced != 0);

    debug("last replaced is %d\n", lastReplaced);
    
    /* Try to replace all sections before that, as far as possible.
       Stop when we reach an irreplacable section (such as one of type
       SHT_PROGBITS).  These cannot be moved in virtual address space
       since that would invalidate absolute references to them. */
    assert(lastReplaced + 1 < shdrs.size()); /* !!! I'm lazy. */
    off_t startOffset = rdi(shdrs[lastReplaced + 1].sh_offset);
    Elf_Addr startAddr = rdi(shdrs[lastReplaced + 1].sh_addr);
    string prevSection;
    for (unsigned int i = 1; i <= lastReplaced; ++i) {
        Elf_Shdr & shdr(shdrs[i]);
        string sectionName = getSectionName(shdr);
        debug("looking at section `%s'\n", sectionName.c_str());
        /* !!! Why do we stop after a .dynstr section? I can't
           remember! */
        if ((rdi(shdr.sh_type) == SHT_PROGBITS && sectionName != ".interp")
            || prevSection == ".dynstr")
        {
            startOffset = rdi(shdr.sh_offset);
            startAddr = rdi(shdr.sh_addr);
            lastReplaced = i - 1;
            break;
        } else {
            if (replacedSections.find(sectionName) == replacedSections.end()) {
                debug("replacing section `%s' which is in the way\n", sectionName.c_str());
                replaceSection(sectionName, rdi(shdr.sh_size));
            }
        }
        prevSection = sectionName;
    }

    debug("first reserved offset/addr is 0x%x/0x%llx\n",
        startOffset, (unsigned long long) startAddr);
    
    assert(startAddr % pageSize == startOffset % pageSize);
    Elf_Addr firstPage = startAddr - startOffset;
    debug("first page is 0x%llx\n", (unsigned long long) firstPage);
        
    /* Right now we assume that the section headers are somewhere near
       the end, which appears to be the case most of the time.
       Therefore they're not accidentally overwritten by the replaced
       sections. !!!  Fix this. */
    assert((off_t) rdi(hdr->e_shoff) >= startOffset);

    
    /* Compute the total space needed for the replaced sections, the
       ELF header, and the program headers. */
    off_t neededSpace = sizeof(Elf_Ehdr) + phdrs.size() * sizeof(Elf_Phdr);
    for (ReplacedSections::iterator i = replacedSections.begin();
         i != replacedSections.end(); ++i)
        neededSpace += roundUp(i->second.size(), sectionAlignment);

    debug("needed space is %d\n", neededSpace);

    /* If we need more space at the start of the file, then grow the
       file by the minimum number of pages and adjust internal
       offsets. */
    if (neededSpace > startOffset) {

        /* We also need an additional program header, so adjust for that. */
        neededSpace += sizeof(Elf_Phdr);
        debug("needed space is %d\n", neededSpace);
        
        unsigned int neededPages = roundUp(neededSpace - startOffset, pageSize) / pageSize;
        debug("needed pages is %d\n", neededPages);
        if (neededPages * pageSize > firstPage)
            error("virtual address space underrun!");
        
        firstPage -= neededPages * pageSize;
        startOffset += neededPages * pageSize;

        shiftFile(neededPages, firstPage);
    }


    /* Clear out the free space. */
    Elf_Off curOff = sizeof(Elf_Ehdr) + phdrs.size() * sizeof(Elf_Phdr);
    debug("clearing first %d bytes\n", startOffset - curOff);
    memset(contents + curOff, 0, startOffset - curOff);
    

    /* Write out the replaced sections. */
    writeReplacedSections(curOff, firstPage, 0);
    assert((off_t) curOff == neededSpace);

    
    rewriteHeaders(firstPage + rdi(hdr->e_phoff));
}

    
template<ElfFileParams>
void ElfFile<ElfFileParamNames>::rewriteSections()
{
    if (replacedSections.empty()) return;

    for (ReplacedSections::iterator i = replacedSections.begin();
         i != replacedSections.end(); ++i)
        debug("replacing section `%s' with size %d\n",
            i->first.c_str(), i->second.size());

    if (rdi(hdr->e_type) == ET_DYN) {
        debug("this is a dynamic library\n");
        rewriteSectionsLibrary();
    } else if (rdi(hdr->e_type) == ET_EXEC) {
        debug("this is an executable\n");
        rewriteSectionsExecutable();
    } else error("unknown ELF type");
}


template<ElfFileParams>
void ElfFile<ElfFileParamNames>::rewriteHeaders(Elf_Addr phdrAddress)
{
    /* Rewrite the program header table. */

    /* If there is a segment for the program header table, update it.
       (According to the ELF spec, it must be the first entry.) */
    if (rdi(phdrs[0].p_type) == PT_PHDR) {
        phdrs[0].p_offset = hdr->e_phoff;
        wri(phdrs[0].p_vaddr, wri(phdrs[0].p_paddr, phdrAddress));
        wri(phdrs[0].p_filesz, wri(phdrs[0].p_memsz, phdrs.size() * sizeof(Elf_Phdr)));
    }

    sortPhdrs();

    for (unsigned int i = 0; i < phdrs.size(); ++i)
        * ((Elf_Phdr *) (contents + rdi(hdr->e_phoff)) + i) = phdrs[i];

    
    /* Rewrite the section header table.  For neatness, keep the
       sections sorted. */
    assert(rdi(hdr->e_shnum) == shdrs.size());
    sortShdrs();
    for (unsigned int i = 1; i < rdi(hdr->e_shnum); ++i)
        * ((Elf_Shdr *) (contents + rdi(hdr->e_shoff)) + i) = shdrs[i];

    
    /* Update all those nasty virtual addresses in the .dynamic
       section.  Note that not all executables have .dynamic sections
       (e.g., those produced by klibc's klcc). */
    Elf_Shdr * shdrDynamic = findSection2(".dynamic");
    if (shdrDynamic) {
        Elf_Dyn * dyn = (Elf_Dyn *) (contents + rdi(shdrDynamic->sh_offset));
        unsigned int d_tag;
        for ( ; (d_tag = rdi(dyn->d_tag)) != DT_NULL; dyn++)
            if (d_tag == DT_STRTAB)
                dyn->d_un.d_ptr = findSection(".dynstr").sh_addr;
            else if (d_tag == DT_STRSZ)
                dyn->d_un.d_val = findSection(".dynstr").sh_size;
            else if (d_tag == DT_SYMTAB)
                dyn->d_un.d_ptr = findSection(".dynsym").sh_addr;
            else if (d_tag == DT_HASH)
                dyn->d_un.d_ptr = findSection(".hash").sh_addr;
            else if (d_tag == DT_GNU_HASH)
                dyn->d_un.d_ptr = findSection(".gnu.hash").sh_addr;
            else if (d_tag == DT_JMPREL) {
                Elf_Shdr * shdr = findSection2(".rel.plt");
                if (!shdr) shdr = findSection2(".rela.plt"); /* 64-bit Linux, x86-64 */
                if (!shdr) shdr = findSection2(".rela.IA_64.pltoff"); /* 64-bit Linux, IA-64 */
                if (!shdr) error("cannot find section corresponding to DT_JMPREL");
                dyn->d_un.d_ptr = shdr->sh_addr;
            }
            else if (d_tag == DT_REL) { /* !!! hack! */
                Elf_Shdr * shdr = findSection2(".rel.dyn");
                /* no idea if this makes sense, but it was needed for some
                   program */
                if (!shdr) shdr = findSection2(".rel.got");
                if (!shdr) error("cannot find .rel.dyn or .rel.got");
                dyn->d_un.d_ptr = shdr->sh_addr;
            }
            /* should probably update DT_RELA */
            else if (d_tag == DT_VERNEED)
                dyn->d_un.d_ptr = findSection(".gnu.version_r").sh_addr;
            else if (d_tag == DT_VERSYM)
                dyn->d_un.d_ptr = findSection(".gnu.version").sh_addr;
    }
}



static void setSubstr(string & s, unsigned int pos, const string & t)
{
    assert(pos + t.size() <= s.size());
    copy(t.begin(), t.end(), s.begin() + pos);
}


template<ElfFileParams>
string ElfFile<ElfFileParamNames>::getInterpreter()
{
    Elf_Shdr & shdr = findSection(".interp");
    return string((char *) contents + rdi(shdr.sh_offset), rdi(shdr.sh_size));
}


template<ElfFileParams>
void ElfFile<ElfFileParamNames>::setInterpreter(const string & newInterpreter)
{
    string & section = replaceSection(".interp", newInterpreter.size() + 1);
    setSubstr(section, 0, newInterpreter + '\0');
    changed = true;
}


static void concatToRPath(string & rpath, const string & path)
{
    if (!rpath.empty()) rpath += ":";
    rpath += path;
}


template<ElfFileParams>
void ElfFile<ElfFileParamNames>::modifyRPath(RPathOp op, string newRPath)
{
    Elf_Shdr & shdrDynamic = findSection(".dynamic");

    /* !!! We assume that the virtual address in the DT_STRTAB entry
       of the dynamic section corresponds to the .dynstr section. */ 
    Elf_Shdr & shdrDynStr = findSection(".dynstr");
    char * strTab = (char *) contents + rdi(shdrDynStr.sh_offset);

    /* Find the DT_STRTAB entry in the dynamic section. */
    Elf_Dyn * dyn = (Elf_Dyn *) (contents + rdi(shdrDynamic.sh_offset));
    Elf_Addr strTabAddr = 0;
    for ( ; rdi(dyn->d_tag) != DT_NULL; dyn++)
        if (rdi(dyn->d_tag) == DT_STRTAB) strTabAddr = rdi(dyn->d_un.d_ptr);
    if (!strTabAddr) error("strange: no string table");

    assert(strTabAddr == rdi(shdrDynStr.sh_addr));
    
    
    /* Walk through the dynamic section, look for the RPATH/RUNPATH
       entry.

       According to the ld.so docs, DT_RPATH is obsolete, we should
       use DT_RUNPATH.  DT_RUNPATH has two advantages: it can be
       overriden by LD_LIBRARY_PATH, and it's scoped (the DT_RUNPATH
       for an executable or library doesn't affect the search path for
       libraries used by it).  DT_RPATH is ignored if DT_RUNPATH is
       present.  The binutils `ld' still generates only DT_RPATH,
       unless you use its `--enable-new-dtag' option, in which case it
       generates a DT_RPATH and DT_RUNPATH pointing at the same
       string. */
    static vector<string> neededLibs;
    dyn = (Elf_Dyn *) (contents + rdi(shdrDynamic.sh_offset));
    Elf_Dyn * dynRPath = 0, * dynRunPath = 0;
    char * rpath = 0;
    for ( ; rdi(dyn->d_tag) != DT_NULL; dyn++) {
        if (rdi(dyn->d_tag) == DT_RPATH) {
            dynRPath = dyn;
            /* Only use DT_RPATH if there is no DT_RUNPATH. */
            if (!dynRunPath) 
                rpath = strTab + rdi(dyn->d_un.d_val);
        }
        else if (rdi(dyn->d_tag) == DT_RUNPATH) {
            dynRunPath = dyn;
            rpath = strTab + rdi(dyn->d_un.d_val);
        }
        else if (rdi(dyn->d_tag) == DT_NEEDED)
	  neededLibs.push_back(string(strTab + rdi(dyn->d_un.d_val)));
    }

    if (op == rpPrint) {
        printf("%s\n", rpath ? rpath : "");
        return;
    }
    
    if (op == rpShrink && !rpath) {
        debug("no RPATH to shrink\n");
        return;
    }

    
    /* For each directory in the RPATH, check if it contains any
       needed library. */
    if (op == rpShrink) {
        static vector<bool> neededLibFound(neededLibs.size(), false);

        newRPath = "";

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
            bool libFound = false;
            for (unsigned int j = 0; j < neededLibs.size(); ++j)
                if (!neededLibFound[j]) {
                    string libName = dirName + "/" + neededLibs[j];
                    struct stat st;
                    if (stat(libName.c_str(), &st) == 0) {
                        neededLibFound[j] = true;
                        libFound = true;
                    }
                }

            if (!libFound)
                debug("removing directory `%s' from RPATH\n", dirName.c_str());
            else
                concatToRPath(newRPath, dirName);
        }
    }

    
    if (string(rpath ? rpath : "") == newRPath) return;

    changed = true;
    
    /* Zero out the previous rpath to prevent retained dependencies in
       Nix. */
    unsigned int rpathSize = 0;
    if (rpath) {
        rpathSize = strlen(rpath);
        memset(rpath, 'X', rpathSize);
    }

    debug("new rpath is `%s'\n", newRPath.c_str());

    if (!forceRPath && dynRPath && !dynRunPath) { /* convert DT_RPATH to DT_RUNPATH */
        dynRPath->d_tag = DT_RUNPATH;
        dynRunPath = dynRPath;
        dynRPath = 0;
    }

    if (forceRPath && dynRPath && dynRunPath) { /* convert DT_RUNPATH to DT_RPATH */
        dynRunPath->d_tag = DT_IGNORE;
    }
    
    if (newRPath.size() <= rpathSize) {
        strcpy(rpath, newRPath.c_str());
        return;
    }

    /* Grow the .dynstr section to make room for the new RPATH. */
    debug("rpath is too long, resizing...\n");

    string & newDynStr = replaceSection(".dynstr",
        rdi(shdrDynStr.sh_size) + newRPath.size() + 1);
    setSubstr(newDynStr, rdi(shdrDynStr.sh_size), newRPath + '\0');

    /* Update the DT_RUNPATH and DT_RPATH entries. */
    if (dynRunPath || dynRPath) {
        if (dynRunPath) dynRunPath->d_un.d_val = shdrDynStr.sh_size;
        if (dynRPath) dynRPath->d_un.d_val = shdrDynStr.sh_size;
    }

    else {
        /* There is no DT_RUNPATH entry in the .dynamic section, so we
           have to grow the .dynamic section. */
        string & newDynamic = replaceSection(".dynamic",
            rdi(shdrDynamic.sh_size) + sizeof(Elf_Dyn));

        unsigned int idx = 0;
        for ( ; rdi(((Elf_Dyn *) newDynamic.c_str())[idx].d_tag) != DT_NULL; idx++) ;
        debug("DT_NULL index is %d\n", idx);

        /* Shift all entries down by one. */
        setSubstr(newDynamic, sizeof(Elf_Dyn),
            string(newDynamic, 0, sizeof(Elf_Dyn) * (idx + 1)));

        /* Add the DT_RUNPATH entry at the top. */
        Elf_Dyn newDyn;
        wri(newDyn.d_tag, forceRPath ? DT_RPATH : DT_RUNPATH);
        newDyn.d_un.d_val = shdrDynStr.sh_size;
        setSubstr(newDynamic, 0, string((char *) &newDyn, sizeof(Elf_Dyn)));
    }
}


static bool printInterpreter = false;
static string newInterpreter;

static bool shrinkRPath = false;
static bool setRPath = false;
static bool printRPath = false;
static string newRPath;


template<class ElfFile>
static void patchElf2(ElfFile & elfFile, mode_t fileMode)
{
    elfFile.parse();


    if (printInterpreter)
        printf("%s\n", elfFile.getInterpreter().c_str());
    
    if (newInterpreter != "")
        elfFile.setInterpreter(newInterpreter);

    if (printRPath)
        elfFile.modifyRPath(elfFile.rpPrint, "");

    if (shrinkRPath)
        elfFile.modifyRPath(elfFile.rpShrink, "");
    else if (setRPath)
        elfFile.modifyRPath(elfFile.rpSet, newRPath);
    
    
    if (elfFile.isChanged()){
        elfFile.rewriteSections();
        writeFile(fileName, fileMode);
    }
}

    
static void patchElf()
{
    if (!printInterpreter && !printRPath)
        debug("patching ELF file `%s'\n", fileName.c_str());

    mode_t fileMode;
    
    readFile(fileName, &fileMode);


    /* Check the ELF header for basic validity. */
    if (fileSize < (off_t) sizeof(Elf32_Ehdr)) error("missing ELF header");

    if (memcmp(contents, ELFMAG, SELFMAG) != 0)
        error("not an ELF executable");
    
    if (contents[EI_CLASS] == ELFCLASS32 &&
        contents[EI_VERSION] == EV_CURRENT)
    {
        ElfFile<Elf32_Ehdr, Elf32_Phdr, Elf32_Shdr, Elf32_Addr, Elf32_Off, Elf32_Dyn> elfFile;
        patchElf2(elfFile, fileMode);
    }
    else if (contents[EI_CLASS] == ELFCLASS64 &&
        contents[EI_VERSION] == EV_CURRENT)
    {
        ElfFile<Elf64_Ehdr, Elf64_Phdr, Elf64_Shdr, Elf64_Addr, Elf64_Off, Elf64_Dyn> elfFile;
        patchElf2(elfFile, fileMode);
    }
    else {
        error("ELF executable is not 32/64-bit, little/big-endian, version 1");
    }
}


void showHelp(const string & progName)
{
        fprintf(stderr, "syntax: %s\n\
  [--set-interpreter FILENAME]\n\
  [--print-interpreter]\n\
  [--set-rpath RPATH]\n\
  [--shrink-rpath]\n\
  [--print-rpath]\n\
  [--force-rpath]\n\
  [--debug]\n\
  [--version]\n\
  FILENAME\n", progName.c_str());
}


int main(int argc, char * * argv)
{
    if (argc <= 1) {
        showHelp(argv[0]);
        return 1;
    }

    if (getenv("PATCHELF_DEBUG") != 0) debugMode = true;

    int i;
    for (i = 1; i < argc; ++i) {
        string arg(argv[i]);
        if (arg == "--set-interpreter" || arg == "--interpreter") {
            if (++i == argc) error("missing argument");
            newInterpreter = argv[i];
        }
        else if (arg == "--print-interpreter") {
            printInterpreter = true;
        }
        else if (arg == "--shrink-rpath") {
            shrinkRPath = true;
        }
        else if (arg == "--set-rpath") {
            if (++i == argc) error("missing argument");
            setRPath = true;
            newRPath = argv[i];
        }
        else if (arg == "--print-rpath") {
            printRPath = true;
        }
        else if (arg == "--force-rpath") {
            /* Generally we prefer to emit DT_RUNPATH instead of
               DT_RPATH, as the latter is obsolete.  However, there is
               a slight semantic difference: DT_RUNPATH is "scoped",
               it only affects the executable or library in question,
               not its recursive imports.  So maybe you really want to
               force the use of DT_RPATH.  That's what this option
               does.  Without it, DT_RPATH (if encountered) is
               converted to DT_RUNPATH, and if neither is present, a
               DT_RUNPATH is added.  With it, DT_RPATH isn't converted
               to DT_RUNPATH, and if neither is present, a DT_RPATH is
               added. */
            forceRPath = true;
        }
        else if (arg == "--debug") {
            debugMode = true;
        }
        else if (arg == "--help") {
            showHelp(argv[0]);
            return 0;
        }
        else if (arg == "--version") {
            printf(PACKAGE_STRING "\n");
            return 0;
        }
        else break;
    }

    if (i == argc) error("missing filename");
    fileName = argv[i];

    patchElf();

    return 0;
}
