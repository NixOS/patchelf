project(patchelf)
cmake_minimum_required(VERSION 2.8)

if (CMAKE_VERSION VERSION_LESS "3.1")
    if (CMAKE_COMPILER_IS_GNUCXX)
        set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")
    endif ()
else ()
    set (CMAKE_CXX_STANDARD   11)
    set (CMAKE_CXX_EXTENSIONS OFF)
endif ()

set(PAGESIZE 4096)

set ( ADDITIONAL_HEADERS
    src/elf.h
)

set ( SOURCES
    src/patchelf.cc
)

file(READ version VERSION)

add_definitions(-DPAGESIZE=${PAGESIZE})
add_definitions(-DPACKAGE_STRING="patchelf ${VERSION}")

add_executable(${PROJECT_NAME} ${SOURCES} ${ADDITIONAL_HEADERS})
