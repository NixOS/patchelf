cmake_minimum_required(VERSION 3.5)

project(patchelf)

file(READ version VERSION)

include(GNUInstallDirs)

add_subdirectory(src)
# add_subdirectory(tests) # TODO

install(FILES patchelf.1 DESTINATION ${CMAKE_INSTALL_MANDIR}/man1)

install(FILES README.md DESTINATION ${CMAKE_INSTALL_DOCDIR})
