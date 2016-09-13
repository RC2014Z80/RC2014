APP_NAME := helloworld
include ../config.mk


all: showinfo $(APP_NAME).hex
	z80dasm -g $(mem_org) -a $(APP_NAME).bin > disasm.txt

showinfo:
	@echo ---------------------------------------------------------
	@echo Compiling $(APP_NAME) with $(memory_model) memory model
	@echo "   Memory ORG: $(mem_org)"
	@echo ---------------------------------------------------------


ifeq ($(memory_model),ram)
    include ../buildrules_ram.mk
else ifeq ($(memory_model),rom)
    include ../buildrules.mk
else
endif
