# RC2014 roms

This subdirectory contains all the "native" (ie. asm or c based)
software written for the  [RC2014 homebrew computer](http://rc2014.co.uk). 

At the moment is composed by the following components:

- The RC2014 initialization code for ROM/RAM system (```init/``` directory)
- PiGFX interface library (```pigfx/``` directory)
- [TinyBasicPlus](https://github.com/BleuLlama/TinyBasicPlus) port, originally written by Scott Lawrence and adapted for the Z80/RC2014 
- A simple snake game (in the ```snake/``` directory)

## How to build

- Download and install the [z88dk development kit](http://www.z88dk.org/forum)
- Export the ```ZCCCFG``` environment variable (Note that the C is repeated 3 times) to the ```<z88dk_root>/lib/config``` directory
- Run ```make```


## How to run

The generated binary rom files can be directly burned to the RC2014 eeprom or
executed with an RC2014 emulator.

