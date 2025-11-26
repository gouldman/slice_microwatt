/**
 * console.h - Console output utility functions for Microwatt
 *
 * This header provides functions for console initialization and output.
 */

#ifndef CONSOLE_H
#define CONSOLE_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

/* Console initialization and configuration */
void console_init(void);
void console_set_irq_en(bool rx_irq, bool tx_irq);

/* Basic I/O functions */
int getchar(void);
int putchar(int c);
int puts(const char *str);

/* Printers */
void print_uint64(uint64_t val);

#ifndef __USE_LIBC
size_t strlen(const char *s);
#endif

#endif /* CONSOLE_H */
