PHDRS
{
  headers PT_PHDR PHDRS ;
  notes PT_NOTE;
  text PT_LOAD FILEHDR PHDRS ;
  data PT_LOAD ;
  interp PT_INTERP ;
  dynamic PT_DYNAMIC ;
}

SECTIONS
{
  . = SIZEOF_HEADERS;
  . = ALIGN(4);

  .note.my-section0 : { *(.note.my-section0) } :notes :text
  .note.my-section1 : { *(.note.my-section1) } :notes :text

  .interp : { *(.interp) } :text :interp
  .text : { *(.text) } :text
  .rodata : { *(.rodata) } /* defaults to :text */

  .data : { *(.data) } :data
}
