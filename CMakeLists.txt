cmake_minimum_required(VERSION 3.5)

project(patchelf)

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_EXTENSIONS OFF)

set(PAGESIZE 4096)

set(ADDITIONAL_HEADERS src/elf.h)

set(SOURCES src/patchelf.cc)

file(READ version VERSION)

add_executable(${PROJECT_NAME} ${SOURCES} ${ADDITIONAL_HEADERS})

target_compile_definitions(
  patchelf PRIVATE PAGESIZE=${PAGESIZE}
                   PACKAGE_STRING="patchelf ${VERSION_STRING}")

install(TARGETS patchelf RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

install(FILES patchelf.1 DESTINATION ${CMAKE_INSTALL_MANDIR}/man1)

install(FILES README.md DESTINATION ${CMAKE_INSTALL_DOCDIR})

install(FILES completions/zsh/_patchelf
        DESTINATION ${CMAKE_INSTALL_DATADIR}/zsh/site-functions)
