all:	hexload.bas

hexload.bas: hexload__.bin
	python bin2bas.py > hexload.bas

hexload__.bin: hexload.asm
	zcc +z80 --no-crt -v -m @hexload.lst -o hexload
	appmake +glue -b hexload --ihex --clean

.PHONY clean:
	rm -f *.bin *.err *.hex *.ihx *.lis *.obj *.map zcc_opt.def hexload.bas
