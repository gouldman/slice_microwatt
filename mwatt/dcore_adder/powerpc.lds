SECTIONS
{
  . = 0;
  _start = .;
  .head : {
    KEEP(*(.head))
  }
  . = 0x1000;
  .text : {
    *(.text) *(.text.*) 
    *(.rodata) *(.rodata.*)
    /* Put .eh_frame here so it doesn't overlap .bss */
    *(.eh_frame)
    *(.eh_frame.*)
  }
  . = 0x1800;
  .data : { *(.data) *(.data.*) *(.got) *(.toc) }

  . = ALIGN(0x80);
  __bss_start = .;
  .bss : {
    *(.bss) *(.common)
  }
  . = ALIGN(0x80);
  __bss_end = .;
	
. = . + 0x2000;
__stack_top_core0 = .;

. = . + 0x2000;
__stack_top_core1 = .;
}
