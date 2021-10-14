
zcc +z80 --no-crt -v -m --list -Ca-f0xFF @nascom32k.lst -o rc2014_32k
z88dk-appmake +glue -b rc2014_32k --ihex --pad --filler 0xFF --recsize 24 --clean
