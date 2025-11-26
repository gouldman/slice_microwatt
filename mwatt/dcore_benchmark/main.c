#include "console.h"
#include "io.h"
#include "microwatt_soc.h"

#include "multicore.h"
#include "queue.h"

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

int main(void)
{
  // Enable UART
  console_init();

  // Enable FPU
  enable_fpu();

  // Enable CPU1 (and CPU0)
  enable_cpus(0x03);

  // Initialize values
  double val1 = 55.0f;
  double val2 = 44.0f;
  double val3 = 33.0f;
  double val4 = 22.0f;
  uint64_t addr1 = (uint64_t)&val1;
  uint64_t addr2 = (uint64_t)&val2;
  uint64_t addr3 = (uint64_t)&val3;
  uint64_t addr4 = (uint64_t)&val4;
  
  // Send addresses to GPRs
  puts("[Core0]: Sending the following addresses to the queue \n");
  puts("[Core0]: "); print_hex(addr1); puts(" -> "); print_hex(*(unsigned long*)&val1); puts("\n");
  puts("[Core0]: "); print_hex(addr2); puts(" -> "); print_hex(*(unsigned long*)&val2); puts("\n");
  puts("[Core0]: "); print_hex(addr3); puts(" -> "); print_hex(*(unsigned long*)&val3); puts("\n");
  puts("[Core0]: "); print_hex(addr4); puts(" -> "); print_hex(*(unsigned long*)&val4); puts("\n");
  __asm__ volatile("ld 14, %0" : : "m"(addr1));
  __asm__ volatile("ld 15, %0" : : "m"(addr2));
  __asm__ volatile("ld 16, %0" : : "m"(addr3));
  __asm__ volatile("ld 17, %0" : : "m"(addr4));

  // Send addresses in GPRs to queue
  stafdxq(14);
  stafdxq(15);
  stafdxq(16);
  stafdxq(17);

  // Reading result from the queue
  lfdxq(1);
  puts("[Core0]: Got the following value from the queue \n");
  double result;
  __asm__ volatile("stfd 1, %0" : "=m"(result));
  puts("[Core0]: "); print_hex(*(unsigned long*)&result); puts("\n");

  return 0;
}

void secondary_main(void)
{
  // Enable FPU
  enable_fpu();

  // Read values in queue and store in FPRs
  lfdxq(1);
  lfdxq(2);
  lfdxq(3);
  lfdxq(4);

  // Enable UART
  console_init();

  // Read values from FPRs
  puts("[Core1]: Got the following values from the queue \n");
  double res1, res2, res3, res4;
  __asm__ volatile("stfd 1, %0" : "=m"(res1));
  __asm__ volatile("stfd 2, %0" : "=m"(res2));
  __asm__ volatile("stfd 3, %0" : "=m"(res3));
  __asm__ volatile("stfd 4, %0" : "=m"(res4));
  puts("[Core1]: "); print_hex(*(unsigned long*)&res1); puts("\n");
  puts("[Core1]: "); print_hex(*(unsigned long*)&res2); puts("\n");
  puts("[Core1]: "); print_hex(*(unsigned long*)&res3); puts("\n");
  puts("[Core1]: "); print_hex(*(unsigned long*)&res4); puts("\n");

  // Compute sum and send it to the queue
  puts("[Core1]: Computing the sum...\n");
  double sum = res1 + res2 + res3 + res4;
  __asm__ volatile("lfd 5, %0" : : "m"(sum));
  puts("[Core1]: Sending the following value to the queue \n");
  puts("[Core1]: "); print_hex(*(unsigned long*)&sum); puts("\n");
  stfdxq(5);

  while(1) {
    /* Stall */
  }

}