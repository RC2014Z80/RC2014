
zcc +z80 --no-crt -v -m --list -Ca-f0xFF @nascom32k.lst -o int32k
z88dk-appmake +glue -b int32k --ihex --pad --filler 0xFF --recsize 24 --clean

# AND

tasm -80 -a7 -fff -c -l d:bas32k.asm d:bas32k.hex

# CONCATENATE THE TWO HEX FILES
