#include "layout.h"

#include <algorithm>
#include <cassert>
#include <iostream>
#include <map>
#include <set>
#include <sstream>
#include <utility>
#include <vector>

using namespace le;
using namespace utl;

namespace le
{
struct VSection
{
    bool isPinned() const { return sec && sec->pinned; }
    bool isBlank() const { return !sec; }
    size_t align() const { return sec ? sec->align : 1; }
    Section* sec;
    utl::Range addrRange {0,0};
};

struct VSegment
{
    utl::Range addrRange;
    Segment* load {nullptr};
    std::vector<VSection> vsecs {};
};

class LayoutEngineImpl
{
public:
    LayoutEngineImpl(Layout lo, size_t nonLoadSegments, size_t sizeOfPHTEntry);
    bool resize(Layout::SecId id, size_t size);

    bool updateFileLayout();
    const Layout& layout() const { return m_lo; }

    size_t getVirtualAddress(size_t secid) const;

private:
    void dumpSections();
    void dumpSegments();

    void buildAddrSpace();
    void placeSections();

    Layout m_lo;
    size_t m_nonLoadSegments, m_sizeOfPHTEntry;
    std::vector<VSegment> m_addrSpace;

    bool resizeNonPinned(Section* sec, size_t newSize);
    bool tryToPlacePendingSections();
    bool moveToPending(Section* sec, Access access, size_t align);

    bool adjustPHTSize();
    size_t phtRequiredSize() const {
        return (m_nonLoadSegments + m_lo.m_segs.size()) * m_sizeOfPHTEntry;
    }

    std::map<Access, VSegment> m_pp;
};
}

static void dump(const std::vector<VSection>& vsecs);
static void dump(const std::vector<VSegment>& addrSpace);
static std::string toHex(size_t n);
static std::string toHex(const Range& rng);
static std::string toString(Access a);
static auto findVSection(std::vector<VSegment>& addrSpace, const Section* sec) -> std::pair<VSegment*, size_t>;
static bool tryToFitSectionInABlank(std::vector<VSection>& vsecs, Section* theSec);
static void normalize(VSegment& vseg);

LayoutEngineImpl::LayoutEngineImpl(Layout lo, size_t nonLoadSegments, size_t sizeOfPHTEntry)
    : m_lo(std::move(lo)), m_nonLoadSegments(nonLoadSegments), m_sizeOfPHTEntry(sizeOfPHTEntry)
{
    std::cerr << "========== START ===============" << std::endl;
    dumpSections();
    dumpSegments();
    buildAddrSpace();
    dump(m_addrSpace);
}

void LayoutEngineImpl::buildAddrSpace()
{
    // Build address space layout by iterating on all segments
    // and checking which sections are within the loaded range
    
    // Sort the segments by virtual address
    std::vector<Segment*> sortedSegs;

    for (auto& seg : m_lo.m_segs)
        sortedSegs.push_back(&seg);

    std::sort(sortedSegs.begin(), sortedSegs.end(), [] (auto* l, auto* r) {
        return l->vRange.begin() < r->vRange.begin();
    });

    // For each segment fill the VSegment
    //     Add empty VSegment items for holes between loaded
    //     segments
    //     Also round the segments by page since a segment
    //     from 0x1500 to 0x2500 is actually placed
    //     from 0x1000 to 0x3000 in the virtual space
    size_t curVAddr = 0;
    for (auto* seg : sortedSegs)
    {
        auto segRng = seg->vRange.aligned(seg->align);
        if (curVAddr < segRng.begin()) { // empty space
            auto sz = segRng.begin() - curVAddr;
            m_addrSpace.push_back( VSegment{Range(curVAddr, sz)} );
            curVAddr = segRng.begin();
        }
        if (!m_addrSpace.empty() && m_addrSpace.back().addrRange.intersects(segRng))
        {
            auto lastRng = m_addrSpace.back().addrRange;
            std::cerr << "Realigned segment " << toHex(lastRng) << " overlaps with " << toHex(segRng) << std::endl;
            // assert(0);
        }
        m_addrSpace.push_back(VSegment{segRng, seg});
        curVAddr = segRng.end();
    }

    // Fill each VSegment with the VSections it mounts
    // VSections are the representation of a Section when
    // placed in the virtual memory
    std::set<Section*> mappedSections;
    for (auto& vseg : m_addrSpace)
    {
        if (!vseg.load) continue;

        std::vector<std::pair<size_t, Section*>> secs;
        for (auto& sec : m_lo.m_secs)
        {
            if (vseg.load->fRange.wraps(sec.fRange))
            {
                if (auto [_, inserted] = mappedSections.insert(&sec); !inserted)
                {
                    std::cerr << "The section " << sec.name << " is being mapped by two different segments" << std::endl;
                    assert(!"We don't support sections mapped by multiple segments right now");
                }
                auto secAtVAddr = vseg.load->vRange.begin() + (sec.fRange.begin() - vseg.load->fRange.begin());
                secs.emplace_back(secAtVAddr, &sec);
                sec.access = vseg.load->access;
            }
            else if (vseg.load->fRange.intersects(sec.fRange))
            {
                std::cerr << "Load segment takes from file: " << toHex(vseg.load->fRange) << std::endl;
                std::cerr << "We have a section a file rng: " << toHex(sec.fRange) << std::endl;
                assert(!"Segment loads only a part of a section");
            }
        }
        std::sort(secs.begin(), secs.end(),
                [] (auto& l, auto& r) { return l.first < r.first; });

        auto curVAddr = vseg.addrRange.begin();
        for (auto& [secVAddr, sec] : secs)
        {
            if (secVAddr > curVAddr) {
                auto sz = secVAddr - curVAddr;
                vseg.vsecs.push_back(VSection{nullptr, Range{curVAddr, sz}});
                curVAddr = secVAddr;
            }
            auto secVAddrRange = Range{curVAddr, sec->fRange.size()};
            vseg.vsecs.push_back(VSection{sec, secVAddrRange});
            curVAddr = secVAddrRange.end();
        }
        if (curVAddr != vseg.addrRange.end())
        {
            auto sz = vseg.addrRange.end() - curVAddr;
            vseg.vsecs.push_back(VSection{nullptr, Range{curVAddr, sz}});
        }
    }
}

bool LayoutEngineImpl::resize(Layout::SecId id, size_t newSize)
{
    auto* sec = &m_lo.m_secs[id];
    auto [oldVSeg, vsecid] = ::findVSection(m_addrSpace, sec);
    if (!oldVSeg)
    {
        // Section is not mapped in virtual memory.
        sec->fRange.resize(newSize);
        return true;
    }
    assert(!sec->pinned);
    return resizeNonPinned(sec, newSize);
}

bool LayoutEngineImpl::resizeNonPinned(Section* sec, size_t newSize)
{
    std::cerr << "############## Resize non pinned section" << std::endl;
    auto [oldVSeg, vsecid] = ::findVSection(m_addrSpace, sec);
    assert(oldVSeg);

    // Detach the section from the virtual space
    oldVSeg->vsecs[vsecid].sec = nullptr;
    // Merge any consecutive blanks that might have been created 
    normalize(*oldVSeg);

    sec->fRange.resize(newSize);

    // Try to place this new section in any segment with matching
    // access rights and with a blank that is big enought to hold it
    for (auto& vseg : m_addrSpace)
    {
        if (vseg.load && vseg.load->access == oldVSeg->load->access && tryToFitSectionInABlank(vseg.vsecs, sec))
        {
            std::cerr << "############## Placed in a pre-existing blank" << std::endl;
            return true;
        }
    }

    // We will need to create a new segment later to place this section
    if (!moveToPending(sec, oldVSeg->load->access, oldVSeg->load->align))
        return false;

    return true;
}

// Merge any consecutive blank segments in this VSegment
static void normalize(VSegment& vseg)
{
    std::vector<VSection> nvsecs;
    for (auto& vsec : vseg.vsecs)
    {
        if (nvsecs.empty() || !nvsecs.back().isBlank() || !vsec.isBlank())
            nvsecs.push_back(vsec);
        else
            nvsecs.back().addrRange.setEnd(vsec.addrRange.end());
    }
    vseg.vsecs = std::move(nvsecs);
}

bool LayoutEngineImpl::moveToPending(Section* sec, Access access, size_t align)
{
    std::cerr << "############## Moving to pending: " << sec->name << std::endl;
    auto it = m_pp.find(access);
    if (it == m_pp.end())
    {
        std::cerr << "Entered here" << std::endl;
        auto newSid = m_lo.add(Segment{Range{0,0}, Range{0,0}, access, align});
        auto& newSeg = m_lo.m_segs.at(newSid);
        it = m_pp.emplace(access, VSegment{Range{0,0}, &newSeg}).first;
        if (!adjustPHTSize())
            return false;
    }
    it->second.vsecs.push_back(VSection{sec});
    std::cerr << "############## Done moving to pending: " << sec->name << std::endl;
    return true;
}

bool LayoutEngineImpl::adjustPHTSize()
{
    std::cerr << "############## Increasing PHT" << std::endl;
    auto requiredSize = phtRequiredSize();

    auto* sec = &m_lo.m_secs[/*phdr id*/1];
    auto [vseg, id] = ::findVSection(m_addrSpace, sec);
    assert(vseg);

    size_t availableSize = vseg->vsecs[id].addrRange.size();

    if (requiredSize <= availableSize)
        return true;

    for (size_t nid = id + 1; availableSize < requiredSize && nid < vseg->vsecs.size(); ++nid)
    {
        auto& nvsec = vseg->vsecs[nid];
        if (nvsec.isBlank())
        {
            std::cerr << "############## Found blank of size " << toHex(nvsec.addrRange.size()) << std::endl;
            availableSize += nvsec.addrRange.size();
        }
        else if (!nvsec.sec->pinned)
        {
            std::cerr << "############## Evicted " << nvsec.sec->name
                      << " of size " << toHex(nvsec.addrRange.size()) << std::endl;

            availableSize += nvsec.addrRange.size();
            auto moveSec = std::exchange(nvsec.sec, nullptr);
            if (!moveToPending(moveSec, vseg->load->access, vseg->load->align))
                return false;
            // Number of needed segments might have increased
            requiredSize = phtRequiredSize();
        }
        else
            break;
    }

    if (availableSize < requiredSize)
    {
        std::cerr << "############## Could not find enough memory. Needed "<< requiredSize << " found: " << availableSize << std::endl;
        return false;
    }

    std::cerr << "############## Found enough memory!"<< std::endl;
    normalize(*vseg);

    auto& vsec = vseg->vsecs[id];

    auto& nvsec = vseg->vsecs[id + 1];
    assert(nvsec.isBlank());

    availableSize = vsec.addrRange.size() + nvsec.addrRange.size();
    assert(availableSize >= requiredSize);

    vsec.addrRange.resize(requiredSize);
    sec->fRange.resize(requiredSize);

    nvsec.addrRange = Range::beginEnd(vsec.addrRange.end(), nvsec.addrRange.end());
    return true;
}

static bool tryToFitSectionInABlank(std::vector<VSection>& vsecs, Section* theSec)
{
    for (size_t i = 0; i < vsecs.size(); ++i)
    {
        auto c = vsecs[i];
        if (c.isBlank() && c.addrRange.size() >= theSec->fRange.size())
        {
            auto vstart = roundUp(c.addrRange.begin(), theSec->align);
            auto vend = vstart + theSec->fRange.size();
            if (vend > c.addrRange.end())
                continue;

            size_t leftOver = c.addrRange.size();
            if (vstart != c.addrRange.begin())
            {
                auto blankRange = Range(c.addrRange.begin(), vstart-c.addrRange.begin());
                vsecs.insert(vsecs.begin()+i, VSection{nullptr, blankRange});
                leftOver -= blankRange.size();
                ++i;
            }
            vsecs[i].sec = theSec;
            vsecs[i].addrRange = Range(vstart, theSec->fRange.size());
            leftOver -= theSec->fRange.size();

            if (leftOver) {
                vsecs.insert(vsecs.begin()+i+1, VSection{nullptr, Range(vend,leftOver)});
            }

            return true;
        }
    }
    return false;
}

static std::vector<VSection>::const_iterator findVSection(const std::vector<VSection>& vsecs, const Section* sec)
{
    return std::find_if(vsecs.begin(), vsecs.end(), [&] (auto& vsec) { return vsec.sec == sec; });
}

static auto findVSection(std::vector<VSegment>& addrSpace, const Section* sec) -> std::pair<VSegment*, size_t>
{
    for (auto& vseg : addrSpace)
    {
        auto it = findVSection(vseg.vsecs, sec);
        if (it != vseg.vsecs.end())
            return {&vseg, it - vseg.vsecs.begin()};
    }
    return {nullptr, 0};
}

size_t LayoutEngineImpl::getVirtualAddress(size_t secid) const
{
    auto* sec = &m_lo.m_secs.at(secid);
    auto [vseg, id] = ::findVSection(const_cast<std::vector<le::VSegment>&>(m_addrSpace), sec);
    return vseg ? vseg->vsecs[id].addrRange.begin() : 0;
}

bool LayoutEngineImpl::updateFileLayout()
{
    if (!tryToPlacePendingSections())
        return false;

    for (auto& vseg : m_addrSpace)
    {
        if (!vseg.load) continue;

        auto& first = vseg.vsecs.front();
        auto& last = vseg.vsecs.back();

        auto b = first.isBlank() ? first.addrRange.end() : first.addrRange.begin();
        auto e = last.isBlank() ? last.addrRange.begin() : last.addrRange.end();

        if (e < b) e = b;
        std::cerr << "######## Setting segment vaddr to: " << toHex(Range::beginEnd(b,e)) << std::endl;
        vseg.load->vRange = Range::beginEnd(b,e);
    }

    std::vector<Section*> sortedSecs;
    for (auto& sec : m_lo.m_secs) sortedSecs.push_back(&sec);
    std::sort(sortedSecs.begin(), sortedSecs.end(), [] (auto& l, auto& r) { return l->fRange.begin() < r->fRange.begin(); });

    size_t fileOffset = 0;
    std::set<Section*> loadedSections;
    for (auto* sec : sortedSecs)
    {
        auto [vsegPtr, _] = ::findVSection(m_addrSpace, sec);
        if (!vsegPtr || !loadedSections.insert(sec).second) continue;

        auto& vseg = *vsegPtr;

        std::cerr << "###################################### New segment" << std::endl;

        std::cerr << "Previous fileOffset: " << toHex(fileOffset) << std::endl;
        auto addrModAlign = vseg.load->vRange.begin() % vseg.load->align;
        auto foffModAlign = fileOffset % vseg.load->align;
        if (addrModAlign > foffModAlign)
            fileOffset += addrModAlign - foffModAlign;
        else if (addrModAlign < foffModAlign)
            fileOffset += (vseg.load->align - foffModAlign) + addrModAlign;
        assert(vseg.load->vRange.begin() % vseg.load->align == fileOffset % vseg.load->align);
        std::cerr << "New fileOffset: " << toHex(fileOffset) << std::endl;

        size_t firstOffset = fileOffset;
        bool updated = false;
        size_t i = 0;
        for (auto& vsec : vseg.vsecs)
        {
            if (!vsec.isBlank())
            {
                if (vsec.sec->fRange.size() > 0)
                    fileOffset = fileOffset ? roundUp(fileOffset, vsec.sec->align) : 0;

                if (!updated) firstOffset = fileOffset;
                updated = true;

                auto fRangeBefore = vsec.sec->fRange;
                vsec.sec->fRange.rebase(fileOffset);
                if (fRangeBefore != vsec.sec->fRange)
                {
                    std::cerr << "##### adjusting sec " << vsec.sec->name
                              << "\tfrom: " << toHex(fRangeBefore)
                              << "\tto: " << toHex(vsec.sec->fRange)
                              << std::endl;
                }
                fileOffset += vsec.sec->fRange.size();
                loadedSections.insert(vsec.sec);
            }
            else if (i != 0 && i != vseg.vsecs.size()-1)
            {
                fileOffset += vsec.addrRange.size();
            }
            ++i;
        }
        vseg.load->fRange = Range::beginEnd(firstOffset, fileOffset);
    }

    for (auto* sec : sortedSecs)
    {
        if (!loadedSections.count(sec))
        {
            fileOffset = fileOffset ? roundUp(fileOffset, sec->align) : 0;
            auto fRangeBefore = sec->fRange;
            sec->fRange.rebase(fileOffset);
            if (fRangeBefore != sec->fRange)
            {
                std::cerr << "##### adjusting non loaded sec " << sec->name
                          << "\tfrom: " << toHex(fRangeBefore)
                          << "\tto: " << toHex(sec->fRange)
                          << std::endl;
            }
            fileOffset += sec->fRange.size();
        }
    }

    std::cerr << "========== END ===============" << std::endl;
    dumpSections();
    dumpSegments();

    std::cerr << "Old file size: " << m_lo.m_fileSz << std::endl;
    std::cerr << "New file size: " << fileOffset << std::endl;
    std::cerr << "         diff: " << long(fileOffset) - long(m_lo.m_fileSz) << std::endl;
    m_lo.m_fileSz = fileOffset;
    return true;
}

bool LayoutEngineImpl::tryToPlacePendingSections()
{
    std::cerr << "############## Placing pending sections" << std::endl;
    auto lastVAddr = m_addrSpace.back().addrRange.end();
    for (auto& [_, vseg] : m_pp)
    {
        lastVAddr = roundUp(lastVAddr, vseg.load->align);
        vseg.addrRange.rebase(lastVAddr);
        for (auto& vsec : vseg.vsecs)
        {
            lastVAddr = roundUp(lastVAddr, vsec.sec->align);
            vsec.addrRange.rebase(lastVAddr);
            lastVAddr += vsec.sec->fRange.size();
            vsec.addrRange.resize(vsec.sec->fRange.size());
        }
        vseg.addrRange.resize(roundUp(lastVAddr, vseg.load->align) - vseg.addrRange.begin());
        m_addrSpace.push_back(vseg);
    }
    dump(m_addrSpace);
    return true;
}

void LayoutEngineImpl::dumpSections()
{
    std::cerr << "================ SECTIONS =====================" << std::endl;
    for (auto& sec : m_lo.m_secs)
    {
        std::cerr << "    " << toHex(sec.fRange) << " " << sec.name << std::endl;
    }
}

void LayoutEngineImpl::dumpSegments()
{
    std::cerr << "================ SEGMENTS =====================" << std::endl;
    for (auto& seg : m_lo.m_segs)
    {
        std::cerr << "    " << toString(seg.access) << toHex(seg.fRange) << " -->  " << toHex(seg.vRange) << std::endl;
    }
}

static void dump(const std::vector<VSection>& vsecs)
{
    size_t totalBlank = 0;
    for (auto& vsec : vsecs)
    {
        auto* sec = vsec.sec;
        std::cerr << "    " << toHex(vsec.addrRange) << "\t(align: ";
        if (sec)
        {
            std::cerr << sec->align << ")\t" << sec->name;
            if (sec->pinned)
                std::cerr << "\tpinned";
            std::cerr << std::endl;
        }
        else
        {
            totalBlank += vsec.addrRange.size();
            std::cerr << "X)\t<BLANK>" << std::endl;
        }
    }
    std::cerr << "    (Total blank size: " << toHex(totalBlank) << ")" << std::endl;
}

static void dump(const std::vector<VSegment>& addrSpace)
{
    std::cerr << "================ ADDR SPACE =====================" << std::endl;
    for (auto& vseg : addrSpace)
    {
        std::cerr << toHex(vseg.addrRange) << (vseg.load ? " (LOAD)" : " (BLANK)")
            << (vseg.load ? "\t(align: " + toHex(vseg.load->align) + ")" : "")
            << std::endl;
        dump(vseg.vsecs);
        std::cerr << std::endl;
    }
}

static std::string toHex(size_t n)
{
    std::stringstream ss;
    ss << std::hex << "0x" << n;
    return ss.str();
}

static std::string toHex(const Range& rng)
{
    std::stringstream ss;
    ss << "[" << toHex(rng.begin()) << " -> " << toHex(rng.end()) << " (" << toHex(rng.size()) << ")]";
    return ss.str();
}

static std::string toString(Access a)
{
    std::string str;
    str.resize(3);
    str[0] = (a & Access::Read) ? 'R' : ' ';
    str[1] = (a & Access::Write) ? 'W' : ' ';
    str[2] = (a & Access::Exec) ? 'E' : ' ';
    return str;
}

LayoutEngine::LayoutEngine(Layout lo, size_t nonLoadSegments, size_t sizeOfPHTEntry) {
    m_impl = std::make_unique<LayoutEngineImpl>(std::move(lo), nonLoadSegments, sizeOfPHTEntry);
}
LayoutEngine::~LayoutEngine() = default;
bool LayoutEngine::resize(Layout::SecId id, size_t size) { return m_impl->resize(id, size); }
bool LayoutEngine::updateFileLayout() { return m_impl->updateFileLayout(); }
const Layout& LayoutEngine::layout() const { return m_impl->layout(); }
size_t LayoutEngine::getVirtualAddress(size_t secid) const { return m_impl->getVirtualAddress(secid); }
