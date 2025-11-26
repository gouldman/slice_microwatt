
#include <stdint.h>
#include <stdbool.h>
#include "console.h"
#include "io.h"
#include "microwatt_soc.h"

#include "time.h"
#include "multicore.h"

#define ARRAY_SIZE 1024

static uint32_t mydata[ARRAY_SIZE];
static volatile uint32_t partial_sum[2]; /* sum from CPU0, CPU1 */
static volatile uint32_t final_sum;

static void fill_array(void)
{
	for (int i = 0; i < ARRAY_SIZE; i++)
	{
		mydata[i] = (uint32_t)(i + 1); /* or something */
	}
}

static uint32_t sum_array(uint32_t start, uint32_t end)
{
	uint32_t sum = 0;
	for (uint32_t i = start; i < end; i++)
	{
		sum += mydata[i];
	}
	return sum;
}

/* CPU1 calls this after console_init */
void secondary_main(void)
{
	puts("Hello from CPU1!\n");

	/* Wait until CPU0 tells us to start the parallel sum */
	while (final_sum != 0x12345678)
	{
		/* spin */
	}

	/* Do the top half of the array. Store partial result. */
	partial_sum[1] = sum_array(ARRAY_SIZE / 2, ARRAY_SIZE);

	/* Indicate we are done by setting final_sum=2. We use final_sum
		 as a crude barrier so CPU0 knows when CPU1 is done. */
	final_sum = 2;

	while (1)
	{
		/* spin forever */
	}
}

int main(void)
{
	console_init();

	puts("Hello from CPU0!\n");

  /* 1) Enable CPU0 & CPU1 */
	enable_cpus(0x03); 

	/* 2) Fill the array. */
	fill_array();

	/* 3) (A) Single-thread sum benchmark */
	uint64_t start = get_tb();
	uint32_t sum_st = sum_array(0, ARRAY_SIZE);
	uint64_t end = get_tb();

	puts("Single-thread sum = ");
	{
		// we can do a quick decimal print:
		print_uint64(sum_st);
		puts(", cycles = ");
		print_uint64(end - start);
		puts("\n");
	}

	/* 4) (B) Reset partial_sum and do a 2-core sum benchmark */

	partial_sum[0] = 0;
	partial_sum[1] = 0;
	final_sum = 0x12345678; /* signal to CPU1 to start sum */

	/* CPU0 sums first half */
	start = get_tb();
	partial_sum[0] = sum_array(0, ARRAY_SIZE / 2);

	/* Wait for CPU1 to finish */
	while (final_sum != 2)
	{
		/* spin */
	}

	/* Now partial_sum[0] + partial_sum[1] is the total */
	uint64_t end2 = get_tb();
	final_sum = partial_sum[0] + partial_sum[1];

	puts("Two-core sum = ");
	print_uint64(final_sum);
	puts(", cycles = ");
	print_uint64(end2 - start);
	puts("\n");

	while (1)
	{
		/* do nothing */
	}
	return 0;
}
