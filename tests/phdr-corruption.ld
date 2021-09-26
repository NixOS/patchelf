PHDRS
{
  headers PT_PHDR PHDRS;
  text PT_LOAD FILEHDR PHDRS;
  interp PT_INTERP ;
}

SECTIONS
{
  . = SIZEOF_HEADERS;
  . = ALIGN(4);

  . = . + 0x1000;
  .interp : { *(.interp) } :text :interp
  .text : { *(.text) } :text
}
