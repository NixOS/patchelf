PatchELFmod
===============
**PatchELFmod** is a simple utility for modifing existing ELF executables
and libraries.<br>
In particular, it can do the following:

Change the ELF interpreter of an executable:<br>
  `patchelfmod --interpreter  <interpreter>  <elf-file>`<br>

Print the ELF interpreter of an executable:<br>
  `patchelfmod --print-interpreter  <elf-file>`<br>

Change the RPATH of an executable or library:<br>
  `patchelfmod --set-rpath  <rpath>  <elf-file>`<br>

Remove all directories from RPATH that do not contain<br>
a library referenced by DT_NEEDED fields:<br>
  `patchelfmod --shrink-rpath  <elf-file>`<br>

Print the RPATH of an executable or library:<br>
  `patchelfmod --print-rpath  <elf-file>`<br>

Force the use of the obsolete DT_RPATH instead of DT_RUNPATH:<br>
  `patchelfmod --force-rpath  <elf-file>`<br>

Add or remove a declared dependencies on a dynamic library:<br>
  `patchelfmod --add-needed  <library>  <elf-file>`<br>
  `patchelfmod --remove-needed  <library>  <elf-file>`<br>
This option can be given multiple times.<br>

Add or remove several declared dependencies on a dynamic library at once:<br>
  `patchelfmod --add-list  <library1>,<library2>,...  <elf-file>`<br>
  `patchelfmod --remove-list  <library1>,<library2>,...  <elf-file>`<br>

Replace a declared dependency on a dynamic library:<br>
  `patchelfmod --replace-needed  <library>  <new library>  <elf-file>`<br>
This option can be given multiple times.<br>

Run `patchelfmod --help` or see the manpage (`man patchelfmod`) for more information.
For known bugs see BUGS file.


**Installation:**<br>
`./bootstrap.sh`<br>
`./configure && make && make check`<br>
`strip src/patchelfmod`<br>
`make install`<br>


**Homepage:** https://github.com/darealshinji/patchelfmod<br>


**License:**<br>
Copyright (c)  see AUTHORS file

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

0.8m (April 02, 2014):
* Add '--add-needed' and '--replace-needed' options
  (contributed by rgcjonas).
* Add the following options:
  --add-list/--add-needed-list,
  --remove-list/--remove-needed-list
* Add tests for new options.
* Changes in the no-rpath test (contributed by vdanjean),
  but without multi-arch tests.
* Add Debian folder.
* Update manpage and documentation.
* Mentioning of ALL known authors.
* Some minor changes.

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
