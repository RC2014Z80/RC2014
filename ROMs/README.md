# RC2014 roms

This subdirectory contains all the "native" (ie. asm or c based)
software written for the  [RC2014 homebrew computer](http://rc2014.co.uk). 

At the moment is composed by the following components:

- The RC2014 initialization code for ROM/RAM system (```init/``` directory)
- PiGFX interface library (```pigfx/``` directory)
- A 2-stage BASIC+assembly hex file loader (in the ```hexload/``` directory)
- The typical "hello world" test
- [TinyBasicPlus](https://github.com/BleuLlama/TinyBasicPlus) port, originally written by Scott Lawrence and adapted for the Z80/RC2014 
- A simple snake game (in the ```snake/``` directory)

## How to build

- Download and install the [z88dk development kit](http://www.z88dk.org/forum). Please be sure to install the latest "nightly build"
- Export the ```ZCCCFG``` environment variable (Note that the C is repeated 3 times) to the ```<z88dk_root>/lib/config``` directory
- Select the memory model by editing the ```config.mk```
- Run ```make```
- Burn the resulting .hex files on the eeprom (rom memory model) or use the provided hexloader (ram memory model)


## Memory models

The provided software can be compiled to be located either in the lower 8k of the ROM memory area (rom model) or in the 
upper 32k RAM (starting at address 0x8080 since the first 0x80 bytes are reserved by the system).
Edit the file ```config.mk``` to select the desired mode.

If the "ram" memory mode is selected, the resulting hex files can be uploaded via the provided BASIC hex loader.


## HEX file upload (No EEPROM programmer required)

- Connect to the RC2014 with a serial interface
- Boot the machine to start the standard basic mode (if asked, select Cold start and 0 Memory Top)
- Set your UART interface program (like minicom or Putty) so that it waits at least 10 msec between each byte sent
- Copy-paste the file ```hexload/hexload.txt```

After a while, the following message should appear:

```
HEX LOADER by Filippo Bergamasco
```

At that point, copy-paste the desired hex file.


### Linux system only

On a Linux system assuming an USB-to-serial converter attached as ```/dev/ttyUSB0``` the following
commands can be used:


```
$ cd hexload
$ python bin2bas.py | python slowprint.py > /dev/ttyUSB0
$ cat ../helloworld/helloworld.hex | python slowprint.py > /dev/ttyUSB0
```


## Running on an Emulator

The generated rom files can be executed on an emulator by selecting the rom memory model.

