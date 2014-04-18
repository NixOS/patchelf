/*
 *  PatchELF is a simple utility for modifing existing ELF executables
 *  and libraries.
 *
 *  Copyright (c) 2004-2014  Eelco Dolstra <eelco.dolstra@logicblox.com>
 *                2011       Zack Weinberg
 *                2013       rgcjonas
 *                2014       djcj <djcj@gmx.de>
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or (at
 *  your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#define COPYRIGHT \
"Copyright (c) 2004-2014  Eelco Dolstra <eelco.dolstra@logicblox.com>\n\
              2011       Zack Weinberg\n\
              2013       rgcjonas\n\
              2014       djcj <djcj@gmx.de>\n"

#define LICENSE "This program is free software; you may redistribute it under the terms of\n\
the GNU General Public License version 3 or (at your option) any later version.\n\
This program has absolutely no warranty.\n"


#include <assert.h>
#include <algorithm>
#include <errno.h>
/*
 *  You can find the latest elf.h here if you need it:
 *   http://www.gnu.org/software/libc/index.html
 *   https://sourceware.org/git/?p=glibc.git;a=blob;f=elf/elf.h;hb=HEAD
 *
 *  Download it and place it in the directory of patchelf.cpp and
 *  replace the line    #include <elf.h>    with    #include "elf.h"
 */
#include <elf.h>
#include <fcntl.h>

#include <fstream>
#include <functional>
#include <iostream>
#include <limits.h>
#include <map>

#include <set>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <vector>


using namespace std;


#ifdef MIPSEL
/* The lemote fuloong 2f kernel defconfig sets a page size of 16KB */
const unsigned int pageSize = 4096*4;
#else
const unsigned int pageSize = 4096;
#endif


static bool debugMode = false;

static bool debugModeFull = false;

static bool forceRPath = false;

static bool goldSupport = false;

static string fileName;


off_t fileSize, maxSize;
unsigned char * contents = 0;


#define ElfFileParams class Elf_Ehdr, class Elf_Phdr, class Elf_Shdr, class Elf_Addr, class Elf_Off, class Elf_Dyn, class Elf_Sym
#define ElfFileParamNames Elf_Ehdr, Elf_Phdr, Elf_Shdr, Elf_Addr, Elf_Off, Elf_Dyn, Elf_Sym


template<ElfFileParams>
class ElfFile
{
    Elf_Ehdr * hdr;
    vector<Elf_Phdr> phdrs;
    vector<Elf_Shdr> shdrs;

    bool littleEndian;

    bool changed;

    bool isExecutable;

    typedef string SectionName;

    typedef map<SectionName, string> ReplacedSections;

    ReplacedSections replacedSections;

    string sectionNames; /* content of the .shstrtab section */

    /* Align on 4 or 8 bytes boundaries on 32- or 64-bit platforms
       respectively. */
    unsigned int sectionAlignment;

    vector<SectionName> sectionsByOldIndex;

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

    typedef enum { rpPrint, rpType, rpShrink, rpSet, rpDelete,
        rpConvert } RPathOp;

    void modifyRPath(RPathOp op, string newRPath);

    typedef enum { addNeeded, removeNeeded } neededOp;

    void addRemoveNeeded(neededOp op, set<string> libs);

    void replaceNeeded(map<string, string> & libs);

    typedef enum { printSoname, replaceSoname } sonameMode;

    void modifySoname(sonameMode op, const string & sonameToReplace);

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
        t = rdi((I) i);
        return i;
    }
};


static bool saveBackup = false;

static bool printInterpreter = false;
static string newInterpreter;

static bool shrinkRPath = false;
static bool setRPath = false;
static bool printRPath = false;
static bool printRPathType = false;
static string newRPath;
static bool deleteRPath = false;
static bool convertRPath = false;

static set<string> neededLibsToRemove;
static map<string, string> neededLibsToReplace;
static set<string> neededLibsToAdd;

static string sonameToReplace;
static bool printSoname = false;

