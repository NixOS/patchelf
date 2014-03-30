PatchELF
===============
**PatchELF** is a simple utility for modifing existing ELF executables
and libraries. In particular, it can do the following:

 Change the ELF interpreter of an executable:<br>
   `patchelf --interpreter  <interpreter>  <elf-file>`<br>
   `patchelf --set-interpreter  <interpreter>  <elf-file>`<br>

 Print the ELF interpreter of an executable:<br>
   `patchelf --print-interpreter  <elf-file>`<br>

 Change the RPATH of an executable or library:<br>
   `patchelf --set-rpath  <rpath>  <elf-file>`<br>

 Remove all directories from RPATH that do not contain
 a library referenced by DT_NEEDED fields:<br>
   `patchelf --shrink-rpath  <elf-file>`<br>

 Print the RPATH of an executable or library:<br>
   `patchelf --print-rpath  <elf-file>`<br>

 Force the use of the obsolete DT_RPATH instead of DT_RUNPATH:<br>
   `patchelf --force-rpath  <elf-file>`<br>

 Add or remove one or more declared dependencies on a dynamic library:<br>
   `patchelf --add-needed  <library>  <elf-file>`<br>
   `patchelf --remove-needed  <library>  <elf-file>`<br>
   `patchelf --add-list  <library1>,<library2>,...  <elf-file>`<br>
   `patchelf --add-needed-list  <library1>,<library2>,...  <elf-file>`<br>
   `patchelf --remove-list  <library1>,<library2>,...  <elf-file>`<br>
   `patchelf --remove-needed-list  <library1>,<library2>,...  <elf-file>`<br>

 Replace a declared dependency on a dynamic library:<br>
   `patchelf --replace-needed  <library>  <new library>  <elf-file>`<br>

See the manpage ('man patchelf') for more information.


**Installation:**<br>
`$ ./bootstrap.sh`<br>
`$ ./configure`<br>
`$ make`<br>
`$ make check`<br>
`$ strip src/patchelf`<br>
`$ make install`<br>


**Homepage:**
http://nixos.org/patchelf.html


**Known bugs:**
See BUGS file.


**Release history:**

0.8-1 (March 29, 2014):

* Added `--add-needed' and `--replace-needed' options
  (contributed by rgcjonas)

* Added the following options:
  --add-list/--add-needed-list  <library1>,<library2>,...
  --remove-list/--remove-needed-list  <library1>,<library2>,...

* Changes in the no-rpath test (contributed by vdanjean),
  but without multi-arch tests

* Added Debian folder

* Update manpage

* Mentioning of ALL known authors

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

