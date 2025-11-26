#include "console.h"
#include "io.h"
#include "microwatt_soc.h"

#include "multicore.h"
#include "queue.h"

static uint64_t done = 0;

static void greet(void)
{
  // Get PIR
  uint64_t me = read_pir();

  // Print message
  puts("Hello, from CPU");
  print_uint64(me);
  puts("\n");
}

int main(void)
{
  // Enable FPU
  enable_fpu();

	// Enable CPU0 and CPU1
	enable_cpus(0x03);

  // Initialize the floating-point registers with test values
  double val1 = 1.0f;
  double val2 = 2.0f;
  double val3 = 3.0f;
  double val4 = 4.0f;
  __asm__ volatile("lfd 1, %0" : : "m"(val1));
  __asm__ volatile("lfd 2, %0" : : "m"(val2));
  __asm__ volatile("lfd 3, %0" : : "m"(val3));
  __asm__ volatile("lfd 4, %0" : : "m"(val4));

  // Store double values to hardware queue
  stfdxq(1);
  stfdxq(2);
  stfdxq(3);
  stfdxq(4);

  // Wait for CPU1 to finish
  while(!done) {
    /* Stall */
  }

  return 0;
}

void secondary_main(void)
{
  // Enable FPU
  enable_fpu();

  // Read double values from hardware queue  
  lfdxq(1);
  lfdxq(2);
  lfdxq(3);
  lfdxq(4);

  // Finish
  done = 1;
}