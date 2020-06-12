AM_CXXFLAGS = -Wall -std=c++11 -D_FILE_OFFSET_BITS=64

if WITH_ASAN
AM_CXXFLAGS += -fsanitize=address -fno-optimize-sibling-calls -fsanitize-address-use-after-scope -fno-omit-frame-pointer -g -O1
endif

bin_PROGRAMS = patchelf

patchelf_SOURCES = patchelf.cc elf.h
