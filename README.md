PatchELF
===============
**PatchELF** is a simple utility to modify header data of ELF executables
and libraries. It can change the dynamic loader ("ELF interpreter")
of executables, change existing DT_SONAME entries of shared libraries
and manipulate the RPATH and DT_NEEDED entries of executables and libraries.

Run `patchelf --help` or see the manpage (`man patchelf`) for more information.


**Installation:**<br>
```
./bootstrap.sh
./configure
make check strip
make install
```


**Homepage:** http://nixos.org/patchelf.html<br>


**License:**<br>
Copyright (c) 2004-2014 Eelco Dolstra <eelco.dolstra@logicblox.com>,
              2014      djcj <djcj@gmx.de>

Contributors: Zack Weinberg, vdanjean, rgcjonas

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.


**Release history:**

0.8 (January 15, 2014):
* Fix a segfault caused by certain illegal entries in symbol tables.

0.7 (January 7, 2014):
* Rewrite section indices in symbol tables. This for instance allows
  gdb to show proper backtraces.
* Added '--remove-needed' option.

0.6 (November 7, 2011):
* Hacky support for executables created by the Gold linker.
* Support segments with an alignment of 0 (contributed by Zack
  Weinberg).
* Added a manual page (contributed by Jeremy Sanders
  <jeremy@jeremysanders.net>).

0.5 (November 4, 2009):
* Various bugfixes.
* '--force-rpath' now deletes the DT_RUNPATH if it is present.

0.4 (June 4, 2008):
* Support for growing the RPATH on dynamic libraries.
* IA-64 support (not tested) and related 64-bit fixes.
* FreeBSD support.
* '--set-rpath', '--shrink-rpath' and '--print-rpath' now prefer
  DT_RUNPATH over DT_RPATH, which is obsolete.  When updating, if both
  are present, both are updated.  If only DT_RPATH is present, it is
  converted to DT_RUNPATH unless '--force-rpath' is specified.  If
  neither is present, a DT_RUNPATH is added unless '--force-rpath' is
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

