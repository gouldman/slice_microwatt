/**
 * multicore.h - Multicore support utilities for Microwatt
 *
 * This header provides functions and utilities specifically designed for
 * multicore Microwatt systems, including processor identification
 * and synchronization primitives.
 */

#ifndef MULTICORE_H
#define MULTICORE_H


#include <stdint.h>

#include "io.h"
#include "microwatt_soc.h"

/**
 * Enable specified CPU cores in the system.
 * 
 * @param cpu_mask Bit mask where each bit position represents a CPU
 *                 (bit 0 = CPU0, bit 1 = CPU1, etc.)
 */
 void enable_cpus(uint64_t cpu_mask)
 {
		 uint64_t ctrl = readq(SYSCON_BASE + SYS_REG_CPU_CTRL);
		 ctrl |= cpu_mask;
		 writeq(ctrl, SYSCON_BASE + SYS_REG_CPU_CTRL);
 }

/**
 * Read the Processor ID Register (PIR).
 * The PIR contains a value that can be used to identify the specific processor
 * in a multi-processor system.
 *
 * @return The current processor's ID
 */
static inline uint64_t read_pir(void)
{
	uint64_t v;
	__asm__ volatile("mfspr %0, 1023" : "=r"(v));
	return v;
}

/**
 * A simple spinlock type for multicore synchronization.
 */
typedef volatile unsigned int spinlock_t;

 /**
 * Initialize a spinlock to the unlocked state.
 *
 * @param lock Pointer to the spinlock to initialize
 */
static inline void spinlock_init(spinlock_t *lock) {
	*lock = 0;
}

/**
 * Acquire a spinlock, blocking until it is available.
 * Uses PowerPC load-reserve/store-conditional atomic operations.
 *
 * @param lock Pointer to the spinlock to acquire
 */
 static inline void spinlock_lock(spinlock_t *lock) {
	unsigned int tmp;
	__asm__ volatile(
			"1:             \n"
			"lwarx  %0,0,%1 \n" /* load-reserve lock into tmp */
			"cmpwi  %0,0    \n"
			"bne-   1b      \n" /* if lock != 0, spin/retry */
			"li     %0,1    \n" /* tmp = 1 */
			"stwcx. %0,0,%1 \n" /* store-cond tmp into lock */
			"bne-   1b      \n" /* if lost reservation, retry */
			: "=&r"(tmp)
			: "r"(lock)
			: "cc", "memory");
}

/**
 * Release a previously acquired spinlock.
 *
 * @param lock Pointer to the spinlock to release
 */
 static inline void spinlock_unlock(spinlock_t *lock) {
	/* Memory barriers to ensure proper ordering */
	__asm__ volatile("eieio" ::: "memory");
	*lock = 0;
	__asm__ volatile("eieio" ::: "memory");
}

/**
 * Memory barrier to ensure previous stores are visible to other cores
 * before subsequent stores.
 */
 static inline void sync_cores(void) {
	__asm__ volatile("sync" ::: "memory");
}

#endif /* MULTICORE_H */