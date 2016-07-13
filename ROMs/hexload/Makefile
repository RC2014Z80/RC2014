all:	hexload.txt

hexload.txt: hexload.bin
	python bin2bas.py > hexload.txt

hexload.bin: hexload.asm
	z80asm -l -b hexload.asm
	mv hexload_INIT.bin hexload.bin

.PHONY clean:
	rm -f *.bin *.err *.hex *.lis *.obj hexload.txt
