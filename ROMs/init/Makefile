all: INIT_SIZE.txt

boot_INIT.bin:
	zcc +embedded -vn -clib=new -startup=1 -o boot rc2014init.asm foo.c

INIT_SIZE.txt: boot_INIT.bin
	wc -c < boot_INIT.bin  > temp.txt
	awk '{print $$1}' < temp.txt > INIT_SIZE.txt
	rm temp.txt

.PHONY clean:
	rm -f boot INIT_SIZE.txt *.bin *.obj *.reloc *.err zcc_opt.def *.sym
