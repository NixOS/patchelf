AM_CXXFLAGS = -Wall -std=c++11 -D_FILE_OFFSET_BITS=64

SAN_FLAGS = -fno-optimize-sibling-calls -fsanitize-address-use-after-scope -fno-omit-frame-pointer -g -O1

if WITH_ASAN
AM_CXXFLAGS += -fsanitize=address $(SAN_FLAGS)
endif

if WITH_UBSAN
AM_CXXFLAGS += -fsanitize=undefined $(SAN_FLAGS)
endif

bin_PROGRAMS = patchelf

patchelf_SOURCES = patchelf.cc elf.h
