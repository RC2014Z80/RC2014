# RC2014 roms

This subdirectory contains all the "native" (ie. asm or c based)
software written for the  [RC2014 homebrew computer](http://rc2014.co.uk).

At the moment is composed by the following components:

- Factory (ROM options provided as standard, with notation)
- The RC2014 initialization code for ROM/RAM system (`init/` directory)
- PiGFX interface library (`pigfx/` directory)
- A 1-stage BASIC hex file loader (replacing standard MSBASIC ROM, in the `HexLoadr/` directory)
- The typical "hello world" test
- [TinyBasicPlus](https://github.com/BleuLlama/TinyBasicPlus) port, originally written by Scott Lawrence and adapted for the Z80/RC2014
- A simple snake game (in the `snake/` directory)
- An optimised (for performance and simplicity) CP/M-IDE using FATFS formatted IDE hard drives and CF cards (in the `CPM-IDE/` directory).


## How to build for PiGFX

- Download and install the [z88dk development kit](http://www.z88dk.org/forum). Please be sure to install the latest "nightly build"
- Export the `ZCCCFG` environment variable (Note that the C is repeated 3 times) to the `<z88dk_root>/lib/config` directory
- Select the memory model by editing the `config.mk`
- Run `make`
- Burn the resulting .hex files on the eeprom (rom memory model) or use the provided hexloader (ram memory model)


## Memory model for PiGFX

The provided software can be compiled to be located either in the lower 8k of the ROM memory area (rom model) or in the upper 32k RAM (starting at address 0x8080 since the first 0x80 bytes are reserved by the system). Edit the file `config.mk` to select the desired mode.

If the "ram" memory mode is selected, the resulting hex files can be uploaded via the provided BASIC hex loader.

## Memory model for Z88DK

The Z88DK `-subtype=basic` assumes that the origin is `0x9000`. All RAM from `0x9000` through to `0xFFFF` is available for user programs.

This is to support the RC2014 Classic and Mini with the MS Basic ROM, and allow space for the `hexload` program to be uploaded with the origin of `0x8900`.

Assembly or C Programs can be initiated with the MS Basic command `USR(x)`, provided the address `0x8049` is prepared with the correct origin of `0x9000` or other location as desired.


## Running on an Emulator

The generated rom files can be executed on an emulator by selecting the rom memory model.
