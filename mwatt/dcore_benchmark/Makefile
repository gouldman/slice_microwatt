# Toolchain
CC = powerpc64le-linux-gnu-gcc
LD = powerpc64le-linux-gnu-ld
OBJCOPY = powerpc64le-linux-gnu-objcopy

# Compiler flags
# -Os                   : Optimize for size
# -g                    : Include debug info
# -Wall                 : Enable all common warnings
# -std=c99              : Use C99 standard
# -msoft-float          : No hardware FPU (Currently disabled)
# -mno-string           : Don't use string instructions
# -mno-multiple         : Don't use multiple/multiply-accumulate
# -mno-vsx              : No Vector-Scalar Extension
# -mno-altivec          : No AltiVec/VMX instructions
# -mlittle-endian       : Generate little-endian code
# -fno-stack-protector  : Disable stack protection
# -mstrict-align        : Enforce strict alignment
# -ffreestanding        : No standard library
# -fdata-sections       : Place data in separate sections
# -ffunction-sections   : Place functions in separate sections
# -I../include          : Include headers from ../include
CFLAGS = -Os -g -Wall -std=c99 -mno-string -mno-multiple -mno-vsx -mno-altivec -mlittle-endian -fno-stack-protector \
         -mstrict-align -ffreestanding -fdata-sections -ffunction-sections -I../include

ASFLAGS = $(CFLAGS)
LDFLAGS = -T powerpc.lds

# Default target
all: main.hex

# Build console.o from library
console.o: ../lib/console.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

# Link object files
main.elf: main.o head.o console.o
	$(LD) $(LDFLAGS) -o $@ $^

# Create binary from ELF
main.bin: main.elf
	$(OBJCOPY) -O binary $^ $@

# Convert to hex format
main.hex: main.bin
	../scripts/bin2hex.py $^ > main.hex.tmp
	mv -f main.hex.tmp main.hex

# Cleanup targets
clean:
	@rm -f *.o main.elf main.bin main.hex

distclean: clean
	rm -f *~