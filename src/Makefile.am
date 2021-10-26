AM_CXXFLAGS = -Wall -std=c++17 -D_FILE_OFFSET_BITS=64

if WITH_ASAN
AM_CXXFLAGS += -fsanitize=address -fsanitize-address-use-after-scope
endif

if WITH_UBSAN
AM_CXXFLAGS += -fsanitize=undefined
endif

SAN_FLAGS = -fno-optimize-sibling-calls -fno-omit-frame-pointer
if WITH_ASAN
AM_CXXFLAGS += $(SAN_FLAGS)
else
if WITH_UBSAN
AM_CXXFLAGS += $(SAN_FLAGS)
endif
endif

bin_PROGRAMS = patchelf

patchelf_SOURCES = patchelf.cc elf.h
