CC = powerpc64le-linux-gnu-gcc
LD = powerpc64le-linux-gnu-ld
OBJCOPY = powerpc64le-linux-gnu-objcopy

CFLAGS = -Os -g -Wall -std=c99 -msoft-float -mno-string -mno-multiple -mno-vsx -mno-altivec -mlittle-endian -fno-stack-protector -mstrict-align -ffreestanding -fdata-sections -ffunction-sections -I../include
ASFLAGS = $(CFLAGS)
LDFLAGS = -T powerpc.lds

all: main.hex

console.o: ../lib/console.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

main.elf: main.o head.o console.o
	$(LD) $(LDFLAGS) -o $@ $^

main.bin: main.elf
	$(OBJCOPY) -O binary $^ $@

main.hex: main.bin
	../scripts/bin2hex.py $^ > main.hex.tmp
	mv -f main.hex.tmp main.hex

clean:
	@rm -f *.o main.elf main.bin main.hex
distclean: clean
	rm -f *~

