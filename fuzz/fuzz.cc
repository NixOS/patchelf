// libFuzzer harness: byte 0 selects the patchelf operation, the rest is the
// ELF image. patchelf rejects bad input via error(), which throws; that's
// expected and swallowed so only real memory/UB errors crash the fuzzer.

#include <cstdint>
#include <cstddef>

// Rename main() so it doesn't clash with libFuzzer's.
#define main patchelf_main_unused
#include "../src/patchelf.cc"
#undef main

template<class ElfFile>
static void fuzzOne(ElfFile && elf, uint8_t op)
{
    switch (op % 11) {
    case 0: elf.modifyRPath(ElfFile::rpSet, {}, "/fuzz/a:/fuzz/b"); break;
    case 1: elf.modifyRPath(ElfFile::rpRemove, {}, ""); break;
    case 2: elf.modifyRPath(ElfFile::rpShrink, {}, ""); break;
    case 3: elf.setInterpreter("/fuzz/ld.so"); break;
    case 4: elf.addNeeded({ "libfuzzneeded.so" }); break;
    case 5: elf.removeNeeded({ "libc.so.6" }); break;
    case 6: elf.replaceNeeded({ { "libc.so.6", "libfuzz.so.6" } }); break;
    case 7: elf.addDebugTag(); break;
    case 8: elf.noDefaultLib(); break;
    case 9: elf.modifySoname(ElfFile::replaceSoname, "libfuzz.so"); break;
    case 10: elf.buildResolutionCache(); break;
    }
    elf.rewriteSections();
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t * data, size_t size)
{
    if (size < 2) return 0;
    uint8_t op = data[0];
    auto contents = std::make_shared<std::vector<unsigned char>>(data + 1, data + size);

    try {
        if (getElfType(contents).is32Bit)
            fuzzOne(ElfFile<Elf32_Ehdr, Elf32_Phdr, Elf32_Shdr, Elf32_Nhdr, Elf32_Addr, Elf32_Off, Elf32_Dyn, Elf32_Sym, Elf32_Versym, Elf32_Verdef, Elf32_Verdaux, Elf32_Verneed, Elf32_Vernaux, Elf32_Rel, Elf32_Rela, 32>(contents), op);
        else
            fuzzOne(ElfFile<Elf64_Ehdr, Elf64_Phdr, Elf64_Shdr, Elf64_Nhdr, Elf64_Addr, Elf64_Off, Elf64_Dyn, Elf64_Sym, Elf64_Versym, Elf64_Verdef, Elf64_Verdaux, Elf64_Verneed, Elf64_Vernaux, Elf64_Rel, Elf64_Rela, 64>(contents), op);
    } catch (std::exception &) {
    }
    return 0;
}
