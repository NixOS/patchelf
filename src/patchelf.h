using FileContents = std::shared_ptr<std::vector<unsigned char>>;

#define ElfFileParams class Elf_Ehdr, class Elf_Phdr, class Elf_Shdr, class Elf_Addr, class Elf_Off, class Elf_Dyn, class Elf_Sym, class Elf_Verneed, class Elf_Versym, class Elf_Rel, class Elf_Rela, unsigned ElfClass
#define ElfFileParamNames Elf_Ehdr, Elf_Phdr, Elf_Shdr, Elf_Addr, Elf_Off, Elf_Dyn, Elf_Sym, Elf_Verneed, Elf_Versym, Elf_Rel, Elf_Rela, ElfClass

template<class T>
struct span
{
    explicit span(T* d = {}, size_t l = {}) : data(d), len(l) {}
    span(T* from, T* to) : data(from), len(to-from) { assert(from <= to); }
    T& operator[](std::size_t i) { checkRange(i); return data[i]; }
    T* begin() { return data; }
    T* end() { return data + len; }
    auto size() const { return len; }
    explicit operator bool() const { return size() > 0; }

private:
    void checkRange(std::size_t i)
    {
        bool oor = i >= size();
        assert(!oor);
        if (oor) throw std::out_of_range("error: Access out of range.");
    }
    T* data;
    size_t len;
};

template<ElfFileParams>
class ElfFile
{
public:

    const FileContents fileContents;

private:

    std::vector<Elf_Phdr> phdrs;
    std::vector<Elf_Shdr> shdrs;

    bool littleEndian;

    bool changed = false;

    bool isExecutable = false;

    using SectionName = std::string;
    using ReplacedSections = std::map<SectionName, std::string>;

    ReplacedSections replacedSections;

    std::string sectionNames; /* content of the .shstrtab section */

    /* Align on 4 or 8 bytes boundaries on 32- or 64-bit platforms
       respectively. */
    size_t sectionAlignment = sizeof(Elf_Off);

    std::vector<SectionName> sectionsByOldIndex;

public:
    explicit ElfFile(FileContents fileContents);

    bool isChanged()
    {
        return changed;
    }

private:

    struct CompPhdr
    {
        ElfFile * elfFile;
        bool operator ()(const Elf_Phdr & x, const Elf_Phdr & y)
        {
            // A PHDR comes before everything else.
            if (elfFile->rdi(y.p_type) == PT_PHDR) return false;
            if (elfFile->rdi(x.p_type) == PT_PHDR) return true;

            // Sort non-PHDRs by address.
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

    unsigned int getPageSize() const;

    void sortShdrs();

    void shiftFile(unsigned int extraPages, size_t sizeOffset, size_t extraBytes);

    std::string getSectionName(const Elf_Shdr & shdr) const;

    Elf_Shdr & findSectionHeader(const SectionName & sectionName);

    std::optional<std::reference_wrapper<Elf_Shdr>> tryFindSectionHeader(const SectionName & sectionName);

    template<class T> span<T> getSectionSpan(const Elf_Shdr & shdr) const;
    template<class T> span<T> getSectionSpan(const SectionName & sectionName);
    template<class T> span<T> tryGetSectionSpan(const SectionName & sectionName);

    unsigned int getSectionIndex(const SectionName & sectionName);

    std::string & replaceSection(const SectionName & sectionName,
        unsigned int size);

    bool haveReplacedSection(const SectionName & sectionName) const;

    void writeReplacedSections(Elf_Off & curOff,
        Elf_Addr startAddr, Elf_Off startOffset);

    void rewriteHeaders(Elf_Addr phdrAddress);

    void rewriteSectionsLibrary();

    void rewriteSectionsExecutable();

    void normalizeNoteSegments();

public:

    void rewriteSections(bool force = false);

    std::string getInterpreter();

    typedef enum { printOsAbi, replaceOsAbi } osAbiMode;

    void modifyOsAbi(osAbiMode op, const std::string & newOsAbi);

    typedef enum { printSoname, replaceSoname } sonameMode;

    void modifySoname(sonameMode op, const std::string & newSoname);

    void setInterpreter(const std::string & newInterpreter);

    typedef enum { rpPrint, rpShrink, rpSet, rpAdd, rpRemove } RPathOp;

    void modifyRPath(RPathOp op, const std::vector<std::string> & allowedRpathPrefixes, std::string newRPath);
    std::string shrinkRPath(char* rpath, std::vector<std::string> &neededLibs, const std::vector<std::string> & allowedRpathPrefixes);
    void removeRPath(Elf_Shdr & shdrDynamic);

    void addNeeded(const std::set<std::string> & libs);

    void removeNeeded(const std::set<std::string> & libs);

    void replaceNeeded(const std::map<std::string, std::string> & libs);

    void printNeededLibs() /* should be const */;

    void noDefaultLib();

    void addDebugTag();

    void renameDynamicSymbols(const std::unordered_map<std::string_view, std::string>&);

    struct GnuHashTable {
        using BloomWord = Elf_Addr;
        struct Header {
            uint32_t numBuckets, symndx, maskwords, shift2;
        } m_hdr;
        span<BloomWord> m_bloomFilters;
        span<uint32_t> m_buckets, m_table;
    };
    GnuHashTable parseGnuHashTable(span<char> gh);

    struct HashTable {
        struct Header {
            uint32_t numBuckets, nchain;
        } m_hdr;
        span<uint32_t> m_buckets, m_chain;
    };
    HashTable parseHashTable(span<char> gh);

    void rebuildGnuHashTable(span<char> strTab, span<Elf_Sym> dynsyms);
    void rebuildHashTable(span<char> strTab, span<Elf_Sym> dynsyms);

    using Elf_Rel_Info = decltype(Elf_Rel::r_info);

    uint32_t rel_getSymId(const Elf_Rel_Info& info) const
    {
        if constexpr (std::is_same_v<Elf_Rel, Elf64_Rel>)
            return ELF64_R_SYM(info);
        else
            return ELF32_R_SYM(info);
    }

    Elf_Rel_Info rel_setSymId(Elf_Rel_Info info, uint32_t id) const
    {
        if constexpr (std::is_same_v<Elf_Rel, Elf64_Rel>)
        {
            constexpr Elf_Rel_Info idmask = (~Elf_Rel_Info()) << 32;
            info = (info & ~idmask) | (Elf_Rel_Info(id) << 32);
        }
        else
        {
            constexpr Elf_Rel_Info idmask = (~Elf_Rel_Info()) << 8;
            info = (info & ~idmask) | (Elf_Rel_Info(id) << 8);
        }
        return info;
    }


    void clearSymbolVersions(const std::set<std::string> & syms);

    enum class ExecstackMode { print, set, clear };

    void modifyExecstack(ExecstackMode op);

private:

    /* Convert an integer in big or little endian representation (as
       specified by the ELF header) to this platform's integer
       representation. */
    template<class I>
    I rdi(I i) const;

    /* Convert back to the ELF representation. */
    template<class I>
    I wri(I & t, unsigned long long i) const
    {
        t = rdi((I) i);
        return i;
    }

    Elf_Ehdr *hdr() {
      return (Elf_Ehdr *)fileContents->data();
    }

    const Elf_Ehdr *hdr() const {
      return (const Elf_Ehdr *)fileContents->data();
    }
};
