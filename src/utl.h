#pragma once

#include <cstddef>
#include <cstdint>

namespace utl
{

inline uint64_t roundUp(uint64_t n, uint64_t m)
{
    if (n == 0)
        return m;
    return ((n - 1) / m + 1) * m;
}

class Range
{
public:
    Range() = delete;
    Range(size_t begin, size_t size)
        : m_begin(begin)
        , m_size(size)
    {
    }

    static Range beginEnd(size_t begin, size_t end)
    {
        return Range(begin, end-begin);
    }

    size_t begin() const { return m_begin; }
    size_t end() const { return begin() + size(); }
    size_t size() const { return m_size; }

    bool operator==(const Range& rhs) const
    {
        return m_begin == rhs.m_begin && m_size == rhs.m_size;
    }
    bool operator!=(const Range& rhs) const { return !(*this == rhs); }

    bool wraps(const Range& rng) const
    {
        return begin() <= rng.begin() && end() >= rng.end();
    }

    bool within(const Range& rng) const
    {
        return rng.wraps(*this);
    }

    bool intersects(const Range& rng) const
    {
        if (begin() == rng.begin()) return true;

        if (begin() < rng.begin())
            return end() > rng.begin();
        else
            return rng.end() > begin();
    }

    Range aligned(size_t align) const
    {
        if (align == 0) return *this;
        auto b = begin() - begin() % align;
        auto e = end() + (align - end()%align);
        return Range{b, e-b};
    }

    void rebase(size_t begin) { m_begin = begin; }
    void resize(size_t sz) { m_size = sz; }
    void setEnd(size_t e) { m_size = e - m_begin; }

    void extendBack(long sz)
    {
        m_begin -= sz;
        m_size += sz;
    }

    void extendForw(long sz)
    {
        m_size += sz;
    }

private:
    size_t m_begin, m_size;
};

}
