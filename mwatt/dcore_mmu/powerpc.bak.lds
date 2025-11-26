SECTIONS
{
  . = 0;
  _start = .;
  .head : {
    KEEP(*(.head))
  }
  
  /* Start text section after head, with alignment */
  . = 0x1000;
  .text : {
    *(.text)
    *(.text.*)
    *(.text.exceptions)
    *(.text.testcode)
    *(.rodata)
    *(.rodata.*)
    *(.eh_frame)
    *(.eh_frame.*)
  }
  
  . = ALIGN(0x1000);
  .data : { 
    *(.data) 
    *(.data.*) 
    *(.got) 
    *(.toc) 
  }

  . = ALIGN(0x80);
  __bss_start = .;
  .bss : {
    *(.dynsbss)
    *(.sbss)
    *(.scommon)
    *(.dynbss)
    *(.bss)
    *(.common)
    *(.bss.*)
  }
  . = ALIGN(0x80);
  __bss_end = .;
	
  /* Stack for Core 0 */
  . = ALIGN(0x1000);
  . = . + 0x4000;  /* 16KB stack */
  __stack_top_core0 = .;

  /* Stack for Core 1 */
  . = ALIGN(0x1000);
  . = . + 0x4000;  /* 16KB stack */
  __stack_top_core1 = .;
  
  /* Keep original stack definition for compatibility */
  __stack_top = __stack_top_core0;
}