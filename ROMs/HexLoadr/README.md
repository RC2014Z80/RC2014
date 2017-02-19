# HexLoadr

The goal of this extension to the standard RC2014 boot sequence is to load an arbitrary program in Intel HEX format into an arbitrary location in the Z80 address space, and allow you to start the program from Nascom Basic.

There are are several stages to this process.

1. Reserve space for your assembly program if required.
2. Reset the RC2014, and select the HexLoadr from the `(C|W|H)` options.
3. Then the HexLoadr program will initiate and look for your program's Intel HEX formatted information on the serial interface.
4. Once the final line of the HEX code is read, the HexLoadr will return to Nascom Basic.
5. The newly loaded program starting address must be loaded into the `USR(x)` jump location.
6. Start the new arbitrary program by entering `USR(x)`.
    
# Important Addresses

There are a number of important Z80 addresses or origins that need to be managed within your assembly program.

## Arbitrary Program Origin

Your program (the one that you're doing all this for) needs to start in RAM located somewhere.

For the RC2014 with 32kB of RAM, when the RC2014 does a cold start it requests the "Memory Top?" figure. Setting this to 57343 (`0xDFFF`), or lower, will give you space from `0xE000` to `0xFFFF` for your program and for the hexloader program.

If you're using the RC2014 with 56kB of RAM, then all of the RAM between `0x3000` and `0x7FFF` is available for your assembly programs, without limitation.

## RST locations

For convenience, because we can't easily change ROM code interrupt routines already present in the RC2014, the serial Tx and Rx routines are reachable by calling `RST` instructions from your assembly program.

* Tx: `RST 08H` expects a byte in the `a` register.
* Rx: `RST 10H` returns a byte in the `a` register, and will loop until it has a byte to return.
* Rx Check: `RST 18H` will return the number of bytes in the Rx buffer (0 if buffer empty) in the `a` register.

# Program Usage

1. Select the preferred origin `.ORG` for your arbitrary program, and assemble a HEX file using your preferred assembler.

2. Start your RC2014 with the `Memory top?` set to 57343 (`0xDFFF`) or lower. This leaves space for your program from `0xE000` through to `0xFFFF`. Adjust this if needed to suit your individual needs.

3. Reset the RC2014 and type `H` when offered the `(C|W|H)` option when booting. `HexLoadr:` will wait for Intel HEX formatted data on the ACIA serial interface.

4. Using a serial terminal, upload the HEX file for your arbitrary program that you prepared in Step 1. If desired the python `slowprint.py` program, or the Linux `cat` utility, can also be used for this purpose. `python slowprint.py < myprogram.hex > /dev/ttyUSB0` or `cat myprogram.hex > /dev/ttyUSB0`.

5. When HexLoadr has finished, and you are back at the Basic `ok` prompt, use the `DOKE` command relocate the address for the Basic `USR(x)` command to point to `.ORG` of your arbitrary program. For the RC2014 the `USR(x)` jump address is located at `&h8124`. If your arbitrary program is located at `&hE000` then the Basic command is `DOKE &h8124, &hE000`, for example.

6. Start your arbitrary program using `PRINT USR(x)`, or other variant if you have parameters to pass to your program.

7. Profit.

## Notes

Note that your arbitrary program and the `USR(x)` jump will remain in place through a RC2014 reset, provided you prevent Basic from initialising the RAM you have loaded. Also, you can reload your program to the same location through multiple Warm and HexLoadr restarts, without reprogramming the `USR(x)` jump.

Any Basic programs loaded will also remain in place during a Warm RESET or HexLoadr RESET.

This makes loading a new version of your program as easy as 1. `RESET`, 2. `H`, 3. then `cat`.

# Credits

Derived from the work of @fbergama and @foxweb at RC2014.

https://github.com/RC2014Z80/RC2014/blob/master/ROMs/hexload/hexload.asm



