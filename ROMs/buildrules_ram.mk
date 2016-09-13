

pigfx:
	$(MAKE) -C ../pigfx/

$(APP_NAME).bin: $(APP_NAME).c pigfx
	cp ../init_ram/rc2014init.asm crt_preamble.asm
	zcc +embedded -vn -m -clib=new -startup=0 -pragma-define:CRT_INCLUDE_PREAMBLE=1 -pragma-define:CRT_ORG_CODE=$(mem_org_decimal) -pragma-define:CRT_ORG_BSS=-1 -pragma-define:CRT_INITIALIZE_BSS=1 -I../pigfx/ -I../init_ram/ -l../pigfx/pigfx.lib -create-app  -o $(APP_NAME) $(APP_NAME).c
	rm crt_preamble.asm


%.hex : %.bin
	cp $< aux_INIT.bin
	appmake +hex --org $(mem_org) -b aux_INIT.bin -o $@
	rm aux_INIT.bin


.PHONY clean:
	rm -f *.bin *.lst *.ihx *.hex *.obj *.rom zcc_opt.def $(APP_NAME) *.reloc *.sym *.map disasm.txt
