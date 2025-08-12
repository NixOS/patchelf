set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_EXTENSIONS OFF)

set(PAGESIZE 4096)

add_executable(${PROJECT_NAME} patchelf.cc elf.h patchelf.h)

target_compile_definitions(
  patchelf PRIVATE PAGESIZE=${PAGESIZE}
                   PACKAGE_STRING="patchelf ${VERSION_STRING}")

install(TARGETS patchelf RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
