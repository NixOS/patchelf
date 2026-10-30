SECTIONS
{
  .note.one : { *(.note.one) }
  .note.two : { *(.note.two) }
  .note.three : { *(.note.three) }
}
/* .interp is an orphan in the MIPS default linker script, so it cannot be
   used as an INSERT anchor. Keep the notes before the relocated .dynstr. */
INSERT BEFORE .dynsym;
