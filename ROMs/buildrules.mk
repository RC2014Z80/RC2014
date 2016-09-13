
init:
	$(MAKE) -C ../init/

pigfx:
	$(MAKE) -C ../pigfx/

$(APP_NAME)_CODE.bin: $(APP_NAME).c init pigfx
	zcc +embedded -vn -m -clib=new -startup=1 -pragma-define=CRT_ORG_CODE=$(shell cat ../init/INIT_SIZE.txt) -I../pigfx/ -I../init/ -l../pigfx/pigfx.lib -o$(APP_NAME) ../init/rc2014init.asm $(APP_NAME).c


$(APP_NAME).rom: $(APP_NAME)_CODE.bin
	cat $(APP_NAME)_INIT.bin > $(APP_NAME).rom
	cat $(APP_NAME)_CODE.bin >> $(APP_NAME).rom
	cat $(APP_NAME)_DATA.bin >> $(APP_NAME).rom
	cp $(APP_NAME).rom $(APP_NAME).bin

%.hex : %.rom
	appmake +hex -b $< -o $@


.PHONY clean:
	rm -f *.bin *.lst *.ihx *.hex *.obj *.rom zcc_opt.def $(APP_NAME) *.reloc *.sym *.map
