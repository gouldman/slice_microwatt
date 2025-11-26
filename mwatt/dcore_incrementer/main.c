#include <stdint.h>
#include <stdbool.h>

#include "console.h"
#include "io.h"
#include "microwatt_soc.h"

#include "multicore.h"
#include "time.h"

/* Console lock for synchronizing console access */
static spinlock_t console_lock = 0;

/* Lock console to prevent output interleaving */
static inline void lock_console(void)
{
    spinlock_lock(&console_lock);
}

/* Unlock console after output is complete */
static inline void unlock_console(void)
{
    spinlock_unlock(&console_lock);
}

/* Shared global counter, both CPUs increment it */
static volatile uint64_t global_count = 0;

/* Common loop each core will run to demonstrate concurrency */
static void concurrency_loop(void)
{
	uint64_t me = read_pir(); /* which core am I? */

	while (1)
	{
		/* Non-atomic increment for demonstration */
		uint64_t c = global_count;
		c++;
		global_count = c;
		lock_console();
		puts("Core ");
		print_uint64(me);
		puts(" increments count => ");
		print_uint64(c);
		puts("\n");
		unlock_console();
		delay(1); /* spin a little */
	}
}

int main(void)
{
	console_init();

	lock_console();
	puts("Hello from CPU0!\n");
	unlock_console();

	/* Enable CPU0 and CPU1 */
	enable_cpus(0x03);

	/* Now loop forever incrementing the global count */
	concurrency_loop();
	return 0;
}

/* Called by head.S if PIR == 1 */
void secondary_main(void)
{
	console_init();

	lock_console();
	puts("Hello from CPU1!\n");
	unlock_console();

	/* Same concurrency loop but from CPU1 */
	concurrency_loop();
}
