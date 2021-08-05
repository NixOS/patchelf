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

```console
./bootstrap.sh
./configure
make
make check
sudo make install
```

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
