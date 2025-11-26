/**
 * queue.h - Abstraction for PowerISA extended queue instructions
 *
 * This header provides functions to use the hardware queue operations
 * from C code. These queue operations are used by the slice optimization
 * to improve performance of indirect memory accesses.
 */

 #ifndef QUEUE_H
 #define QUEUE_H
 
 #include <stdint.h>
 
 /* Opcodes */ 
 #define PO_X 31        /* Primary opcode for X-form instructions */
 #define EO_LFDXQ 700   /* Read 64-bit float from queue */
 #define EO_STAFDXQ 701 /* Write address of 64-bit float to queue */
 #define EO_STFDXQ 702  /* Write 64-bit float to queue */
 #define EO_LFSXQ 703   /* Read 32-bit float from queue */
 #define EO_STAFSXQ 704 /* Write address of 32-bit float to queue */
 #define EO_STFSXQ 705  /* Write 32-bit float to queue */
 
/**
 * Enables floating-point operations by setting the MSR[FP] bit.
 * This must be called before using any floating-point instructions.
 */
 void enable_fpu(void)
 {
     unsigned long msr;
     __asm__ volatile("mfmsr %0" : "=r"(msr));
     msr |= 0x2000;  // Set MSR[FP] bit
     __asm__ volatile("mtmsr %0" : : "r"(msr));
 }

 /**
  * Internal function to generate X-form PowerISA instructions.
  *
  * @param po Primary opcode
  * @param rt Target register
  * @param ra Address register A
  * @param rb Address register B
  * @param xo Extended opcode
  * @param rc Record bit
  */
 static inline void x_form(unsigned po, unsigned rt, unsigned ra, unsigned rb, unsigned xo, unsigned rc) {
   uint32_t instr = (po << 26) | (rt << 21) | (ra << 16) | (rb << 11) | (xo << 1) | (rc & 1);
 
   /* Emit the instruction directly using inline assembly */
   __asm__ volatile (".long %0" : : "i" (instr) : "memory");
 }
 
 
 /**
  * Load a 32-bit float from the hardware queue.
  * 
  * @param frt Floating-point register to load value into (0-31)
  */
 static inline void lfsxq(int frt) {
   x_form(PO_X, frt, 0, 0, EO_LFSXQ, 1);
 }
 
 /**
  * Store the address of a 32-bit float to the hardware queue.
  * The queue will prefetch this value for the consumer.
  *
  * @param rs Address register (0-31)
  */
 static inline void stafsxq(int rs) {
   // x_form(PO_X, 0, rs, 0, EO_STAFSXQ, 1);
   x_form(PO_X, 0, 0, rs, EO_STAFSXQ, 1);
 }
 
 /**
  * Store a 32-bit float directly to the hardware queue.
  *
  * @param frs Floating-point register containing value to store (0-31)
  */
 static inline void stfsxq(int frs) {
   x_form(PO_X, frs, 0, 0, EO_STFSXQ, 1);
 }
 
 /*
  * 64-bit double queue operations
  */
 
 /**
  * Load a 64-bit double from the hardware queue.
  * 
  * @param frt Floating-point register to load value into (0-31)
  */
 static inline void lfdxq(int frt) {
   x_form(PO_X, frt, 0, 0, EO_LFDXQ, 1);
 }
 
 /**
  * Store the address of a 64-bit double to the hardware queue.
  * The queue will prefetch this value for the consumer.
  *
  * @param rs Address register (0-31)
  */
 static inline void stafdxq(int rs) {
  // x_form(PO_X, 0, rs, 0, EO_STAFDXQ, 1);
   x_form(PO_X, 0, 0, rs, EO_STAFDXQ, 1);
 }
 
 /**
  * Store a 64-bit double directly to the hardware queue.
  *
  * @param frs Floating-point register containing value to store (0-31)
  */
 static inline void stfdxq(int frs) {
   x_form(PO_X, frs, 0, 0, EO_STFDXQ, 1);
 }
 
 #endif /* QUEUE_H */