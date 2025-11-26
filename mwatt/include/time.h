/**
 * time.h - Time-related utility functions for Microwatt
 *
 * This header provides functions for accessing the Microwatt timebase
 * register and implementing time-related utilities.
 */

#ifndef TIME_H
#define TIME_H

/**
 * Get the current value of the PowerPC timebase register.
 *
 * This function safely reads the 64-bit timebase value by ensuring
 * the upper and lower 32-bit parts are read consistently.
 *
 * @return The current 64-bit timebase value
 */
static inline uint64_t get_tb(void) {
	uint32_t tbu0, tbl, tbu1;
	__asm__ volatile(
			"1:                 \n\t"
			"mfspr  %0, 269     \n\t" /* TBU */
			"mfspr  %1, 268     \n\t" /* TBL */
			"mfspr  %2, 269     \n\t" /* TBU again */
			"cmpw   %0, %2      \n\t"
			"bne-   1b          \n\t"
			: "=&r"(tbu0), "=&r"(tbl), "=&r"(tbu1)
			:
			: "memory");
	return ((uint64_t)tbu0 << 32) | tbl;
}

/**
 * Simple delay function that busy-waits for a specified number of cycles.
 *
 * @param cycles Number of busy-loop iterations to perform
 */
static inline void delay(unsigned long cycles)
{
	for (volatile unsigned long i = 0; i < cycles; i++)
	{
		/* do nothing */
	}
}

#endif /* TIME_H */