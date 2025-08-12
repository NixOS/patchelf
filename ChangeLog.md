## Release History

## 0.15.2 (August 12, 2025)

* In the autotools build system for the tests, pass a few more tool env vars in `TESTS_ENVIRONMENT`.

  Some of them are not used yet (at all, or at least not in this backport to the `0.15-maintenance` branch), but at least `STRIP` is.

## 0.15.1 (August 12, 2025)

The objective is to prepare a very conservative patch release which can be bumped in Nixpkgs immediately.

* Backport infra changes from later master (August 2025)
* Backport shellcheck fixes to test suite
* Backport C++ code quality fixes (all of https://github.com/NixOS/patchelf/pull/464 but the final two commits)

The behavior of this version should be essentially the same as 0.15.0.

## 0.15.0 (July 16, 2022)

* Add --add-debug option by @deadw00d in https://github.com/NixOS/patchelf/pull/367
* Add O_BINARY flag when opening files to allow compilation for Windows by @JagoGyselinck in https://github.com/NixOS/patchelf/pull/372
* Document --print-needed by @klemensn in https://github.com/NixOS/patchelf/pull/375
* modifyRPath: return early if new and old rpath are empty by @ehmry in https://github.com/NixOS/patchelf/pull/376
* Add comment explaining calculation for DT_MIPS_RLD_MAP_REL by @amjoseph-nixpkgs in https://github.com/NixOS/patchelf/pull/379
* Add --no-sort option by @amjoseph-nixpkgs in https://github.com/NixOS/patchelf/pull/378
* Handle DT_MIPS_XHASH and .MIPS.xhash by @amjoseph-nixpkgs in https://github.com/NixOS/patchelf/pull/380

## 0.14.5 (February 21, 2022)

* fix faulty version in 0.14.4

## 0.14.4 (February 21, 2022)

* Several test fixes to fix patchelf test suite on openbsd by @klemensn
* Allow multiple modifications in same call by @fzakaria in https://github.com/NixOS/patchelf/pull/361
* Add support to build with musl by @fzakaria in https://github.com/NixOS/patchelf/pull/362
* Fix typo: s/folllow/follow/ by @bjornfor in https://github.com/NixOS/patchelf/pull/366
* mips: fix incorrect polarity on dyn_offset; closes #364 by @a-m-joseph in https://github.com/NixOS/patchelf/pull/365

## 0.14.3 (December 05, 2021)

* this release adds support for static, pre-compiled patchelf binaries

## 0.14.2 (November 29, 2021)

* make version number in tarball easier to use for packagers

## 0.14.1 (November 28, 2021)

* build fix: add missing include

## 0.14 (November 27, 2021)

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

## 0.13.1 (November 27, 2021)

* Bug fixes:
  - fix setting empty rpath
  - use memcpy instead of strcpy to set rpath
  - Don't try to parse .dynamic section of type NOBITS
  - fix use-after-free in normalizeNoteSegments
  - correct EINTR handling in writeFile
  - Adjust PT_MIPS_ABIFLAGS segment if present
  - Adjust DT_MIPS_RLD_MAP_REL dynamic section entry if present
  - fix binaries without .gnu.hash section

## 0.13 (August 5, 2021)

* New `--add-rpath` flag.

* Bug fixes.

## 0.12 (August 27, 2020)

* New `--clear-symbol-version` flag.

* Better support for relocating NOTE sections/segments.

* Improved the default section alignment choice.

* Bug fixes.

## 0.11 (June 9, 2020)

* New `--output` flag.

* Some bug fixes.

## 0.10 (March 28, 2019)

* Many bug fixes. Please refer to the Git commit log:

    https://github.com/NixOS/patchelf/commits/master

  This release has contributions from Adam Trhoň, Benjamin Hipple,
  Bernardo Ramos, Bjørn Forsman, Domen Kožar, Eelco Dolstra, Ezra
  Cooper, Felipe Sateler, Jakub Wilk, James Le Cuirot, Karl Millar,
  Linus Heckemann, Nathaniel J. Smith, Richard Purdie, Stanislav
  Markevich and Tuomas Tynkkynen.

## 0.9 (February 29, 2016)

* Lots of new features. Please refer to the Git commit log:

    https://github.com/NixOS/patchelf/commits/master

  This release has contributions from Aaron D. Marasco, Adrien
  Devresse, Alexandre Pretyman, Changli Gao, Chingis Dugarzhapov,
  darealshinji, David Sveningsson, Eelco Dolstra, Felipe Sateler,
  Jeremy Sanders, Jonas Kuemmerlin, Thomas Tuegel, Tuomas Tynkkynen,
  Vincent Danjean and Vladimír Čunát.

## 0.8 (January 15, 2014)

* Fix a segfault caused by certain illegal entries in symbol tables.

## 0.7 (January 7, 2014)

* Rewrite section indices in symbol tables. This for instance allows
  gdb to show proper backtraces.

* Added `--remove-needed' option.

## 0.6 (November 7, 2011)

* Hacky support for executables created by the Gold linker.

* Support segments with an alignment of 0 (contributed by Zack
  Weinberg).

* Added a manual page (contributed by Jeremy Sanders
  <jeremy@jeremysanders.net>).

## 0.5 (November 4, 2009)

* Various bugfixes.

* `--force-rpath' now deletes the DT_RUNPATH if it is present.

## 0.4 (June 4, 2008)

* Support for growing the RPATH on dynamic libraries.

* IA-64 support (not tested) and related 64-bit fixes.

* FreeBSD support.

* `--set-rpath', `--shrink-rpath' and `--print-rpath' now prefer
  DT_RUNPATH over DT_RPATH, which is obsolete.  When updating, if both
  are present, both are updated.  If only DT_RPATH is present, it is
  converted to DT_RUNPATH unless `--force-rpath' is specified.  If
  neither is present, a DT_RUNPATH is added unless `--force-rpath' is
  specified, in which case a DT_RPATH is added.

## 0.3 (May 24, 2007)

* Support for 64-bit ELF binaries (such as on x86_64-linux).

* Support for big-endian ELF binaries (such as on powerpc-linux).

* Various bugfixes.

## 0.2 (January 15, 2007)

* Provides a hack to get certain programs (such as the
  Belastingaangifte 2005) to work.

## 0.1 (October 11, 2005)

* Initial release.
