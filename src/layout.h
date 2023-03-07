#pragma once

#include "utl.h"

#include <cstddef>
#include <deque>
#include <string>
#include <memory>

namespace le
{
enum Access {None, Read=1, Write=2, Exec=4};
inline void addIf(Access& lhs, Access rhs, bool cond = true) {
    if (cond)
        lhs = static_cast<Access>(lhs | rhs);
}

struct Section
{
    enum class Type { ElfHeader, PHTable, SHTable, Regular };

    std::string name;
    Type type;
    utl::Range fRange;
    size_t align;
    bool pinned;

    // Filled by the engine
    Access access {Access::None};
    ssize_t id {-1};
};

struct Segment
{
    utl::Range vRange, fRange;
    Access access;
    size_t align;
    // Filled by the engine
    ssize_t id {-1};
};

struct Layout
{
    using SecId = size_t;
    using SegId = size_t;

    SecId add(const Section& sec)
    {
        m_secs.push_back(sec);
        auto id = m_secs.size() - 1;
        m_secs.back().id = id;
        m_fileSz = std::max(m_fileSz, sec.fRange.end());
        return id;
    }

    SegId add(const Segment& seg)
    {
        m_segs.push_back(seg);
        auto id = m_segs.size() - 1;
        m_segs.back().id = id;
        return id;
    }

    std::deque<Section> m_secs;
    std::deque<Segment> m_segs;
    size_t m_fileSz {0};
};

class LayoutEngineImpl;
class LayoutEngine
{
public:
    LayoutEngine(Layout lo, size_t nonLoadSegments, size_t sizeOfPHTEntry);
    ~LayoutEngine();

    bool resize(Layout::SecId id, size_t size);

    bool updateFileLayout();
    const Layout& layout() const;

    size_t getVirtualAddress(size_t secid) const;

private:
    std::unique_ptr<LayoutEngineImpl> m_impl;
};

}
