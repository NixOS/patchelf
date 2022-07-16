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

### Via Autotools
```console
./bootstrap.sh
./configure
make
make check
sudo make install
```
### Via Nix

You can build with Nix in several ways.

1. Building via `nix build` will produce the result in `./result/bin/patchelf`. If you would like to build _patchelf_ with _musl_ try `nix build .#patchelf-musl`

2. You can launch a development environment with `nix develop` and follow the autotools steps above. If you would like to develop with _musl_ try `nix develop .#musl`

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
