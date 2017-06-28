all:	hexload.txt

hexload.txt: hexload__.bin
	python bin2bas.py > hexload.txt

hexload__.bin: hexload.asm
	zcc +z80 --no-crt -v -m @hexload.lst -o hexload
	appmake +glue -b hexload --ihex --clean

.PHONY clean:
	rm -f *.bin *.err *.hex *.ihx *.lis *.obj hexload.txt
