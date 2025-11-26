
#define FIXUP_ENDIAN						   \
	tdi   0,0,0x48;	  /* Reverse endian of b . + 8		*/ \
	b     191f;	  /* Skip trampoline if endian is good	*/ \
	.long 0xa600607d; /* mfmsr r11				*/ \
	.long 0x01006b69; /* xori r11,r11,1			*/ \
	.long 0x05009f42; /* bcl 20,31,$+4			*/ \
	.long 0xa602487d; /* mflr r10				*/ \
	.long 0x14004a39; /* addi r10,r10,20			*/ \
	.long 0xa64b5a7d; /* mthsrr0 r10			*/ \
	.long 0xa64b7b7d; /* mthsrr1 r11			*/ \
	.long 0x2402004c; /* hrfid				*/ \
191:


/* Load an immediate 64-bit value into a register */
#define LOAD_IMM64(r, e)			\
	lis     r,(e)@highest;			\
	ori     r,r,(e)@higher;			\
	rldicr  r,r, 32, 31;			\
	oris    r,r, (e)@h;			\
	ori     r,r, (e)@l;

	.section ".head","ax"

	/*
	 * Microwatt currently enters in LE mode at 0x0, so we don't need to
	 * do any endian fix ups>
	 */
	. = 0
.global _start
_start:
	b	boot_entry

	/* QEMU enters at 0x10 */
	. = 0x10
	FIXUP_ENDIAN
	b	boot_entry

	. = 0x100
	FIXUP_ENDIAN
	b	boot_entry

.global boot_entry
boot_entry:
    mfspr   3, 1023        ; /* r3 = PIR */
    cmpwi   3, 0
    bne     boot_secondary  ; /* If PIR!=0 => go do CPU1’s path */

    /* == CPU0 path == */
    /* Clear BSS, just like you do now */
    LOAD_IMM64(%r10,__bss_start)
    LOAD_IMM64(%r11,__bss_end)
    subf    %r11,%r10,%r11
    addi    %r11,%r11,63
    srdi.   %r11,%r11,6
    beq     2f
    mtctr   %r11
1:  dcbz    0,%r10
    addi    %r10,%r10,64
    bdnz    1b

2:  /* Setup stack for CPU0 */
    LOAD_IMM64(%r1,__stack_top_core0)
    li      %r0,0
    stdu    %r0,-32(%r1)

    /* Call main */
    LOAD_IMM64(%r12, main)
    mtctr   %r12
    bctrl

    /* If main returns, loop or attn */
    attn
    b .

boot_secondary:
    /* == CPU1 path == */
    /* CPU1 stack */
    LOAD_IMM64(%r1,__stack_top_core1)
    li      %r0,0
    stdu    %r0,-32(%r1)

    /* Jump to secondary_main() in C */
    LOAD_IMM64(%r12, secondary_main)
    mtctr   %r12
    bctrl

    attn
    b .

#define EXCEPTION(nr)		\
	.= nr			;\
	b	.

	/* More exception stubs */
	EXCEPTION(0x300)
	EXCEPTION(0x380)
	EXCEPTION(0x400)
	EXCEPTION(0x480)
	EXCEPTION(0x500)
	EXCEPTION(0x600)
	EXCEPTION(0x700)
	EXCEPTION(0x800)
	EXCEPTION(0x900)
	EXCEPTION(0x980)
	EXCEPTION(0xa00)
	EXCEPTION(0xb00)
	EXCEPTION(0xc00)
	EXCEPTION(0xd00)
	EXCEPTION(0xe00)
	EXCEPTION(0xe20)
	EXCEPTION(0xe40)
	EXCEPTION(0xe60)
	EXCEPTION(0xe80)
	EXCEPTION(0xf00)
	EXCEPTION(0xf20)
	EXCEPTION(0xf40)
	EXCEPTION(0xf60)
	EXCEPTION(0xf80)
#if 0
	EXCEPTION(0x1000)
	EXCEPTION(0x1100)
	EXCEPTION(0x1200)
	EXCEPTION(0x1300)
	EXCEPTION(0x1400)
	EXCEPTION(0x1500)
	EXCEPTION(0x1600)
#endif
