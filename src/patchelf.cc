/*
 *  PatchELF is a utility to modify properties of ELF executables and libraries
 *  Copyright (C) 2004-2016  Eelco Dolstra <edolstra@gmail.com>
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or (at
 *  your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include <algorithm>
#include <limits>
#include <map>
#include <memory>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>
#include <optional>

#include <cassert>
#include <cerrno>
#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "elf.h"
#include "patchelf.h"

#ifndef PACKAGE_STRING
#define PACKAGE_STRING "patchelf"
#endif

// This is needed for Windows/mingw
#ifndef O_BINARY
#define O_BINARY 0
#endif

static bool debugMode = false;

static bool forceRPath = false;

static std::vector<std::string> fileNames;
static std::string outputFileName;
static bool alwaysWrite = false;
#ifdef DEFAULT_PAGESIZE
static int forcedPageSize = DEFAULT_PAGESIZE;
#else
static int forcedPageSize = -1;
#endif

#ifndef EM_LOONGARCH
#define EM_LOONGARCH    258
#endif

[[nodiscard]] static std::vector<std::string> splitColonDelimitedString(std::string_view s)
{
    std::vector<std::string> parts;

    size_t pos;
    while ((pos = s.find(':')) != std::string_view::npos) {
        parts.emplace_back(s.substr(0, pos));
        s = s.substr(pos + 1);
    }

    if (!s.empty())
        parts.emplace_back(s);

    return parts;
}

static bool hasAllowedPrefix(const std::string & s, const std::vector<std::string> & allowedPrefixes)
{
    return std::any_of(allowedPrefixes.begin(), allowedPrefixes.end(), [&](const std::string & i) { return !s.compare(0, i.size(), i); });
}

/* !!! G++ creates broken code if this function is inlined, don't know
   why... */
template<ElfFileParams>
template<class I>
constexpr I ElfFile<ElfFileParamNames>::rdi(I i) const noexcept
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


static void debug(const char * format, ...)
{
    if (debugMode) {
        va_list ap;
        va_start(ap, format);
        vfprintf(stderr, format, ap);
        va_end(ap);
    }
}


static void fmt2([[maybe_unused]] std::ostringstream & out)
{
}


template<typename T, typename... Args>
void fmt2(std::ostringstream & out, T x, Args... args)
{
    out << x;
    fmt2(out, args...);
}


template<typename... Args>
std::string fmt(Args... args)
{
    std::ostringstream out;
    fmt2(out, args...);
    return out.str();
}


struct SysError : std::runtime_error
{
    int errNo;
    explicit SysError(const std::string & msg)
        : std::runtime_error(fmt(msg + ": " + strerror(errno)))
        , errNo(errno)
    { }
};

__attribute__((noreturn)) static void error(const std::string & msg)
{
    if (errno)
        throw SysError(msg);
    throw std::runtime_error(msg);
}

static FileContents readFile(const std::string & fileName,
    size_t cutOff = std::numeric_limits<size_t>::max())
{
    struct stat st;
    if (stat(fileName.c_str(), &st) != 0)
        throw SysError(fmt("getting info about '", fileName, "'"));

    if (static_cast<uint64_t>(st.st_size) > static_cast<uint64_t>(std::numeric_limits<size_t>::max()))
        throw SysError(fmt("cannot read file of size ", st.st_size, " into memory"));

    size_t size = std::min(cutOff, static_cast<size_t>(st.st_size));

    FileContents contents = std::make_shared<std::vector<unsigned char>>(size);

    int fd = open(fileName.c_str(), O_RDONLY | O_BINARY);
    if (fd == -1) throw SysError(fmt("opening '", fileName, "'"));

    size_t bytesRead = 0;
    ssize_t portion;
    while ((portion = read(fd, contents->data() + bytesRead, size - bytesRead)) > 0)
        bytesRead += portion;

    if (bytesRead != size)
        throw SysError(fmt("reading '", fileName, "'"));

    close(fd);

    return contents;
}


struct ElfType
{
    bool is32Bit;
    int machine; // one of EM_*
};


ElfType getElfType(const FileContents & fileContents)
{
    /* Check the ELF header for basic validity. */
    if (fileContents->size() < static_cast<off_t>(sizeof(Elf32_Ehdr)))
        error("missing ELF header");

    auto contents = fileContents->data();

    if (memcmp(contents, ELFMAG, SELFMAG) != 0)
        error("not an ELF executable");

    if (contents[EI_VERSION] != EV_CURRENT)
        error("unsupported ELF version");

    if (contents[EI_CLASS] != ELFCLASS32 && contents[EI_CLASS] != ELFCLASS64)
        error("ELF executable is not 32 or 64 bit");

    bool is32Bit = contents[EI_CLASS] == ELFCLASS32;

    // FIXME: endianness
    return ElfType { is32Bit, is32Bit ? (reinterpret_cast<Elf32_Ehdr *>(contents))->e_machine : (reinterpret_cast<Elf64_Ehdr *>(contents))->e_machine };
}


static void checkPointer(const FileContents & contents, void * p, unsigned int size)
{
    auto q = static_cast<unsigned char *>(p);
    if (!(q >= contents->data() && q + size <= contents->data() + contents->size()))
        error("data region extends past file end");
}


template<ElfFileParams>
ElfFile<ElfFileParamNames>::ElfFile(FileContents fContents)
    : fileContents(fContents)
{
    /* Check the ELF header for basic validity. */
    if (fileContents->size() < (off_t) sizeof(Elf_Ehdr)) error("missing ELF header");


    if (memcmp(hdr()->e_ident, ELFMAG, SELFMAG) != 0)
        error("not an ELF executable");

    littleEndian = hdr()->e_ident[EI_DATA] == ELFDATA2LSB;

    if (rdi(hdr()->e_type) != ET_EXEC && rdi(hdr()->e_type) != ET_DYN)
        error("wrong ELF type");

    if (rdi(hdr()->e_phoff) + rdi(hdr()->e_phnum) * rdi(hdr()->e_phentsize) > fileContents->size())
        error("program header table out of bounds");

    if (rdi(hdr()->e_shnum) == 0)
        error("no section headers. The input file is probably a statically linked, self-decompressing binary");

    if (rdi(hdr()->e_shoff) + rdi(hdr()->e_shnum) * rdi(hdr()->e_shentsize) > fileContents->size())
        error("section header table out of bounds");

    if (rdi(hdr()->e_phentsize) != sizeof(Elf_Phdr))
        error("program headers have wrong size");

    /* Copy the program and section headers. */
    for (int i = 0; i < rdi(hdr()->e_phnum); ++i) {
        Elf_Phdr *phdr = (Elf_Phdr *) (fileContents->data() + rdi(hdr()->e_phoff)) + i;

        checkPointer(fileContents, phdr, sizeof(*phdr));
        phdrs.push_back(*phdr);
        if (rdi(phdrs[i].p_type) == PT_INTERP) isExecutable = true;
    }

    for (int i = 0; i < rdi(hdr()->e_shnum); ++i) {
        Elf_Shdr *shdr = (Elf_Shdr *) (fileContents->data() + rdi(hdr()->e_shoff)) + i;

        checkPointer(fileContents, shdr, sizeof(*shdr));
        shdrs.push_back(*shdr);
    }

    /* Get the section header string table section (".shstrtab").  Its
       index in the section header table is given by e_shstrndx field
       of the ELF header. */
    unsigned int shstrtabIndex = rdi(hdr()->e_shstrndx);
    if (shstrtabIndex >= shdrs.size())
        error("string table index out of bounds");

    unsigned int shstrtabSize = rdi(shdrs[shstrtabIndex].sh_size);
    char * shstrtab = (char * ) fileContents->data() + rdi(shdrs[shstrtabIndex].sh_offset);
    checkPointer(fileContents, shstrtab, shstrtabSize);

    if (shstrtabSize == 0)
        error("string table size is zero");

    if (shstrtab[shstrtabSize - 1] != 0)
        error("string table is not zero terminated");

    sectionNames = std::string(shstrtab, shstrtabSize);

    sectionsByOldIndex.resize(shdrs.size());
    for (size_t i = 1; i < shdrs.size(); ++i)
        sectionsByOldIndex.at(i) = getSectionName(shdrs.at(i));
}


template<ElfFileParams>
unsigned int ElfFile<ElfFileParamNames>::getPageSize() const noexcept
{
    if (forcedPageSize > 0)
        return forcedPageSize;

    // Architectures (and ABIs) can have different minimum section alignment
    // requirements. There is no authoritative list of these values. The
    // current list is extracted from GNU gold's source code (abi_pagesize).
    switch (rdi(hdr()->e_machine)) {
      case EM_SPARC:
      case EM_MIPS:
      case EM_PPC:
      case EM_PPC64:
      case EM_AARCH64:
      case EM_TILEGX:
      case EM_LOONGARCH:
        return 0x10000;
      default:
        return 0x1000;
    }
}


template<ElfFileParams>
void ElfFile<ElfFileParamNames>::sortPhdrs()
{
    /* Sort the segments by offset. */
    CompPhdr comp;
    comp.elfFile = this;
    stable_sort(phdrs.begin(), phdrs.end(), comp);
}


template<ElfFileParams>
void ElfFile<ElfFileParamNames>::sortShdrs()
{
    /* Translate sh_link mappings to section names, since sorting the
       sections will invalidate the sh_link fields. */
    std::map<SectionName, SectionName> linkage;
    for (unsigned int i = 1; i < rdi(hdr()->e_shnum); ++i)
        if (rdi(shdrs.at(i).sh_link) != 0)
            linkage[getSectionName(shdrs.at(i))] = getSectionName(shdrs.at(rdi(shdrs.at(i).sh_link)));

    /* Idem for sh_info on certain sections. */
    std::map<SectionName, SectionName> info;
    for (unsigned int i = 1; i < rdi(hdr()->e_shnum); ++i)
        if (rdi(shdrs.at(i).sh_info) != 0 &&
            (rdi(shdrs.at(i).sh_type) == SHT_REL || rdi(shdrs.at(i).sh_type) == SHT_RELA))
            info[getSectionName(shdrs.at(i))] = getSectionName(shdrs.at(rdi(shdrs.at(i).sh_info)));

    /* Idem for the index of the .shstrtab section in the ELF header. */
    Elf_Shdr shstrtab = shdrs.at(rdi(hdr()->e_shstrndx));

    /* Sort the sections by offset. */
    CompShdr comp;
    comp.elfFile = this;
    stable_sort(shdrs.begin() + 1, shdrs.end(), comp);

    /* Restore the sh_link mappings. */
    for (unsigned int i = 1; i < rdi(hdr()->e_shnum); ++i)
        if (rdi(shdrs[i].sh_link) != 0)
            wri(shdrs[i].sh_link,
                getSectionIndex(linkage[getSectionName(shdrs[i])]));

    /* And the st_info mappings. */
    for (unsigned int i = 1; i < rdi(hdr()->e_shnum); ++i)
        if (rdi(shdrs.at(i).sh_info) != 0 &&
            (rdi(shdrs.at(i).sh_type) == SHT_REL || rdi(shdrs.at(i).sh_type) == SHT_RELA))
            wri(shdrs.at(i).sh_info,
                getSectionIndex(info.at(getSectionName(shdrs.at(i)))));

    /* And the .shstrtab index. Note: the match here is done by checking the offset as searching
     * by name can yield incorrect results in case there are multiple sections with the same
     * name as the one initially pointed by hdr()->e_shstrndx */
    for (unsigned int i = 1; i < rdi(hdr()->e_shnum); ++i) {
        if (shdrs.at(i).sh_offset == shstrtab.sh_offset) {
            wri(hdr()->e_shstrndx, i);
        }
    }
}

static void writeFile(const std::string & fileName, const FileContents & contents)
{
    debug("writing %s\n", fileName.c_str());

    int fd = open(fileName.c_str(), O_CREAT | O_TRUNC | O_WRONLY | O_BINARY, 0777);
    if (fd == -1)
        error("open");

    size_t bytesWritten = 0;
    ssize_t portion;
    while (bytesWritten < contents->size()) {
        if ((portion = write(fd, contents->data() + bytesWritten, contents->size() - bytesWritten)) < 0) {
            if (errno == EINTR)
                continue;
            error("write");
        }
        bytesWritten += portion;
    }

    if (close(fd) >= 0)
        return;
    /*
     * Just ignore EINTR; a retry loop is the wrong thing to do.
     *
     * http://lkml.indiana.edu/hypermail/linux/kernel/0509.1/0877.html
     * https://bugzilla.gnome.org/show_bug.cgi?id=682819
     * http://utcc.utoronto.ca/~cks/space/blog/unix/CloseEINTR
     * https://sites.google.com/site/michaelsafyan/software-engineering/checkforeintrwheninvokingclosethinkagain
     */
    if (errno == EINTR)
        return;
    error("close");
}


static uint64_t roundUp(uint64_t n, uint64_t m)
{
    return ((n - 1) / m + 1) * m;
}


template<ElfFileParams>
void ElfFile<ElfFileParamNames>::shiftFile(unsigned int extraPages, Elf_Addr startPage)
{
    /* Move the entire contents of the file 'extraPages' pages
       further. */
    unsigned int oldSize = fileContents->size();
    unsigned int shift = extraPages * getPageSize();
    fileContents->resize(oldSize + shift, 0);
    memmove(fileContents->data() + shift, fileContents->data(), oldSize);
    memset(fileContents->data() + sizeof(Elf_Ehdr), 0, shift - sizeof(Elf_Ehdr));

    /* Adjust the ELF header. */
    wri(hdr()->e_phoff, sizeof(Elf_Ehdr));
    wri(hdr()->e_shoff, rdi(hdr()->e_shoff) + shift);

    /* Update the offsets in the section headers. */
    for (int i = 1; i < rdi(hdr()->e_shnum); ++i)
        wri(shdrs.at(i).sh_offset, rdi(shdrs.at(i).sh_offset) + shift);

    /* Update the offsets in the program headers. */
    for (int i = 0; i < rdi(hdr()->e_phnum); ++i) {
        wri(phdrs.at(i).p_offset, rdi(phdrs.at(i).p_offset) + shift);
        if (rdi(phdrs.at(i).p_align) != 0 &&
            (rdi(phdrs.at(i).p_vaddr) - rdi(phdrs.at(i).p_offset)) % rdi(phdrs.at(i).p_align) != 0) {
            debug("changing alignment of program header %d from %d to %d\n", i,
                rdi(phdrs.at(i).p_align), getPageSize());
            wri(phdrs.at(i).p_align, getPageSize());
        }
    }

    /* Add a segment that maps the new program/section headers and
       PT_INTERP segment into memory.  Otherwise glibc will choke. */
    phdrs.resize(rdi(hdr()->e_phnum) + 1);
    wri(hdr()->e_phnum, rdi(hdr()->e_phnum) + 1);
    Elf_Phdr & phdr = phdrs.at(rdi(hdr()->e_phnum) - 1);
    wri(phdr.p_type, PT_LOAD);
    wri(phdr.p_offset, 0);
    wri(phdr.p_vaddr, wri(phdr.p_paddr, startPage));
    wri(phdr.p_filesz, wri(phdr.p_memsz, shift));
    wri(phdr.p_flags, PF_R | PF_W);
    wri(phdr.p_align, getPageSize());
}


template<ElfFileParams>
std::string ElfFile<ElfFileParamNames>::getSectionName(const Elf_Shdr & shdr) const
{
    const size_t name_off = rdi(shdr.sh_name);

    if (name_off >= sectionNames.size())
        error("section name offset out of bounds");

    return std::string(sectionNames.c_str() + name_off);
}


template<ElfFileParams>
Elf_Shdr & ElfFile<ElfFileParamNames>::findSectionHeader(const SectionName & sectionName)
{
    auto shdr = tryFindSectionHeader(sectionName);
    if (!shdr) {
        std::string extraMsg;
        if (sectionName == ".interp" || sectionName == ".dynamic" || sectionName == ".dynstr")
            extraMsg = ". The input file is most likely statically linked";
        error("cannot find section '" + sectionName + "'" + extraMsg);
    }
    return *shdr;
}


template<ElfFileParams>
std::optional<std::reference_wrapper<Elf_Shdr>> ElfFile<ElfFileParamNames>::tryFindSectionHeader(const SectionName & sectionName)
{
    auto i = getSectionIndex(sectionName);
    if (i)
        return shdrs.at(i);
    return {};
}


template<ElfFileParams>
unsigned int ElfFile<ElfFileParamNames>::getSectionIndex(const SectionName & sectionName) const
{
    for (unsigned int i = 1; i < rdi(hdr()->e_shnum); ++i)
        if (getSectionName(shdrs.at(i)) == sectionName) return i;
    return 0;
}

template<ElfFileParams>
bool ElfFile<ElfFileParamNames>::haveReplacedSection(const SectionName & sectionName) const
{
    return replacedSections.count(sectionName);
}

template<ElfFileParams>
std::string & ElfFile<ElfFileParamNames>::replaceSection(const SectionName & sectionName,
    unsigned int size)
{
    auto i = replacedSections.find(sectionName);
    std::string s;

    if (i != replacedSections.end()) {
        s = std::string(i->second);
    } else {
        auto shdr = findSectionHeader(sectionName);
        s = std::string((char *) fileContents->data() + rdi(shdr.sh_offset), rdi(shdr.sh_size));
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
    for (auto & i : replacedSections) {
        const std::string & sectionName = i.first;
        Elf_Shdr & shdr = findSectionHeader(sectionName);
        if (rdi(shdr.sh_type) != SHT_NOBITS)
            memset(fileContents->data() + rdi(shdr.sh_offset), 'X', rdi(shdr.sh_size));
    }

    std::set<unsigned int> noted_phdrs = {};
    for (auto & i : replacedSections) {
        const std::string & sectionName = i.first;
        auto & shdr = findSectionHeader(sectionName);
        Elf_Shdr orig_shdr = shdr;
        debug("rewriting section '%s' from offset 0x%x (size %d) to offset 0x%x (size %d)\n",
            sectionName.c_str(), rdi(shdr.sh_offset), rdi(shdr.sh_size), curOff, i.second.size());

        memcpy(fileContents->data() + curOff, (unsigned char *) i.second.c_str(),
            i.second.size());

        /* Update the section header for this section. */
        wri(shdr.sh_offset, curOff);
        wri(shdr.sh_addr, startAddr + (curOff - startOffset));
        wri(shdr.sh_size, i.second.size());
        wri(shdr.sh_addralign, sectionAlignment);

        /* If this is the .interp section, then the PT_INTERP segment
           must be sync'ed with it. */
        if (sectionName == ".interp") {
            for (auto & phdr : phdrs) {
                if (rdi(phdr.p_type) == PT_INTERP) {
                    phdr.p_offset = shdr.sh_offset;
                    phdr.p_vaddr = phdr.p_paddr = shdr.sh_addr;
                    phdr.p_filesz = phdr.p_memsz = shdr.sh_size;
                }
            }
        }

        /* If this is the .dynamic section, then the PT_DYNAMIC segment
           must be sync'ed with it. */
        else if (sectionName == ".dynamic") {
            for (auto & phdr : phdrs) {
                if (rdi(phdr.p_type) == PT_DYNAMIC) {
                    phdr.p_offset = shdr.sh_offset;
                    phdr.p_vaddr = phdr.p_paddr = shdr.sh_addr;
                    phdr.p_filesz = phdr.p_memsz = shdr.sh_size;
                }
            }
        }

        /* If this is a note section, there might be a PT_NOTE segment that
           must be sync'ed with it. Note that normalizeNoteSegments() will have
           already taken care of PT_NOTE segments containing multiple note
           sections. At this point, we can assume that the segment will map to
           exactly one section.

           Note sections also have particular alignment constraints: the
           data inside the section is formatted differently depending on the
           section alignment. Keep the original alignment if possible. */
        if (rdi(shdr.sh_type) == SHT_NOTE) {
            if (orig_shdr.sh_addralign < sectionAlignment)
                shdr.sh_addralign = orig_shdr.sh_addralign;

            for (unsigned int j = 0; j < phdrs.size(); ++j) {
                auto &phdr = phdrs.at(j);
                if (rdi(phdr.p_type) == PT_NOTE && !noted_phdrs.count(j)) {
                    Elf_Off p_start = rdi(phdr.p_offset);
                    Elf_Off p_end = p_start + rdi(phdr.p_filesz);
                    Elf_Off s_start = rdi(orig_shdr.sh_offset);
                    Elf_Off s_end = s_start + rdi(orig_shdr.sh_size);

                    /* Skip if no overlap. */
                    if (!(s_start >= p_start && s_start < p_end) &&
                        !(s_end > p_start && s_end <= p_end))
                        continue;

                    /* We only support exact matches. */
                    if (p_start != s_start || p_end != s_end)
                        error("unsupported overlap of SHT_NOTE and PT_NOTE");

                    phdr.p_offset = shdr.sh_offset;
                    phdr.p_vaddr = phdr.p_paddr = shdr.sh_addr;
                    phdr.p_filesz = phdr.p_memsz = shdr.sh_size;

                    noted_phdrs.insert(j);
                }
            }
        }

        /* If there is .MIPS.abiflags section, then the PT_MIPS_ABIFLAGS
           segment must be sync'ed with it. */
        if (sectionName == ".MIPS.abiflags") {
            for (auto & phdr : phdrs) {
                if (rdi(phdr.p_type) == PT_MIPS_ABIFLAGS) {
                    phdr.p_offset = shdr.sh_offset;
                    phdr.p_vaddr = phdr.p_paddr = shdr.sh_addr;
                    phdr.p_filesz = phdr.p_memsz = shdr.sh_size;
                }
            }
        }

        curOff += roundUp(i.second.size(), sectionAlignment);
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
    Elf_Addr firstPage = 0;
    for (auto & phdr : phdrs) {
        Elf_Addr thisPage = roundUp(rdi(phdr.p_vaddr) + rdi(phdr.p_memsz), getPageSize());
        if (thisPage > startPage) startPage = thisPage;
        if (rdi(phdr.p_type) == PT_PHDR) firstPage = rdi(phdr.p_vaddr) - rdi(phdr.p_offset);
    }

    debug("last page is 0x%llx\n", (unsigned long long) startPage);
    debug("first page is 0x%llx\n", (unsigned long long) firstPage);

    /* When normalizing note segments we will in the worst case be adding
       1 program header for each SHT_NOTE section. */
    unsigned int num_notes = std::count_if(shdrs.begin(), shdrs.end(),
        [this](Elf_Shdr shdr) { return rdi(shdr.sh_type) == SHT_NOTE; });

    /* Because we're adding a new section header, we're necessarily increasing
       the size of the program header table.  This can cause the first section
       to overlap the program header table in memory; we need to shift the first
       few segments to someplace else. */
    /* Some sections may already be replaced so account for that */
    unsigned int i = 1;
    Elf_Addr pht_size = sizeof(Elf_Ehdr) + (phdrs.size() + num_notes + 1)*sizeof(Elf_Phdr);
    while( rdi(shdrs.at(i).sh_offset) <= pht_size && i < rdi(hdr()->e_shnum) ) {
        if (not haveReplacedSection(getSectionName(shdrs.at(i))))
            replaceSection(getSectionName(shdrs.at(i)), rdi(shdrs.at(i).sh_size));
        i++;
    }

    /* Compute the total space needed for the replaced sections */
    off_t neededSpace = 0;
    for (auto & s : replacedSections)
        neededSpace += roundUp(s.second.size(), sectionAlignment);
    debug("needed space is %d\n", neededSpace);

    Elf_Off startOffset = roundUp(fileContents->size(), getPageSize());

    fileContents->resize(startOffset + neededSpace, 0);

    /* Even though this file is of type ET_DYN, it could actually be
       an executable.  For instance, Gold produces executables marked
       ET_DYN as does LD when linking with pie. If we move PT_PHDR, it
       has to stay in the first PT_LOAD segment or any subsequent ones
       if they're continuous in memory due to linux kernel constraints
       (see BUGS). Since the end of the file would be after bss, we can't
       move PHDR there, we therefore choose to leave PT_PHDR where it is but
       move enough following sections such that we can add the extra PT_LOAD
       section to it. This PT_LOAD segment ensures the sections at the end of
       the file are mapped into memory for ld.so to process.
       We can't use the approach in rewriteSectionsExecutable()
       since DYN executables tend to start at virtual address 0, so
       rewriteSectionsExecutable() won't work because it doesn't have
       any virtual address space to grow downwards into. */
    if (isExecutable && startOffset > startPage) {
        debug("shifting new PT_LOAD segment by %d bytes to work around a Linux kernel bug\n", startOffset - startPage);
        startPage = startOffset;
    }

    /* Add a segment that maps the replaced sections into memory. */
    wri(hdr()->e_phoff, sizeof(Elf_Ehdr));
    phdrs.resize(rdi(hdr()->e_phnum) + 1);
    wri(hdr()->e_phnum, rdi(hdr()->e_phnum) + 1);
    Elf_Phdr & phdr = phdrs.at(rdi(hdr()->e_phnum) - 1);
    wri(phdr.p_type, PT_LOAD);
    wri(phdr.p_offset, startOffset);
    wri(phdr.p_vaddr, wri(phdr.p_paddr, startPage));
    wri(phdr.p_filesz, wri(phdr.p_memsz, neededSpace));
    wri(phdr.p_flags, PF_R | PF_W);
    wri(phdr.p_align, getPageSize());


    normalizeNoteSegments();


    /* Write out the replaced sections. */
    Elf_Off curOff = startOffset;
    writeReplacedSections(curOff, startPage, startOffset);
    assert(curOff == startOffset + neededSpace);

    /* Write out the updated program and section headers */
    rewriteHeaders(firstPage + rdi(hdr()->e_phoff));
}

static bool noSort = false;

template<ElfFileParams>
void ElfFile<ElfFileParamNames>::rewriteSectionsExecutable()
{
    if (!noSort) {
        /* Sort the sections by offset, otherwise we won't correctly find
           all the sections before the last replaced section. */
        sortShdrs();
    }

    /* What is the index of the last replaced section? */
    unsigned int lastReplaced = 0;
    for (unsigned int i = 1; i < rdi(hdr()->e_shnum); ++i) {
        std::string sectionName = getSectionName(shdrs.at(i));
        if (replacedSections.count(sectionName)) {
            debug("using replaced section '%s'\n", sectionName.c_str());
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
    size_t startOffset = rdi(shdrs.at(lastReplaced + 1).sh_offset);
    Elf_Addr startAddr = rdi(shdrs.at(lastReplaced + 1).sh_addr);
    std::string prevSection;
    for (unsigned int i = 1; i <= lastReplaced; ++i) {
        Elf_Shdr & shdr(shdrs.at(i));
        std::string sectionName = getSectionName(shdr);
        debug("looking at section '%s'\n", sectionName.c_str());
        /* !!! Why do we stop after a .dynstr section? I can't
           remember! */
        if ((rdi(shdr.sh_type) == SHT_PROGBITS && sectionName != ".interp")
            || prevSection == ".dynstr")
        {
            startOffset = rdi(shdr.sh_offset);
            startAddr = rdi(shdr.sh_addr);
            lastReplaced = i - 1;
            break;
        }
        if (!replacedSections.count(sectionName)) {
            debug("replacing section '%s' which is in the way\n", sectionName.c_str());
            replaceSection(sectionName, rdi(shdr.sh_size));
        }
        prevSection = std::move(sectionName);
    }

    debug("first reserved offset/addr is 0x%x/0x%llx\n",
        startOffset, (unsigned long long) startAddr);

    assert(startAddr % getPageSize() == startOffset % getPageSize());
    Elf_Addr firstPage = startAddr - startOffset;
    debug("first page is 0x%llx\n", (unsigned long long) firstPage);

    if (rdi(hdr()->e_shoff) < startOffset) {
        /* The section headers occur too early in the file and would be
           overwritten by the replaced sections. Move them to the end of the file
           before proceeding. */
        off_t shoffNew = fileContents->size();
        off_t shSize = rdi(hdr()->e_shoff) + rdi(hdr()->e_shnum) * rdi(hdr()->e_shentsize);
        fileContents->resize(fileContents->size() + shSize, 0);
        wri(hdr()->e_shoff, shoffNew);

        /* Rewrite the section header table.  For neatness, keep the
           sections sorted. */
        assert(rdi(hdr()->e_shnum) == shdrs.size());
        sortShdrs();
        for (unsigned int i = 1; i < rdi(hdr()->e_shnum); ++i)
            * ((Elf_Shdr *) (fileContents->data() + rdi(hdr()->e_shoff)) + i) = shdrs.at(i);
    }


    normalizeNoteSegments();


    /* Compute the total space needed for the replaced sections, the
       ELF header, and the program headers. */
    size_t neededSpace = sizeof(Elf_Ehdr) + phdrs.size() * sizeof(Elf_Phdr);
    for (auto & i : replacedSections)
        neededSpace += roundUp(i.second.size(), sectionAlignment);

    debug("needed space is %d\n", neededSpace);

    /* If we need more space at the start of the file, then grow the
       file by the minimum number of pages and adjust internal
       offsets. */
    if (neededSpace > startOffset) {

        /* We also need an additional program header, so adjust for that. */
        neededSpace += sizeof(Elf_Phdr);
        debug("needed space is %d\n", neededSpace);

        unsigned int neededPages = roundUp(neededSpace - startOffset, getPageSize()) / getPageSize();
        debug("needed pages is %d\n", neededPages);
        if (neededPages * getPageSize() > firstPage)
            error("virtual address space underrun!");

        firstPage -= neededPages * getPageSize();
        startOffset += neededPages * getPageSize();

        shiftFile(neededPages, firstPage);
    }


    /* Clear out the free space. */
    Elf_Off curOff = sizeof(Elf_Ehdr) + phdrs.size() * sizeof(Elf_Phdr);
    debug("clearing first %d bytes\n", startOffset - curOff);
    memset(fileContents->data() + curOff, 0, startOffset - curOff);


    /* Write out the replaced sections. */
    writeReplacedSections(curOff, firstPage, 0);
    assert(curOff == neededSpace);


    rewriteHeaders(firstPage + rdi(hdr()->e_phoff));
}


template<ElfFileParams>
void ElfFile<ElfFileParamNames>::normalizeNoteSegments()
{
    /* Break up PT_NOTE segments containing multiple SHT_NOTE sections. This
       is to avoid having to deal with moving multiple sections together if
       one of them has to be replaced. */

    /* We don't need to do anything if no note segments were replaced. */
    bool replaced_note = std::any_of(replacedSections.begin(), replacedSections.end(),
        [this](std::pair<const std::string, std::string> & i) { return rdi(findSectionHeader(i.first).sh_type) == SHT_NOTE; });
    if (!replaced_note) return;

    std::vector<Elf_Phdr> newPhdrs;
    for (auto & phdr : phdrs) {
        if (rdi(phdr.p_type) != PT_NOTE) continue;

        size_t start_off = rdi(phdr.p_offset);
        size_t curr_off = start_off;
        size_t end_off = start_off + rdi(phdr.p_filesz);
        while (curr_off < end_off) {
            /* Find a section that starts at the current offset. If we can't
               find one, it means the SHT_NOTE sections weren't contiguous
               within the segment. */
            size_t size = 0;
            for (const auto & shdr : shdrs) {
                if (rdi(shdr.sh_type) != SHT_NOTE) continue;
                if (rdi(shdr.sh_offset) != roundUp(curr_off, rdi(shdr.sh_addralign))) continue;
                size = rdi(shdr.sh_size);
                curr_off = roundUp(curr_off, rdi(shdr.sh_addralign));
                break;
            }
            if (size == 0)
                error("cannot normalize PT_NOTE segment: non-contiguous SHT_NOTE sections");
            if (curr_off + size > end_off)
                error("cannot normalize PT_NOTE segment: partially mapped SHT_NOTE section");

            /* Build a new phdr for this note section. */
            Elf_Phdr new_phdr = phdr;
            wri(new_phdr.p_offset, curr_off);
            wri(new_phdr.p_vaddr, rdi(phdr.p_vaddr) + (curr_off - start_off));
            wri(new_phdr.p_paddr, rdi(phdr.p_paddr) + (curr_off - start_off));
            wri(new_phdr.p_filesz, size);
            wri(new_phdr.p_memsz, size);

            /* If we haven't yet, reuse the existing phdr entry. Otherwise add
               a new phdr to the table. */
            if (curr_off == start_off)
                phdr = new_phdr;
            else
                newPhdrs.push_back(new_phdr);

            curr_off += size;
        }
    }
    phdrs.insert(phdrs.end(), newPhdrs.begin(), newPhdrs.end());

    wri(hdr()->e_phnum, phdrs.size());
}


template<ElfFileParams>
void ElfFile<ElfFileParamNames>::rewriteSections()
{

    if (replacedSections.empty()) return;

    for (auto & i : replacedSections)
        debug("replacing section '%s' with size %d\n",
            i.first.c_str(), i.second.size());

    if (rdi(hdr()->e_type) == ET_DYN) {
        debug("this is a dynamic library\n");
        rewriteSectionsLibrary();
    } else if (rdi(hdr()->e_type) == ET_EXEC) {
        debug("this is an executable\n");
        rewriteSectionsExecutable();
    } else error("unknown ELF type");
}


template<ElfFileParams>
void ElfFile<ElfFileParamNames>::rewriteHeaders(Elf_Addr phdrAddress)
{
    /* Rewrite the program header table. */

    /* If there is a segment for the program header table, update it.
       (According to the ELF spec, there can only be one.) */
    for (auto & phdr : phdrs) {
        if (rdi(phdr.p_type) == PT_PHDR) {
            phdr.p_offset = hdr()->e_phoff;
            wri(phdr.p_vaddr, wri(phdr.p_paddr, phdrAddress));
            wri(phdr.p_filesz, wri(phdr.p_memsz, phdrs.size() * sizeof(Elf_Phdr)));
            break;
        }
    }

    if (!noSort) {
        sortPhdrs();
    }

    for (unsigned int i = 0; i < phdrs.size(); ++i)
        * ((Elf_Phdr *) (fileContents->data() + rdi(hdr()->e_phoff)) + i) = phdrs.at(i);


    /* Rewrite the section header table.  For neatness, keep the
       sections sorted. */
    assert(rdi(hdr()->e_shnum) == shdrs.size());
    if (!noSort) {
        sortShdrs();
    }
    for (unsigned int i = 1; i < rdi(hdr()->e_shnum); ++i)
        * ((Elf_Shdr *) (fileContents->data() + rdi(hdr()->e_shoff)) + i) = shdrs.at(i);


    /* Update all those nasty virtual addresses in the .dynamic
       section.  Note that not all executables have .dynamic sections
       (e.g., those produced by klibc's klcc). */
    auto shdrDynamic = tryFindSectionHeader(".dynamic");
    if (shdrDynamic) {
        auto dyn_table = (Elf_Dyn *) (fileContents->data() + rdi((*shdrDynamic).get().sh_offset));
        unsigned int d_tag;
        for (auto dyn = dyn_table; (d_tag = rdi(dyn->d_tag)) != DT_NULL; dyn++)
            if (d_tag == DT_STRTAB)
                dyn->d_un.d_ptr = findSectionHeader(".dynstr").sh_addr;
            else if (d_tag == DT_STRSZ)
                dyn->d_un.d_val = findSectionHeader(".dynstr").sh_size;
            else if (d_tag == DT_SYMTAB)
                dyn->d_un.d_ptr = findSectionHeader(".dynsym").sh_addr;
            else if (d_tag == DT_HASH)
                dyn->d_un.d_ptr = findSectionHeader(".hash").sh_addr;
            else if (d_tag == DT_GNU_HASH) {
                auto shdr = tryFindSectionHeader(".gnu.hash");
                // some binaries might this section stripped
                // in which case we just ignore the value.
                if (shdr) dyn->d_un.d_ptr = (*shdr).get().sh_addr;
            } else if (d_tag == DT_MIPS_XHASH) {
                // the .MIPS.xhash section was added to the glibc-ABI
                // in commit 23c1c256ae7b0f010d0fcaff60682b620887b164
                dyn->d_un.d_ptr = findSectionHeader(".MIPS.xhash").sh_addr;
            } else if (d_tag == DT_JMPREL) {
                auto shdr = tryFindSectionHeader(".rel.plt");
                if (!shdr) shdr = tryFindSectionHeader(".rela.plt");
                /* 64-bit Linux, x86-64 */
                if (!shdr) shdr = tryFindSectionHeader(".rela.IA_64.pltoff"); /* 64-bit Linux, IA-64 */
                if (!shdr) error("cannot find section corresponding to DT_JMPREL");
                dyn->d_un.d_ptr = (*shdr).get().sh_addr;
            }
            else if (d_tag == DT_REL) { /* !!! hack! */
                auto shdr = tryFindSectionHeader(".rel.dyn");
                /* no idea if this makes sense, but it was needed for some
                   program */
                if (!shdr) shdr = tryFindSectionHeader(".rel.got");
                /* some programs have neither section, but this doesn't seem
                   to be a problem */
                if (!shdr) continue;
                dyn->d_un.d_ptr = (*shdr).get().sh_addr;
            }
            else if (d_tag == DT_RELA) {
                auto shdr = tryFindSectionHeader(".rela.dyn");
                /* some programs lack this section, but it doesn't seem to
                   be a problem */
                if (!shdr) continue;
                dyn->d_un.d_ptr = (*shdr).get().sh_addr;
            }
            else if (d_tag == DT_VERNEED)
                dyn->d_un.d_ptr = findSectionHeader(".gnu.version_r").sh_addr;
            else if (d_tag == DT_VERSYM)
                dyn->d_un.d_ptr = findSectionHeader(".gnu.version").sh_addr;
            else if (d_tag == DT_MIPS_RLD_MAP_REL) {
                /* the MIPS_RLD_MAP_REL tag stores the offset to the debug
                   pointer, relative to the address of the tag */
                auto shdr = tryFindSectionHeader(".rld_map");
                if (shdr) {
                    /*
                     * "When correct, (DT_MIPS_RLD_MAP_REL + tag offset + executable base address) equals DT_MIPS_RLD_MAP"
                     * -- https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=820334#5
                     *
                     * Equivalently,
                     *
                     *   DT_MIPS_RLD_MAP_REL + tag offset + executable base address == DT_MIPS_RLD_MAP
                     *   DT_MIPS_RLD_MAP_REL              + executable base address == DT_MIPS_RLD_MAP - tag_offset
                     *   DT_MIPS_RLD_MAP_REL                                        == DT_MIPS_RLD_MAP - tag_offset - executable base address
                     */
                    auto rld_map_addr = findSectionHeader(".rld_map").sh_addr;
                    auto dyn_offset = ((char*)dyn) - ((char*)dyn_table);
                    dyn->d_un.d_ptr = rld_map_addr - dyn_offset - (*shdrDynamic).get().sh_addr;
                } else {
                    /* ELF file with DT_MIPS_RLD_MAP_REL but without .rld_map
                       is broken, and it's not our job to fix it; yet, we have
                       to find some location for dynamic loader to write the
                       debug pointer to; well, let's write it right here */
                    fprintf(stderr, "warning: DT_MIPS_RLD_MAP_REL entry is present, but .rld_map section is not\n");
                    dyn->d_un.d_ptr = 0;
                }
            }
    }


    /* Rewrite the .dynsym section.  It contains the indices of the
       sections in which symbols appear, so these need to be
       remapped. */
    for (unsigned int i = 1; i < rdi(hdr()->e_shnum); ++i) {
        auto &shdr = shdrs.at(i);
        if (rdi(shdr.sh_type) != SHT_SYMTAB && rdi(shdr.sh_type) != SHT_DYNSYM) continue;
        debug("rewriting symbol table section %d\n", i);
        for (size_t entry = 0; (entry + 1) * sizeof(Elf_Sym) <= rdi(shdr.sh_size); entry++) {
            auto sym = (Elf_Sym *)(fileContents->data() + rdi(shdr.sh_offset) + entry * sizeof(Elf_Sym));
            unsigned int shndx = rdi(sym->st_shndx);
            if (shndx != SHN_UNDEF && shndx < SHN_LORESERVE) {
                if (shndx >= sectionsByOldIndex.size()) {
                    fprintf(stderr, "warning: entry %d in symbol table refers to a non-existent section, skipping\n", shndx);
                    continue;
                }
                const std::string & section = sectionsByOldIndex.at(shndx);
                assert(!section.empty());
                auto newIndex = getSectionIndex(section); // inefficient
                //debug("rewriting symbol %d: index = %d (%s) -> %d\n", entry, shndx, section.c_str(), newIndex);
                wri(sym->st_shndx, newIndex);
                /* Rewrite st_value.  FIXME: we should do this for all
                   types, but most don't actually change. */
                if (ELF32_ST_TYPE(rdi(sym->st_info)) == STT_SECTION)
                    wri(sym->st_value, rdi(shdrs.at(newIndex).sh_addr));
            }
        }
    }
}



static void setSubstr(std::string & s, unsigned int pos, const std::string & t)
{
    assert(pos + t.size() <= s.size());
    copy(t.begin(), t.end(), s.begin() + pos);
}


template<ElfFileParams>
std::string ElfFile<ElfFileParamNames>::getInterpreter()
{
    auto shdr = findSectionHeader(".interp");
    return std::string((char *) fileContents->data() + rdi(shdr.sh_offset), rdi(shdr.sh_size) - 1);
}

template<ElfFileParams>
void ElfFile<ElfFileParamNames>::modifySoname(sonameMode op, const std::string & newSoname)
{
    if (rdi(hdr()->e_type) != ET_DYN) {
        debug("this is not a dynamic library\n");
        return;
    }

    auto shdrDynamic = findSectionHeader(".dynamic");
    auto shdrDynStr = findSectionHeader(".dynstr");
    char * strTab = (char *) fileContents->data() + rdi(shdrDynStr.sh_offset);

    /* Walk through the dynamic section, look for the DT_SONAME entry. */
    auto dyn = (Elf_Dyn *)(fileContents->data() + rdi(shdrDynamic.sh_offset));
    Elf_Dyn * dynSoname = nullptr;
    char * soname = nullptr;
    for ( ; rdi(dyn->d_tag) != DT_NULL; dyn++) {
        if (rdi(dyn->d_tag) == DT_SONAME) {
            dynSoname = dyn;
            soname = strTab + rdi(dyn->d_un.d_val);
        }
    }

    if (op == printSoname) {
        if (soname) {
            if (strlen(soname) == 0)
                debug("DT_SONAME is empty\n");
            else
                printf("%s\n", soname);
        } else {
            debug("no DT_SONAME found\n");
        }
        return;
    }

    if (soname && soname == newSoname) {
        debug("current and proposed new SONAMEs are equal keeping DT_SONAME entry\n");
        return;
    }

    debug("new SONAME is '%s'\n", newSoname.c_str());

    /* Grow the .dynstr section to make room for the new SONAME. */
    debug("SONAME is too long, resizing...\n");

    std::string & newDynStr = replaceSection(".dynstr", rdi(shdrDynStr.sh_size) + newSoname.size() + 1);
    setSubstr(newDynStr, rdi(shdrDynStr.sh_size), newSoname + '\0');

    /* Update the DT_SONAME entry. */
    if (dynSoname) {
        dynSoname->d_un.d_val = shdrDynStr.sh_size;
    } else {
        /* There is no DT_SONAME entry in the .dynamic section, so we
           have to grow the .dynamic section. */
        std::string & newDynamic = replaceSection(".dynamic", rdi(shdrDynamic.sh_size) + sizeof(Elf_Dyn));

        unsigned int idx = 0;
        for (; rdi(((Elf_Dyn *) newDynamic.c_str())[idx].d_tag) != DT_NULL; idx++);
        debug("DT_NULL index is %d\n", idx);

        /* Shift all entries down by one. */
        setSubstr(newDynamic, sizeof(Elf_Dyn), std::string(newDynamic, 0, sizeof(Elf_Dyn) * (idx + 1)));

        /* Add the DT_SONAME entry at the top. */
        Elf_Dyn newDyn;
        wri(newDyn.d_tag, DT_SONAME);
        newDyn.d_un.d_val = shdrDynStr.sh_size;
        setSubstr(newDynamic, 0, std::string((char *)&newDyn, sizeof(Elf_Dyn)));
    }

    changed = true;
    this->rewriteSections();
}

template<ElfFileParams>
void ElfFile<ElfFileParamNames>::setInterpreter(const std::string & newInterpreter)
{
    std::string & section = replaceSection(".interp", newInterpreter.size() + 1);
    setSubstr(section, 0, newInterpreter + '\0');
    changed = true;
    this->rewriteSections();
}


static void appendRPath(std::string & rpath, const std::string & path)
{
    if (!rpath.empty()) rpath += ":";
    rpath += path;
}

/* For each directory in the RPATH, check if it contains any
   needed library. */
template<ElfFileParams>
std::string ElfFile<ElfFileParamNames>::shrinkRPath(char* rpath, std::vector<std::string> &neededLibs, const std::vector<std::string> & allowedRpathPrefixes) {
    std::vector<bool> neededLibFound(neededLibs.size(), false);

    std::string newRPath = "";

    for (auto & dirName : splitColonDelimitedString(rpath)) {

        /* Non-absolute entries are allowed (e.g., the special
           "$ORIGIN" hack). */
        if (dirName.size() && dirName.at(0) != '/') {
            appendRPath(newRPath, dirName);
            continue;
        }

        /* If --allowed-rpath-prefixes was given, reject directories
           not starting with any of the (colon-delimited) prefixes. */
        if (!allowedRpathPrefixes.empty() && !hasAllowedPrefix(dirName, allowedRpathPrefixes)) {
            debug("removing directory '%s' from RPATH because of non-allowed prefix\n", dirName.c_str());
            continue;
        }

        /* For each library that we haven't found yet, see if it
           exists in this directory. */
        bool libFound = false;
        for (unsigned int j = 0; j < neededLibs.size(); ++j)
            if (!neededLibFound.at(j)) {
                std::string libName = dirName + "/" + neededLibs.at(j);
                try {
                    Elf32_Half library_e_machine = getElfType(readFile(libName, sizeof(Elf32_Ehdr))).machine;
                    if (rdi(library_e_machine) == rdi(hdr()->e_machine)) {
                        neededLibFound.at(j) = true;
                        libFound = true;
                    } else
                        debug("ignoring library '%s' because its machine type differs\n", libName.c_str());
                } catch (SysError & e) {
                    if (e.errNo != ENOENT) throw;
                }
            }

        if (!libFound)
            debug("removing directory '%s' from RPATH\n", dirName.c_str());
        else
            appendRPath(newRPath, dirName);
    }

    return newRPath;
}

template<ElfFileParams>
void ElfFile<ElfFileParamNames>::removeRPath(Elf_Shdr & shdrDynamic) {
    auto dyn = (Elf_Dyn *)(fileContents->data() + rdi(shdrDynamic.sh_offset));
    Elf_Dyn * last = dyn;
    for ( ; rdi(dyn->d_tag) != DT_NULL; dyn++) {
        if (rdi(dyn->d_tag) == DT_RPATH) {
            debug("removing DT_RPATH entry\n");
            changed = true;
        } else if (rdi(dyn->d_tag) == DT_RUNPATH) {
            debug("removing DT_RUNPATH entry\n");
            changed = true;
        } else {
            *last++ = *dyn;
        }
    }
    memset(last, 0, sizeof(Elf_Dyn) * (dyn - last));
    this->rewriteSections();
}

template<ElfFileParams>
void ElfFile<ElfFileParamNames>::modifyRPath(RPathOp op,
    const std::vector<std::string> & allowedRpathPrefixes, std::string newRPath)
{
    auto shdrDynamic = findSectionHeader(".dynamic");

    if (rdi(shdrDynamic.sh_type) == SHT_NOBITS) {
            debug("no dynamic section\n");
            return;
    }

    /* !!! We assume that the virtual address in the DT_STRTAB entry
       of the dynamic section corresponds to the .dynstr section. */
    auto shdrDynStr = findSectionHeader(".dynstr");
    char * strTab = (char *) fileContents->data() + rdi(shdrDynStr.sh_offset);


    /* Walk through the dynamic section, look for the RPATH/RUNPATH
       entry.

       According to the ld.so docs, DT_RPATH is obsolete, we should
       use DT_RUNPATH.  DT_RUNPATH has two advantages: it can be
       overriden by LD_LIBRARY_PATH, and it's scoped (the DT_RUNPATH
       for an executable or library doesn't affect the search path for
       libraries used by it).  DT_RPATH is ignored if DT_RUNPATH is
       present.  The binutils 'ld' still generates only DT_RPATH,
       unless you use its '--enable-new-dtag' option, in which case it
       generates a DT_RPATH and DT_RUNPATH pointing at the same
       string. */
    std::vector<std::string> neededLibs;
    auto dyn = (Elf_Dyn *)(fileContents->data() + rdi(shdrDynamic.sh_offset));
    Elf_Dyn *dynRPath = nullptr, *dynRunPath = nullptr;
    char * rpath = nullptr;
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
            neededLibs.push_back(std::string(strTab + rdi(dyn->d_un.d_val)));
    }

    switch (op) {
        case rpPrint: {
            printf("%s\n", rpath ? rpath : "");
            return;
        };
        case rpRemove: {
            if (!rpath) {
                debug("no RPATH to delete\n");
                return;
            }
            removeRPath(shdrDynamic);
            return;
        }
        case rpShrink: {
            if (!rpath) {
                debug("no RPATH to shrink\n");
                return;
            ;}
            newRPath = shrinkRPath(rpath, neededLibs, allowedRpathPrefixes);
            break;
        }
        case rpAdd: {
            auto temp = std::string(rpath ? rpath : "");
            appendRPath(temp, newRPath);
            newRPath = temp;
            break;
        }
        case rpSet: { break; } /* new rpath was provied as input to this function */
    }

    if (!forceRPath && dynRPath && !dynRunPath) { /* convert DT_RPATH to DT_RUNPATH */
        wri(dynRPath->d_tag, DT_RUNPATH);
        dynRunPath = dynRPath;
        dynRPath = nullptr;
        changed = true;
    } else if (forceRPath && dynRunPath) { /* convert DT_RUNPATH to DT_RPATH */
        wri(dynRunPath->d_tag, DT_RPATH);
        dynRPath = dynRunPath;
        dynRunPath = nullptr;
        changed = true;
    }

    if (rpath && rpath == newRPath) {
        return;
    }
    changed = true;

    /* Zero out the previous rpath to prevent retained dependencies in
       Nix. */
    size_t rpathSize = 0;
    if (rpath) {
        rpathSize = strlen(rpath);
        memset(rpath, 'X', rpathSize);
    }

    debug("new rpath is '%s'\n", newRPath.c_str());


    if (newRPath.size() <= rpathSize) {
        if (rpath) memcpy(rpath, newRPath.c_str(), newRPath.size() + 1);
        return;
    }

    /* Grow the .dynstr section to make room for the new RPATH. */
    debug("rpath is too long, resizing...\n");

    std::string & newDynStr = replaceSection(".dynstr",
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
        std::string & newDynamic = replaceSection(".dynamic",
            rdi(shdrDynamic.sh_size) + sizeof(Elf_Dyn));

        unsigned int idx = 0;
        for ( ; rdi(((Elf_Dyn *) newDynamic.c_str())[idx].d_tag) != DT_NULL; idx++) ;
        debug("DT_NULL index is %d\n", idx);

        /* Shift all entries down by one. */
        setSubstr(newDynamic, sizeof(Elf_Dyn),
            std::string(newDynamic, 0, sizeof(Elf_Dyn) * (idx + 1)));

        /* Add the DT_RUNPATH entry at the top. */
        Elf_Dyn newDyn;
        wri(newDyn.d_tag, forceRPath ? DT_RPATH : DT_RUNPATH);
        newDyn.d_un.d_val = shdrDynStr.sh_size;
        setSubstr(newDynamic, 0, std::string((char *) &newDyn, sizeof(Elf_Dyn)));
    }
    this->rewriteSections();
}


template<ElfFileParams>
void ElfFile<ElfFileParamNames>::removeNeeded(const std::set<std::string> & libs)
{
    if (libs.empty()) return;

    auto shdrDynamic = findSectionHeader(".dynamic");
    auto shdrDynStr = findSectionHeader(".dynstr");
    char * strTab = (char *) fileContents->data() + rdi(shdrDynStr.sh_offset);

    auto dyn = (Elf_Dyn *)(fileContents->data() + rdi(shdrDynamic.sh_offset));
    Elf_Dyn * last = dyn;
    for ( ; rdi(dyn->d_tag) != DT_NULL; dyn++) {
        if (rdi(dyn->d_tag) == DT_NEEDED) {
            char * name = strTab + rdi(dyn->d_un.d_val);
            if (libs.count(name)) {
                debug("removing DT_NEEDED entry '%s'\n", name);
                changed = true;
            } else {
                debug("keeping DT_NEEDED entry '%s'\n", name);
                *last++ = *dyn;
            }
        } else
            *last++ = *dyn;
    }

    memset(last, 0, sizeof(Elf_Dyn) * (dyn - last));

    this->rewriteSections();
}

template<ElfFileParams>
void ElfFile<ElfFileParamNames>::replaceNeeded(const std::map<std::string, std::string> & libs)
{
    if (libs.empty()) return;

    auto shdrDynamic = findSectionHeader(".dynamic");
    auto shdrDynStr = findSectionHeader(".dynstr");
    char * strTab = (char *) fileContents->data() + rdi(shdrDynStr.sh_offset);

    auto dyn = (Elf_Dyn *)(fileContents->data() + rdi(shdrDynamic.sh_offset));

    unsigned int verNeedNum = 0;

    unsigned int dynStrAddedBytes = 0;
    std::unordered_map<std::string, Elf_Off> addedStrings;

    for ( ; rdi(dyn->d_tag) != DT_NULL; dyn++) {
        if (rdi(dyn->d_tag) == DT_NEEDED) {
            char * name = strTab + rdi(dyn->d_un.d_val);
            auto i = libs.find(name);
            if (i != libs.end() && name != i->second) {
                auto replacement = i->second;

                debug("replacing DT_NEEDED entry '%s' with '%s'\n", name, replacement.c_str());

                auto a = addedStrings.find(replacement);
                // the same replacement string has already been added, reuse it
                if (a != addedStrings.end()) {
                    wri(dyn->d_un.d_val, a->second);
                    continue;
                }

                // technically, the string referred by d_val could be used otherwise, too (although unlikely)
                // we'll therefore add a new string
                debug("resizing .dynstr ...\n");

                // relative location of the new string
                Elf_Off strOffset = rdi(shdrDynStr.sh_size) + dynStrAddedBytes;
                std::string & newDynStr = replaceSection(".dynstr",
                    strOffset + replacement.size() + 1);
                setSubstr(newDynStr, strOffset, replacement + '\0');

                wri(dyn->d_un.d_val, strOffset);
                addedStrings[replacement] = strOffset;

                dynStrAddedBytes += replacement.size() + 1;

                changed = true;
            } else {
                debug("keeping DT_NEEDED entry '%s'\n", name);
            }
        }
        if (rdi(dyn->d_tag) == DT_VERNEEDNUM) {
            verNeedNum = rdi(dyn->d_un.d_val);
        }
    }

    // If a replaced library uses symbol versions, then there will also be
    // references to it in the "version needed" table, and these also need to
    // be replaced.

    if (verNeedNum) {
        auto shdrVersionR = findSectionHeader(".gnu.version_r");
        // The filename strings in the .gnu.version_r are different from the
        // ones in .dynamic: instead of being in .dynstr, they're in some
        // arbitrary section and we have to look in ->sh_link to figure out
        // which one.
        Elf_Shdr & shdrVersionRStrings = shdrs.at(rdi(shdrVersionR.sh_link));
        // this is where we find the actual filename strings
        char * verStrTab = (char *) fileContents->data() + rdi(shdrVersionRStrings.sh_offset);
        // and we also need the name of the section containing the strings, so
        // that we can pass it to replaceSection
        std::string versionRStringsSName = getSectionName(shdrVersionRStrings);

        debug("found .gnu.version_r with %i entries, strings in %s\n", verNeedNum, versionRStringsSName.c_str());

        unsigned int verStrAddedBytes = 0;
        // It may be that it is .dynstr again, in which case we must take the already
        // added bytes into account.
        if (versionRStringsSName == ".dynstr")
            verStrAddedBytes += dynStrAddedBytes;
        else
            // otherwise the already added strings can't be reused
            addedStrings.clear();

        auto need = (Elf_Verneed *)(fileContents->data() + rdi(shdrVersionR.sh_offset));
        while (verNeedNum > 0) {
            char * file = verStrTab + rdi(need->vn_file);
            auto i = libs.find(file);
            if (i != libs.end() && file != i->second) {
                auto replacement = i->second;

                debug("replacing .gnu.version_r entry '%s' with '%s'\n", file, replacement.c_str());

                auto a = addedStrings.find(replacement);
                // the same replacement string has already been added, reuse it
                if (a != addedStrings.end()) {
                    wri(need->vn_file, a->second);
                } else {
                    debug("resizing string section %s ...\n", versionRStringsSName.c_str());

                    Elf_Off strOffset = rdi(shdrVersionRStrings.sh_size) + verStrAddedBytes;
                    std::string & newVerDynStr = replaceSection(versionRStringsSName,
                        strOffset + replacement.size() + 1);
                    setSubstr(newVerDynStr, strOffset, replacement + '\0');

                    wri(need->vn_file, strOffset);
                    addedStrings[replacement] = strOffset;

                    verStrAddedBytes += replacement.size() + 1;
                }

                changed = true;
            } else {
                debug("keeping .gnu.version_r entry '%s'\n", file);
            }
            // the Elf_Verneed structures form a linked list, so jump to next entry
            need = (Elf_Verneed *) (((char *) need) + rdi(need->vn_next));
            --verNeedNum;
        }
    }

    this->rewriteSections();
}

template<ElfFileParams>
void ElfFile<ElfFileParamNames>::addNeeded(const std::set<std::string> & libs)
{
    if (libs.empty()) return;

    auto shdrDynamic = findSectionHeader(".dynamic");
    auto shdrDynStr = findSectionHeader(".dynstr");

    unsigned int length = 0;

    /* add all new libs to the dynstr string table */
    for (auto &lib : libs)
        length += lib.size() + 1;

    std::string & newDynStr = replaceSection(".dynstr",
        rdi(shdrDynStr.sh_size) + length + 1);

    std::set<Elf64_Xword> libStrings;
    unsigned int pos = 0;
    for (auto & i : libs) {
        setSubstr(newDynStr, rdi(shdrDynStr.sh_size) + pos, i + '\0');
        libStrings.insert(rdi(shdrDynStr.sh_size) + pos);
        pos += i.size() + 1;
    }

    /* add all new needed entries to the dynamic section */
    std::string & newDynamic = replaceSection(".dynamic",
        rdi(shdrDynamic.sh_size) + sizeof(Elf_Dyn) * libs.size());

    unsigned int idx = 0;
    for ( ; rdi(((Elf_Dyn *) newDynamic.c_str())[idx].d_tag) != DT_NULL; idx++) ;
    debug("DT_NULL index is %d\n", idx);

    /* Shift all entries down by the number of new entries. */
    setSubstr(newDynamic, sizeof(Elf_Dyn) * libs.size(),
        std::string(newDynamic, 0, sizeof(Elf_Dyn) * (idx + 1)));

    /* Add the DT_NEEDED entries at the top. */
    unsigned int i = 0;
    for (auto & j : libStrings) {
        Elf_Dyn newDyn;
        wri(newDyn.d_tag, DT_NEEDED);
        wri(newDyn.d_un.d_val, j);
        setSubstr(newDynamic, i * sizeof(Elf_Dyn), std::string((char *) &newDyn, sizeof(Elf_Dyn)));
        i++;
    }

    changed = true;

    this->rewriteSections();
}

template<ElfFileParams>
void ElfFile<ElfFileParamNames>::printNeededLibs() // const
{
    const auto shdrDynamic = findSectionHeader(".dynamic");
    const auto shdrDynStr = findSectionHeader(".dynstr");
    const char *strTab = (char *)fileContents->data() + rdi(shdrDynStr.sh_offset);

    const Elf_Dyn *dyn = (Elf_Dyn *) (fileContents->data() + rdi(shdrDynamic.sh_offset));

    for (; rdi(dyn->d_tag) != DT_NULL; dyn++) {
        if (rdi(dyn->d_tag) == DT_NEEDED) {
            const char *name = strTab + rdi(dyn->d_un.d_val);
            printf("%s\n", name);
        }
    }
}


template<ElfFileParams>
void ElfFile<ElfFileParamNames>::noDefaultLib()
{
    auto shdrDynamic = findSectionHeader(".dynamic");

    auto dyn = (Elf_Dyn *)(fileContents->data() + rdi(shdrDynamic.sh_offset));
    auto dynFlags1 = (Elf_Dyn *)nullptr;
    for ( ; rdi(dyn->d_tag) != DT_NULL; dyn++) {
        if (rdi(dyn->d_tag) == DT_FLAGS_1) {
            dynFlags1 = dyn;
            break;
        }
    }
    if (dynFlags1) {
        if (dynFlags1->d_un.d_val & DF_1_NODEFLIB)
            return;
        dynFlags1->d_un.d_val |= DF_1_NODEFLIB;
    } else {
        std::string & newDynamic = replaceSection(".dynamic",
                rdi(shdrDynamic.sh_size) + sizeof(Elf_Dyn));

        unsigned int idx = 0;
        for ( ; rdi(((Elf_Dyn *) newDynamic.c_str())[idx].d_tag) != DT_NULL; idx++) ;
        debug("DT_NULL index is %d\n", idx);

        /* Shift all entries down by one. */
        setSubstr(newDynamic, sizeof(Elf_Dyn),
                std::string(newDynamic, 0, sizeof(Elf_Dyn) * (idx + 1)));

        /* Add the DT_FLAGS_1 entry at the top. */
        Elf_Dyn newDyn;
        wri(newDyn.d_tag, DT_FLAGS_1);
        newDyn.d_un.d_val = DF_1_NODEFLIB;
        setSubstr(newDynamic, 0, std::string((char *) &newDyn, sizeof(Elf_Dyn)));
    }

    this->rewriteSections();
    changed = true;
}

template<ElfFileParams>
void ElfFile<ElfFileParamNames>::addDebugTag()
{
    auto shdrDynamic = findSectionHeader(".dynamic");

    auto dyn = (Elf_Dyn *)(fileContents->data() + rdi(shdrDynamic.sh_offset));
    for ( ; rdi(dyn->d_tag) != DT_NULL; dyn++) {
        if (rdi(dyn->d_tag) == DT_DEBUG) {
            return;
        }
    }
    std::string & newDynamic = replaceSection(".dynamic",
            rdi(shdrDynamic.sh_size) + sizeof(Elf_Dyn));

    unsigned int idx = 0;
    for ( ; rdi(((Elf_Dyn *) newDynamic.c_str())[idx].d_tag) != DT_NULL; idx++) ;
    debug("DT_NULL index is %d\n", idx);

    /* Shift all entries down by one. */
    setSubstr(newDynamic, sizeof(Elf_Dyn),
            std::string(newDynamic, 0, sizeof(Elf_Dyn) * (idx + 1)));

    /* Add the DT_DEBUG entry at the top. */
    Elf_Dyn newDyn;
    wri(newDyn.d_tag, DT_DEBUG);
    newDyn.d_un.d_val = 0;
    setSubstr(newDynamic, 0, std::string((char *) &newDyn, sizeof(Elf_Dyn)));

    this->rewriteSections();
    changed = true;
}

template<ElfFileParams>
void ElfFile<ElfFileParamNames>::clearSymbolVersions(const std::set<std::string> & syms)
{
    if (syms.empty()) return;

    auto shdrDynStr = findSectionHeader(".dynstr");
    auto shdrDynsym = findSectionHeader(".dynsym");
    auto shdrVersym = findSectionHeader(".gnu.version");

    auto strTab = (char *)fileContents->data() + rdi(shdrDynStr.sh_offset);
    auto dynsyms = (Elf_Sym *)(fileContents->data() + rdi(shdrDynsym.sh_offset));
    auto versyms = (Elf_Versym *)(fileContents->data() + rdi(shdrVersym.sh_offset));
    size_t count = rdi(shdrDynsym.sh_size) / sizeof(Elf_Sym);

    if (count != rdi(shdrVersym.sh_size) / sizeof(Elf_Versym))
        error("versym size mismatch");

    for (size_t i = 0; i < count; i++) {
        auto dynsym = dynsyms[i];
        auto name = strTab + rdi(dynsym.st_name);
        if (syms.count(name)) {
            debug("clearing symbol version for %s\n", name);
            wri(versyms[i], 1);
        }
    }
    changed = true;
    this->rewriteSections();
}

static bool printInterpreter = false;
static bool printSoname = false;
static bool setSoname = false;
static std::string newSoname;
static std::string newInterpreter;
static bool shrinkRPath = false;
static std::vector<std::string> allowedRpathPrefixes;
static bool removeRPath = false;
static bool setRPath = false;
static bool addRPath = false;
static bool addDebugTag = false;
static bool printRPath = false;
static std::string newRPath;
static std::set<std::string> neededLibsToRemove;
static std::map<std::string, std::string> neededLibsToReplace;
static std::set<std::string> neededLibsToAdd;
static std::set<std::string> symbolsToClearVersion;
static bool printNeeded = false;
static bool noDefaultLib = false;

template<class ElfFile>
static void patchElf2(ElfFile && elfFile, const FileContents & fileContents, const std::string & fileName)
{
    if (printInterpreter)
        printf("%s\n", elfFile.getInterpreter().c_str());

    if (printSoname)
        elfFile.modifySoname(elfFile.printSoname, "");

    if (setSoname)
        elfFile.modifySoname(elfFile.replaceSoname, newSoname);

    if (!newInterpreter.empty())
        elfFile.setInterpreter(newInterpreter);

    if (printRPath)
        elfFile.modifyRPath(elfFile.rpPrint, {}, "");

    if (shrinkRPath)
        elfFile.modifyRPath(elfFile.rpShrink, allowedRpathPrefixes, "");
    else if (removeRPath)
        elfFile.modifyRPath(elfFile.rpRemove, {}, "");
    else if (setRPath)
        elfFile.modifyRPath(elfFile.rpSet, {}, newRPath);
    else if (addRPath)
        elfFile.modifyRPath(elfFile.rpAdd, {}, newRPath);

    if (printNeeded) elfFile.printNeededLibs();

    elfFile.removeNeeded(neededLibsToRemove);
    elfFile.replaceNeeded(neededLibsToReplace);
    elfFile.addNeeded(neededLibsToAdd);
    elfFile.clearSymbolVersions(symbolsToClearVersion);

    if (noDefaultLib)
        elfFile.noDefaultLib();

    if (addDebugTag)
        elfFile.addDebugTag();

    if (elfFile.isChanged()){
        writeFile(fileName, elfFile.fileContents);
    } else if (alwaysWrite) {
        debug("not modified, but alwaysWrite=true\n");
        writeFile(fileName, fileContents);
    }
}


static void patchElf()
{
    for (const auto & fileName : fileNames) {
        if (!printInterpreter && !printRPath && !printSoname && !printNeeded)
            debug("patching ELF file '%s'\n", fileName.c_str());

        auto fileContents = readFile(fileName);
        const std::string & outputFileName2 = outputFileName.empty() ? fileName : outputFileName;

        if (getElfType(fileContents).is32Bit)
            patchElf2(ElfFile<Elf32_Ehdr, Elf32_Phdr, Elf32_Shdr, Elf32_Addr, Elf32_Off, Elf32_Dyn, Elf32_Sym, Elf32_Verneed, Elf32_Versym>(fileContents), fileContents, outputFileName2);
        else
            patchElf2(ElfFile<Elf64_Ehdr, Elf64_Phdr, Elf64_Shdr, Elf64_Addr, Elf64_Off, Elf64_Dyn, Elf64_Sym, Elf64_Verneed, Elf64_Versym>(fileContents), fileContents, outputFileName2);
    }
}

std::string resolveArgument(const char *arg) {
  if (strlen(arg) > 0 && arg[0] == '@') {
    FileContents cnts = readFile(arg + 1);
    return std::string((char *)cnts->data(), cnts->size());
  }

  return std::string(arg);
}


void showHelp(const std::string & progName)
{
        fprintf(stderr, "syntax: %s\n\
  [--set-interpreter FILENAME]\n\
  [--page-size SIZE]\n\
  [--print-interpreter]\n\
  [--print-soname]\t\tPrints 'DT_SONAME' entry of .dynamic section. Raises an error if DT_SONAME doesn't exist\n\
  [--set-soname SONAME]\t\tSets 'DT_SONAME' entry to SONAME.\n\
  [--set-rpath RPATH]\n\
  [--add-rpath RPATH]\n\
  [--remove-rpath]\n\
  [--shrink-rpath]\n\
  [--allowed-rpath-prefixes PREFIXES]\t\tWith '--shrink-rpath', reject rpath entries not starting with the allowed prefix\n\
  [--print-rpath]\n\
  [--force-rpath]\n\
  [--add-needed LIBRARY]\n\
  [--remove-needed LIBRARY]\n\
  [--replace-needed LIBRARY NEW_LIBRARY]\n\
  [--print-needed]\n\
  [--no-default-lib]\n\
  [--no-sort]\t\tDo not sort program+section headers; useful for debugging patchelf.\n\
  [--clear-symbol-version SYMBOL]\n\
  [--add-debug-tag]\n\
  [--output FILE]\n\
  [--debug]\n\
  [--version]\n\
  FILENAME...\n", progName.c_str());
}


int mainWrapped(int argc, char * * argv)
{
    if (argc <= 1) {
        showHelp(argv[0]);
        return 1;
    }

    if (getenv("PATCHELF_DEBUG") != nullptr)
        debugMode = true;

    int i;
    for (i = 1; i < argc; ++i) {
        std::string arg(argv[i]);
        if (arg == "--set-interpreter" || arg == "--interpreter") {
            if (++i == argc) error("missing argument");
            newInterpreter = resolveArgument(argv[i]);
        }
        else if (arg == "--page-size") {
            if (++i == argc) error("missing argument");
            forcedPageSize = atoi(argv[i]);
            if (forcedPageSize <= 0) error("invalid argument to --page-size");
        }
        else if (arg == "--print-interpreter") {
            printInterpreter = true;
        }
        else if (arg == "--print-soname") {
            printSoname = true;
        }
        else if (arg == "--set-soname") {
            if (++i == argc) error("missing argument");
            setSoname = true;
            newSoname = resolveArgument(argv[i]);
        }
        else if (arg == "--remove-rpath") {
            removeRPath = true;
        }
        else if (arg == "--shrink-rpath") {
            shrinkRPath = true;
        }
        else if (arg == "--allowed-rpath-prefixes") {
            if (++i == argc) error("missing argument");
            allowedRpathPrefixes = splitColonDelimitedString(argv[i]);
        }
        else if (arg == "--set-rpath") {
            if (++i == argc) error("missing argument");
            setRPath = true;
            newRPath = resolveArgument(argv[i]);
        }
        else if (arg == "--add-rpath") {
            if (++i == argc) error("missing argument");
            addRPath = true;
            newRPath = resolveArgument(argv[i]);
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
        else if (arg == "--print-needed") {
            printNeeded = true;
        }
        else if (arg == "--no-sort") {
            noSort = true;
        }
        else if (arg == "--add-needed") {
            if (++i == argc) error("missing argument");
            neededLibsToAdd.insert(resolveArgument(argv[i]));
        }
        else if (arg == "--remove-needed") {
            if (++i == argc) error("missing argument");
            neededLibsToRemove.insert(resolveArgument(argv[i]));
        }
        else if (arg == "--replace-needed") {
            if (i+2 >= argc) error("missing argument(s)");
            neededLibsToReplace[ argv[i+1] ] = argv[i+2];
            i += 2;
        }
        else if (arg == "--clear-symbol-version") {
            if (++i == argc) error("missing argument");
            symbolsToClearVersion.insert(resolveArgument(argv[i]));
        }
        else if (arg == "--output") {
            if (++i == argc) error("missing argument");
            outputFileName = resolveArgument(argv[i]);
            alwaysWrite = true;
        }
        else if (arg == "--debug") {
            debugMode = true;
        }
        else if (arg == "--no-default-lib") {
            noDefaultLib = true;
        }
        else if (arg == "--add-debug-tag") {
            addDebugTag = true;
        }
        else if (arg == "--help" || arg == "-h" ) {
            showHelp(argv[0]);
            return 0;
        }
        else if (arg == "--version") {
            printf(PACKAGE_STRING "\n");
            return 0;
        }
        else {
            fileNames.push_back(arg);
        }
    }

    if (fileNames.empty()) error("missing filename");

    if (!outputFileName.empty() && fileNames.size() != 1)
        error("--output option only allowed with single input file");

    if (setRPath && addRPath)
        error("--set-rpath option not allowed with --add-rpath");

    patchElf();

    return 0;
}

int main(int argc, char * * argv)
{
    try {
        return mainWrapped(argc, argv);
    } catch (std::exception & e) {
        fprintf(stderr, "patchelf: %s\n", e.what());
        return 1;
    }
}
