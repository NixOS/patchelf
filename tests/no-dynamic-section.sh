#! /bin/sh -e

# print rpath on library with stripped dynamic section
../src/patchelf --print-rpath libbig-dynstr.debug
