#include <stdint.h>
#include <stdbool.h>

#include "console.h"
#include "io.h"
#include "microwatt_soc.h"

#include "queue.h"

int main(void)
{

	// Enable floating point unit
	enable_fpu();

    uint32_t values_test = 0;
    if (values_test) {

        // Initialize the floating-point register with a test value
        float val1 = 1.0f;
        float val2 = 2.0f;
        float val3 = 3.0f;
        float val4 = 4.0f;
        __asm__ volatile("lfs 1, %0" : : "m"(val1));
        __asm__ volatile("lfs 2, %0" : : "m"(val2));
        __asm__ volatile("lfs 3, %0" : : "m"(val3));
        __asm__ volatile("lfs 4, %0" : : "m"(val4));

        // Store double values to hardware queue
        stfsxq(1);
        stfsxq(2);
        stfsxq(3);
        stfsxq(4);

        // Read double values from hardware queue
        lfsxq(1);
        lfsxq(2);
        lfsxq(3);
        lfsxq(4);

    } else {

        // Initialize the registers with test address
        double val1 = 1.0f;
        double val2 = 2.0f;
        double val3 = 3.0f;
        double val4 = 4.0f;
        __asm__ volatile("addi 3, %0, 0" : : "b"(&val1));  // Load address of val1 into GPR 3
        __asm__ volatile("addi 4, %0, 0" : : "b"(&val2));  // Load address of val2 into GPR 4
        __asm__ volatile("addi 5, %0, 0" : : "b"(&val3));  // Load address of val3 into GPR 5
        __asm__ volatile("addi 6, %0, 0" : : "b"(&val4));  // Load address of val4 into GPR 6

        // Store addresses to hardware queue
        stafdxq(3);
        stafdxq(4);
        stafdxq(5);
        stafdxq(6);

        // Read values from hardware queue (lfsxq does not work until proper data loaded in queue)
        lfdxq(1);
        lfdxq(2);
        lfdxq(3);
        lfdxq(4);

    }

	return 0;
}
