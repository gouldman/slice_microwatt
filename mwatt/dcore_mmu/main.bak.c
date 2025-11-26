#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#include "console.h"
#include "io.h"
#include "microwatt_soc.h"

#include "multicore.h"
#include "queue.h"

/* Machine State Register (MSR) bits */
#define MSR_LE	0x1                   /* Little Endian mode */
#define MSR_DR	0x10                  /* Data Relocate (MMU for data enabled) */
#define MSR_IR	0x20                  /* Instruction Relocate (MMU for instructions enabled) */
#define MSR_HV	0x1000000000000000ul  /* Hypervisor mode */
#define MSR_SF	0x8000000000000000ul  /* 64-bit mode */

/* External functions defined in assembly */
extern int test_read(long *addr, long *ret, long init);
extern int test_write(long *addr, long val);
extern int test_dcbz(long *addr);
extern int test_exec(int testno, unsigned long pc, unsigned long msr);

/* TLB Invalidate Entry instruction - clears a TLB entry */
static inline void do_tlbie(unsigned long rb, unsigned long rs)
{
	__asm__ volatile("tlbie %0,%1" : : "r" (rb), "r" (rs) : "memory");
}

/* Special Purpose Register (SPR) numbers */
#define DSISR	18      /* Data Storage Interrupt Status Register */
#define DAR	19        /* Data Address Register */
#define SRR0    26      /* Save/Restore Register 0 (stores address after interrupt) */
#define SRR1    27      /* Save/Restore Register 1 (stores MSR after interrupt) */
#define PID	48        /* Process ID register */
#define PTCR    464     /* Page Table Control Register */

/* Function to read from a Special Purpose Register */
static inline unsigned long mfspr(int sprnum)
{
	long val;

	__asm__ volatile("mfspr %0,%1" : "=r" (val) : "i" (sprnum));
	return val;
}

/* Function to write to a Special Purpose Register */
static inline void mtspr(int sprnum, unsigned long val)
{
	__asm__ volatile("mtspr %0,%1" : : "i" (sprnum), "r" (val));
}

/* Store a page table entry with proper endianness (byte-reversed) */
static inline void store_pte(unsigned long *p, unsigned long pte)
{
	__asm__ volatile("stdbrx %1,0,%0" : : "r" (p), "r" (pte) : "memory");
}

/* Utility function to print a hex value */
void print_hex(unsigned long val)
{
	int i, x;

	for (i = 60; i >= 0; i -= 4) {
		x = (val >> i) & 0xf;
		if (x >= 10)
			putchar(x + 'a' - 10);
		else
			putchar(x + '0');
	}
}

/* Print a test number (assumes number is < 100) */
void print_test_number(int i)
{
	puts("test ");
	putchar(48 + i/10);
	putchar(48 + i%10);
	putchar(':');
}

#define CACHE_LINE_SIZE	64

/* Zero out a memory region, using dcbz (data cache block zero) instruction 
   for efficiency when possible */
void zero_memory(void *ptr, unsigned long nbytes)
{
	unsigned long nb, i, nl;
	void *p;

	for (; nbytes != 0; nbytes -= nb, ptr += nb) {
		nb = -((unsigned long)ptr) & (CACHE_LINE_SIZE - 1);
		if (nb == 0 && nbytes >= CACHE_LINE_SIZE) {
			nl = nbytes / CACHE_LINE_SIZE;
			p = ptr;
			for (i = 0; i < nl; ++i) {
				__asm__ volatile("dcbz 0,%0" : : "r" (p) : "memory");
				p += CACHE_LINE_SIZE;
			}
			nb = nl * CACHE_LINE_SIZE;
		} else {
			if (nb > nbytes)
				nb = nbytes;
			for (i = 0; i < nb; ++i)
				((unsigned char *)ptr)[i] = 0;
		}
	}
}

/* Page permission and attribute flags */
#define PERM_EX		0x001  /* Execute permission */
#define PERM_WR		0x002  /* Write permission */
#define PERM_RD		0x004  /* Read permission */
#define PERM_PRIV	0x008  /* Privileged access only */
#define ATTR_NC		0x020  /* Non-cacheable */
#define CHG		    0x080  /* Changed (dirty) bit */
#define REF		    0x100  /* Referenced bit */

/* Default permissions for data pages */
#define DFLT_PERM	(PERM_WR | PERM_RD | REF | CHG)

/*
 * Set up an MMU translation tree using memory starting at the 64k point.
 * We use 2 levels, mapping 2GB (the minimum size possible), with a
 * 8kB PGD level pointing to 4kB PTE pages.
 */
unsigned long *pgdir = (unsigned long *) 0x10000;      /* Page directory (top level) */
unsigned long *proc_tbl = (unsigned long *) 0x12000;   /* Process table */
unsigned long *part_tbl = (unsigned long *) 0x13000;   /* Partition table */
unsigned long free_ptr = 0x14000;                      /* Next free memory for page tables */
void *eas_mapped[4];                                   /* Track mapped effective addresses */
int neas_mapped;                                       /* Count of mapped EAs */

/* Initialize the MMU tables */
void init_mmu(void)
{
   /* set up partition table */
   store_pte(&part_tbl[1], (unsigned long)proc_tbl);
   /* set up process table */
   zero_memory(proc_tbl, 512 * sizeof(unsigned long));
   mtspr(PTCR, (unsigned long)part_tbl);  /* Set page table control register */
   mtspr(PID, 1);                         /* Set process ID */
   zero_memory(pgdir, 1024 * sizeof(unsigned long));
   /* RTS = 0 (2GB address space), RPDS = 10 (1024-entry top level) */
   store_pte(&proc_tbl[2 * 1], (unsigned long) pgdir | 10);
   do_tlbie(0xc00, 0);	/* invalidate all TLB entries */
}

/* Read a page directory entry with proper endianness */
static unsigned long *read_pgd(unsigned long i)
{
   unsigned long ret;

   __asm__ volatile("ldbrx %0,%1,%2" : "=r" (ret) : "b" (pgdir),
        "r" (i * sizeof(unsigned long)));
   return (unsigned long *) (ret & 0x00ffffffffffff00);
}

/* Map a virtual address (ea) to a physical address (pa) with specified permissions */
void map(void *ea, void *pa, unsigned long perm_attr)
{
   unsigned long epn = (unsigned long) ea >> 12;  /* Effective page number */
   unsigned long i, j;
   unsigned long *ptep;

   /* Calculate page directory index (i) and page table index (j) */
   i = (epn >> 9) & 0x3ff;
   j = epn & 0x1ff;
   
   /* If no page table exists for this directory entry, create one */
   if (pgdir[i] == 0) {
     zero_memory((void *)free_ptr, 512 * sizeof(unsigned long));
     store_pte(&pgdir[i], 0x8000000000000000 | free_ptr | 9);
     free_ptr += 512 * sizeof(unsigned long);
   }
   
   /* Get the page table pointer and store the PTE */
   ptep = read_pgd(i);
   /* 0xc0... indicates a valid, leaf PTE entry */
   store_pte(&ptep[j], 0xc000000000000000 | ((unsigned long)pa & 0x00fffffffffff000) | perm_attr);
   eas_mapped[neas_mapped++] = ea;  /* Track this mapping */
}

/* Remove a virtual address mapping */
void unmap(void *ea)
{
   unsigned long epn = (unsigned long) ea >> 12;
   unsigned long i, j;
   unsigned long *ptep;

   i = (epn >> 9) & 0x3ff;
   j = epn & 0x1ff;
   if (pgdir[i] == 0)
     return;
   ptep = read_pgd(i);
   ptep[j] = 0;  /* Clear the PTE */
   do_tlbie(((unsigned long)ea & ~0xfff), 0);  /* Invalidate TLB entry */
}

/* Remove all virtual address mappings */
void unmap_all(void)
{
   int i;

   for (i = 0; i < neas_mapped; ++i)
     unmap(eas_mapped[i]);
   neas_mapped = 0;
}

/* Test 1: Verify access to unmapped memory fails */
int mmu_test_1(void)
{
	long *ptr = (long *) 0x123000;  /* Unmapped address */
	long val;

	/* this should fail */
	if (test_read(ptr, &val, 0xdeadbeefd00d))
		return 1;
	/* dest reg of load should be unchanged */
	if (val != 0xdeadbeefd00d)
		return 2;
	/* DAR and DSISR should be set correctly */
	if (mfspr(DAR) != (long) ptr || mfspr(DSISR) != 0x40000000)
		return 3;
	return 0;
}

/* Test 2: Verify basic TLB hit and miss behavior for reads */
int mmu_test_2(void)
{
	long *mem = (long *) 0x8000;          /* Physical memory */
	long *ptr = (long *) 0x124000;        /* First virtual address */
	long *ptr2 = (long *) 0x1124000;      /* Second virtual address */
	long val;

	/* create PTE */
	map(ptr, mem, DFLT_PERM);
	/* initialize the memory content */
	mem[33] = 0xbadc0ffee;
	/* this should succeed and be a cache miss */
	if (!test_read(&ptr[33], &val, 0xdeadbeefd00d))
		return 1;
	/* dest reg of load should have the value written */
	if (val != 0xbadc0ffee)
		return 2;
	/* load a second TLB entry in the same set as the first */
	map(ptr2, mem, DFLT_PERM);
	/* this should succeed and be a cache hit */
	if (!test_read(&ptr2[33], &val, 0xdeadbeefd00d))
		return 3;
	/* dest reg of load should have the value written */
	if (val != 0xbadc0ffee)
		return 4;
	/* check that the first entry still works */
	if (!test_read(&ptr[33], &val, 0xdeadbeefd00d))
		return 5;
	if (val != 0xbadc0ffee)
		return 6;
	return 0;
}

/* Test 3: Test TLB entry removal */
int mmu_test_3(void)
{
	long *mem = (long *) 0x9000;
	long *ptr = (long *) 0x14a000;
	long val;

	/* create PTE */
	map(ptr, mem, DFLT_PERM);
	/* initialize the memory content */
	mem[45] = 0xfee1800d4ea;
	/* this should succeed and be a cache miss */
	if (!test_read(&ptr[45], &val, 0xdeadbeefd0d0))
		return 1;
	/* dest reg of load should have the value written */
	if (val != 0xfee1800d4ea)
		return 2;
	/* remove the PTE */
	unmap(ptr);
	/* this should fail */
	if (test_read(&ptr[45], &val, 0xdeadbeefd0d0))
		return 3;
	/* dest reg of load should be unchanged */
	if (val != 0xdeadbeefd0d0)
		return 4;
	/* DAR and DSISR should be set correctly */
	if (mfspr(DAR) != (long) &ptr[45] || mfspr(DSISR) != 0x40000000)
		return 5;
	return 0;
}

/* Test 4: Test writes with TLB hit/miss behavior */
int mmu_test_4(void)
{
	long *mem = (long *) 0xa000;
	long *ptr = (long *) 0x10b000;
	long *ptr2 = (long *) 0x110b000;
	long val;

	/* create PTE */
	map(ptr, mem, DFLT_PERM);
	/* initialize the memory content */
	mem[27] = 0xf00f00f00f00;
	/* this should succeed and be a cache miss */
	if (!test_write(&ptr[27], 0xe44badc0ffee))
		return 1;
	/* memory should now have the value written */
	if (mem[27] != 0xe44badc0ffee)
		return 2;
	/* load a second TLB entry in the same set as the first */
	map(ptr2, mem, DFLT_PERM);
	/* this should succeed and be a cache hit */
	if (!test_write(&ptr2[27], 0x6e11ae))
		return 3;
	/* memory should have the value written */
	if (mem[27] != 0x6e11ae)
		return 4;
	/* check that the first entry still exists */
	/* (assumes TLB is 2-way associative or more) */
	if (!test_read(&ptr[27], &val, 0xdeadbeefd00d))
		return 5;
	if (val != 0x6e11ae)
		return 6;
	return 0;
}

/* Execute one test, managing TLB flushing and error reporting */
void do_test(int num, int (*test)(void))
{
	int ret;

	mtspr(DSISR, 0);
	mtspr(DAR, 0);
	unmap_all();
	print_test_number(num);
	ret = test();
	if (ret == 0) {
		puts("PASS\r\n");
	} else {
		puts("FAIL ");
		putchar(ret + '0');
		if (num <= 10 || num == 19) {
			puts(" DAR=");
			print_hex(mfspr(DAR));
			puts(" DSISR=");
			print_hex(mfspr(DSISR));
		} else {
			puts(" SRR0=");
			print_hex(mfspr(SRR0));
			puts(" SRR1=");
			print_hex(mfspr(SRR1));
		}
		puts("\r\n");
	}
}

static void greet(void)
{
  // Get PIR
  uint64_t me = read_pir();

  // Print message
  puts("Hello, from CPU");
  print_uint64(me);
  puts("\n");
}

static volatile uint64_t done = 0;

/* Main function that runs on CPU0 */
int main(void)
{
	int fail = 0;

	// Initialize console for output
	console_init();
	
	// Initialize MMU
	init_mmu();
	
  // Print out greeting
  greet();

	// Enable CPU1 - it won't do anything yet but we can enable it
	// enable_cpus(0x03);
	
	puts("Starting MMU tests\r\n");
	
	// Run tests
	do_test(1, mmu_test_1);
	do_test(2, mmu_test_2);
	do_test(3, mmu_test_3);
	do_test(4, mmu_test_4);
	
	// Add the remaining tests here as needed

	puts("MMU tests completed\r\n");

	// Wait for CPU1 to finish
	while(!done) {
		/* Stall */
	}

  // Print out greeting
  greet();

	return fail;
}

/* Secondary function that runs on CPU1 */
void secondary_main(void)
{
	// Currently does nothing - we'll expand this later
	console_init();

  // Print out greeting
  greet();

	// Finish
	done = 1;

	// Wait for CPU0 to exit
	while (1) {
		/* Stall */
	}
}