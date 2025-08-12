# PatchELF

PatchELF is a simple utility for modifying existing ELF executables and
libraries.  In particular, it can do the following:

* Change the dynamic loader ("ELF interpreter") of executables:

  ```console
  $ patchelf --set-interpreter /lib/my-ld-linux.so.2 my-program
  ```

* Change the `RPATH` of executables and libraries:

  ```console
  $ patchelf --set-rpath /opt/my-libs/lib:/other-libs my-program
  ```

* Shrink the `RPATH` of executables and libraries:

  ```console
  $ patchelf --shrink-rpath my-program
  ```

  This removes from the `RPATH` all directories that do not contain a
  library referenced by `DT_NEEDED` fields of the executable or library.
  For instance, if an executable references one library `libfoo.so`, has
  an RPATH `/lib:/usr/lib:/foo/lib`, and `libfoo.so` can only be found
  in `/foo/lib`, then the new `RPATH` will be `/foo/lib`.

  In addition, the `--allowed-rpath-prefixes` option can be used for
  further rpath tuning. For instance, if an executable has an `RPATH`
  `/tmp/build-foo/.libs:/foo/lib`, it is probably desirable to keep
  the `/foo/lib` reference instead of the `/tmp` entry. To accomplish
  that, use:

  ```console
  $ patchelf --shrink-rpath --allowed-rpath-prefixes /usr/lib:/foo/lib my-program
  ```

* Remove declared dependencies on dynamic libraries (`DT_NEEDED`
  entries):

  ```console
  $ patchelf --remove-needed libfoo.so.1 my-program
  ```

  This option can be given multiple times.

* Add a declared dependency on a dynamic library (`DT_NEEDED`):

  ```console
  $ patchelf --add-needed libfoo.so.1 my-program
  ```

  This option can be give multiple times.

* Replace a declared dependency on a dynamic library with another one
  (`DT_NEEDED`):

  ```console
  $ patchelf --replace-needed liboriginal.so.1 libreplacement.so.1 my-program
  ```

  This option can be give multiple times.

* Change `SONAME` of a dynamic library:

  ```console
  $ patchelf --set-soname libnewname.so.3.4.5 path/to/libmylibrary.so.1.2.3
  ```


## Compiling and Testing

### Via [GNU Autotools](https://www.gnu.org/software/automake/manual/html_node/Autotools-Introduction.html)
```console
./bootstrap.sh
./configure
make
make check
sudo make install
```

### Via [CMake](https://cmake.org/) (and [Ninja](https://ninja-build.org/))

```console
mkdir build
cd build
cmake .. -GNinja
ninja all
sudo ninja install
```

### Via [Meson](https://mesonbuild.com/) (and [Ninja](https://ninja-build.org/))

```console
mkdir build
meson configure build
cd build
ninja all
sudo ninja install
```

### Via Nix

You can build with Nix in several ways.

1. Building via `nix build` will produce the result in `./result/bin/patchelf`. If you would like to build _patchelf_ with _musl_ try `nix build .#patchelf-musl`

2. You can launch a development environment with `nix develop` and follow the autotools steps above. If you would like to develop with _musl_ try `nix develop .#musl`

## Help and resources

- Matrix: [#patchelf:nixos.org](https://matrix.to/#/#patchelf:nixos.org)

## Author

Copyright 2004-2019 Eelco Dolstra <edolstra@gmail.com>.

## License

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

## Release History

0.14.5 (February 21, 2022):

* fix faulty version in 0.14.4

0.14.4 (February 21, 2022):

* Several test fixes to fix patchelf test suite on openbsd by @klemensn
* Allow multiple modifications in same call by @fzakaria in https://github.com/NixOS/patchelf/pull/361
* Add support to build with musl by @fzakaria in https://github.com/NixOS/patchelf/pull/362
* Fix typo: s/folllow/follow/ by @bjornfor in https://github.com/NixOS/patchelf/pull/366
* mips: fix incorrect polarity on dyn_offset; closes #364 by @a-m-joseph in https://github.com/NixOS/patchelf/pull/365

0.14.3 (December 05, 2021):

* this release adds support for static, pre-compiled patchelf binaries

0.14.2 (November 29, 2021):

* make version number in tarball easier to use for packagers

0.14.1 (November 28, 2021):

* build fix: add missing include

0.14 (November 27, 2021):

Changes compared to 0.13:

* Bug fixes:
  - Fix corrupted library names when using --replace-needed multiple times
  - Fix setting an empty rpath
  - Don't try to parse .dynamic section of type NOBITS
  - Fix use-after-free in normalizeNoteSegments
  - Correct EINTR handling in writeFile
  - MIPS: Adjust PT_MIPS_ABIFLAGS segment and DT_MIPS_RLD_MAP_REL dynamic section if present
  - Fix binaries without .gnu.hash section
* Support loongarch architecture
* Remove limits on output file size for elf files
* Allow reading rpath from file
* Requires now C++17 for building

0.13.1 (November 27, 2021):

* Bug fixes:
  - fix setting empty rpath
  - use memcpy instead of strcpy to set rpath
  - Don't try to parse .dynamic section of type NOBITS
  - fix use-after-free in normalizeNoteSegments
  - correct EINTR handling in writeFile
  - Adjust PT_MIPS_ABIFLAGS segment if present
  - Adjust DT_MIPS_RLD_MAP_REL dynamic section entry if present
  - fix binaries without .gnu.hash section

0.13 (August 5, 2021):

* New `--add-rpath` flag.

* Bug fixes.

0.12 (August 27, 2020):

* New `--clear-symbol-version` flag.

* Better support for relocating NOTE sections/segments.

* Improved the default section alignment choice.

* Bug fixes.

0.11 (June 9, 2020):

* New `--output` flag.

* Some bug fixes.

0.10 (March 28, 2019):

* Many bug fixes. Please refer to the Git commit log:

    https://github.com/NixOS/patchelf/commits/master

  This release has contributions from Adam Trhoň, Benjamin Hipple,
  Bernardo Ramos, Bjørn Forsman, Domen Kožar, Eelco Dolstra, Ezra
  Cooper, Felipe Sateler, Jakub Wilk, James Le Cuirot, Karl Millar,
  Linus Heckemann, Nathaniel J. Smith, Richard Purdie, Stanislav
  Markevich and Tuomas Tynkkynen.

0.9 (February 29, 2016):

* Lots of new features. Please refer to the Git commit log:

    https://github.com/NixOS/patchelf/commits/master

  This release has contributions from Aaron D. Marasco, Adrien
  Devresse, Alexandre Pretyman, Changli Gao, Chingis Dugarzhapov,
  darealshinji, David Sveningsson, Eelco Dolstra, Felipe Sateler,
  Jeremy Sanders, Jonas Kuemmerlin, Thomas Tuegel, Tuomas Tynkkynen,
  Vincent Danjean and Vladimír Čunát.

0.8 (January 15, 2014):

* Fix a segfault caused by certain illegal entries in symbol tables.

0.7 (January 7, 2014):

* Rewrite section indices in symbol tables. This for instance allows
  gdb to show proper backtraces.

* Added `--remove-needed' option.

0.6 (November 7, 2011):

* Hacky support for executables created by the Gold linker.

* Support segments with an alignment of 0 (contributed by Zack
  Weinberg).

* Added a manual page (contributed by Jeremy Sanders
  <jeremy@jeremysanders.net>).

0.5 (November 4, 2009):

* Various bugfixes.

* `--force-rpath' now deletes the DT_RUNPATH if it is present.

0.4 (June 4, 2008):

* Support for growing the RPATH on dynamic libraries.

* IA-64 support (not tested) and related 64-bit fixes.

* FreeBSD support.

* `--set-rpath', `--shrink-rpath' and `--print-rpath' now prefer
  DT_RUNPATH over DT_RPATH, which is obsolete.  When updating, if both
  are present, both are updated.  If only DT_RPATH is present, it is
  converted to DT_RUNPATH unless `--force-rpath' is specified.  If
  neither is present, a DT_RUNPATH is added unless `--force-rpath' is
  specified, in which case a DT_RPATH is added.

0.3 (May 24, 2007):

* Support for 64-bit ELF binaries (such as on x86_64-linux).

* Support for big-endian ELF binaries (such as on powerpc-linux).

* Various bugfixes.

0.2 (January 15, 2007):

* Provides a hack to get certain programs (such as the
  Belastingaangifte 2005) to work.

0.1 (October 11, 2005):

* Initial release.
