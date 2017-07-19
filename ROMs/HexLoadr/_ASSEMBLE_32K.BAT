tasm -80 -a7 -fff -c -l d:bas32k.asm d:bas32k.hex
tasm -80 -a7 -fff -c -l d:int32k.asm d:int32k.hex

# OR

zcc +z80 --no-crt -v -m --list -Ca--filler=0xFF @nascom32k.lst -o int32k
appmake +glue -b int32k --ihex --pad --filler 0xFF --recsize 24 --clean
