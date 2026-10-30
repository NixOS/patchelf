#pragma once

#include <cerrno>
#include <cstddef>
#include <cstring>
#include <stdexcept>
#include <string>
#include <vector>

#include <fcntl.h>
#include <unistd.h>

#if defined(__linux__)
#include <sys/mman.h>
#define PATCHELF_HAVE_MREMAP 1
#endif

class FileContentsBuffer
{
public:
    static FileContentsBuffer inHeapMemory(std::vector<unsigned char> initialContents)
    {
        return FileContentsBuffer(std::move(initialContents));
    }

#ifdef PATCHELF_HAVE_MREMAP
    static FileContentsBuffer mappedFromFile(int fd, size_t initialSize)
    {
        return FileContentsBuffer(fd, initialSize);
    }
#endif

    ~FileContentsBuffer()
    {
#ifdef PATCHELF_HAVE_MREMAP
        if (mmapBacked)
            unmapAndCloseFile();
#endif
    }

    FileContentsBuffer(const FileContentsBuffer &) = delete;
    FileContentsBuffer & operator=(const FileContentsBuffer &) = delete;

    FileContentsBuffer(FileContentsBuffer && other) noexcept
        : heap(std::move(other.heap))
        , mmapBacked(other.mmapBacked)
    {
#ifdef PATCHELF_HAVE_MREMAP
        if (mmapBacked)
            adoptMapping(other);
#endif
        other.mmapBacked = false;
    }

    FileContentsBuffer & operator=(FileContentsBuffer && other) noexcept
    {
        if (this == &other)
            return *this;
#ifdef PATCHELF_HAVE_MREMAP
        if (mmapBacked)
            unmapAndCloseFile();
#endif
        heap = std::move(other.heap);
        mmapBacked = other.mmapBacked;
#ifdef PATCHELF_HAVE_MREMAP
        if (mmapBacked)
            adoptMapping(other);
#endif
        other.mmapBacked = false;
        return *this;
    }

    [[nodiscard]] bool isMMapBacked() const noexcept { return mmapBacked; }

    [[nodiscard]] unsigned char * data() noexcept
    {
#ifdef PATCHELF_HAVE_MREMAP
        if (mmapBacked) return static_cast<unsigned char *>(addr);
#endif
        return heap.data();
    }

    [[nodiscard]] const unsigned char * data() const noexcept
    {
#ifdef PATCHELF_HAVE_MREMAP
        if (mmapBacked) return static_cast<const unsigned char *>(addr);
#endif
        return heap.data();
    }

    [[nodiscard]] size_t size() const noexcept
    {
#ifdef PATCHELF_HAVE_MREMAP
        if (mmapBacked) return mmapLen;
#endif
        return heap.size();
    }

    void resize(size_t newSize, unsigned char fill = 0)
    {
#ifdef PATCHELF_HAVE_MREMAP
        if (mmapBacked) {
            resizeMappedRegion(newSize, fill);
            return;
        }
#endif
        heap.resize(newSize, fill);
    }

    void flush()
    {
#ifdef PATCHELF_HAVE_MREMAP
        if (mmapBacked)
            syncMappedRegionToDisk();
#endif
    }

private:
    explicit FileContentsBuffer(std::vector<unsigned char> initialContents)
        : heap(std::move(initialContents))
    { }

#ifdef PATCHELF_HAVE_MREMAP
    FileContentsBuffer(int fd_, size_t initialSize)
        : mmapBacked(true)
        , fd(fd_)
    {
        mapRegularFileIfNonEmpty(initialSize);
    }

    void mapRegularFileIfNonEmpty(size_t initialSize)
    {
        if (initialSize == 0)
            return;
        void * p = mmap(nullptr, initialSize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
        if (p == MAP_FAILED)
            throw std::runtime_error(std::string("mmap: ") + strerror(errno));
        addr = p;
        mmapLen = initialSize;
    }

    void unmapAndCloseFile() noexcept
    {
        if (addr && mmapLen)
            munmap(addr, mmapLen);
        if (fd != -1)
            close(fd);
    }

    void adoptMapping(FileContentsBuffer & other) noexcept
    {
        fd = other.fd;
        addr = other.addr;
        mmapLen = other.mmapLen;
        other.fd = -1;
        other.addr = nullptr;
        other.mmapLen = 0;
    }

    void syncMappedRegionToDisk()
    {
        if (!addr || !mmapLen)
            return;
        if (msync(addr, mmapLen, MS_SYNC) != 0)
            throw std::runtime_error(std::string("msync: ") + strerror(errno));
    }

    void resizeMappedRegion(size_t newSize, unsigned char fill)
    {
        size_t oldSize = mmapLen;
        if (newSize == oldSize)
            return;

        growOrShrinkUnderlyingFile(newSize);

        if (newSize == 0) {
            unmapEntirely();
            return;
        }

        remapToNewSize(oldSize, newSize);
        fillExtendedRegionIfNonZero(oldSize, newSize, fill);
    }

    void growOrShrinkUnderlyingFile(size_t newSize)
    {
        if (ftruncate(fd, static_cast<off_t>(newSize)) != 0)
            throw std::runtime_error(std::string("ftruncate: ") + strerror(errno));
    }

    void unmapEntirely() noexcept
    {
        if (addr) munmap(addr, mmapLen);
        addr = nullptr;
        mmapLen = 0;
    }

    void remapToNewSize(size_t oldSize, size_t newSize)
    {
        if (oldSize == 0) {
            void * newAddr = mmap(nullptr, newSize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
            if (newAddr == MAP_FAILED)
                throw std::runtime_error(std::string("mmap: ") + strerror(errno));
            addr = newAddr;
        } else {
            void * newAddr = mremap(addr, oldSize, newSize, MREMAP_MAYMOVE);
            if (newAddr == MAP_FAILED)
                throw std::runtime_error(std::string("mremap: ") + strerror(errno));
            addr = newAddr;
        }
        mmapLen = newSize;
    }

    void fillExtendedRegionIfNonZero(size_t oldSize, size_t newSize, unsigned char fill)
    {
        if (newSize > oldSize && fill != 0)
            memset(static_cast<unsigned char *>(addr) + oldSize, fill, newSize - oldSize);
    }
#endif

    std::vector<unsigned char> heap;

    bool mmapBacked = false;
#ifdef PATCHELF_HAVE_MREMAP
    int fd = -1;
    void * addr = nullptr;
    size_t mmapLen = 0;
#endif
};
