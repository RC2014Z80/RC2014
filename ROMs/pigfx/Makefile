all: pigfx.lib


pigfx.lib: pigfx.asm
	z80asm -l -xpigfx.lib pigfx.asm

.PHONY clean:
	rm -f *.bin *.lst *.obj *.lib *.lis
