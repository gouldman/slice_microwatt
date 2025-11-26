/*
 * Linker Script
 */

SECTIONS
{
  /* Program entry point at address 0 */
  . = 0;
  _start = .;

  /* .head section contains the boot code */
  .head : {
    KEEP(*(.head))
  }

  /* Align text section to 4KB boundary for MMU page alignment */
  . = ALIGN(0x1000);
  
  /* .text section contains executable code and read-only data */
  .text : { 
      *(.text) 
      *(.text.*) 
      *(.rodata) 
      *(.rodata.*)
      /* Include exception handling frames in .text to avoid overlap with .bss */
      *(.eh_frame)
      *(.eh_frame.*)
  }

  /* Align data section to 4KB boundary for MMU page alignment */
  . = ALIGN(0x1000);
  
  /* .data section contains initialized global variables */
  .data : { 
      *(.data) 
      *(.data.*) 
      /* Global Offset Table and Table of Contents used by the PowerPC ABI */
      *(.got) 
      *(.toc) 
  }

  /* Align BSS to 128-byte boundary (0x80) */
  . = ALIGN(0x80);
  __bss_start = .;

  /* .bss section contains uninitialized data */
  .bss : {
      *(.dynsbss)  /* Dynamic shared BSS */
      *(.sbss)     /* Small BSS */
      *(.scommon)  /* Small common symbols */
      *(.dynbss)   /* Dynamic BSS */
      *(.bss)      /* Standard BSS */
      *(.common)   /* Common symbols */
      *(.bss.*)    /* Any other BSS sections */
  }

  /* End of BSS section, aligned to 128-byte boundary */
  . = ALIGN(0x80);
  __bss_end = .;

  /* Reserve space for Core 0 stack (8KB) */
  . = . + 0x2000;
  __stack_top_core0 = .;
  
  /* Reserve space for Core 1 stack (8KB) */
  . = . + 0x2000;
  __stack_top_core1 = .;
}