# HexLoadr

The goal of this extension to the standard RC2014 boot ROM sequence is to load an arbitrary program in Intel HEX format into an arbitrary location in the Z80 address space, and allow you to start and use your program from Nascom Basic. Your program can be created in assembler, or in C, provided the code is available in Intel HEX format.

There are are several stages to this process.

1. Reserve space for your assembly program, if required, during the cold start.
2. Reset the RC2014, and select the HexLoadr from the `(C|W|H)` options.
3. Then the HexLoadr program will initiate and look for your program's Intel HEX formatted information on the serial interface.
4. Once the final line of the HEX code is read, the HexLoadr will return to Nascom Basic.
5. The newly loaded program starting address must be loaded into the `USR(x)` jump location.
6. Start the new arbitrary program from Basic by entering the`USR(x)` command.


```bash
SBC - Grant Searle
ACIA - feilipu
z88dk

Cold or Warm start, or HexLoadr (C|W|H) ? C

Memory top? 
Z80 BASIC Ver 4.7b
Copyright (C) 1978 by Microsoft
31907 Bytes free

Ok
```

# Important Addresses

There are a number of important Z80 addresses or origins that need to be managed within your assembly program.

## Arbitrary Program Origin

Your program (the one that you're doing all this for) needs to start in RAM located somewhere.

For the RC2014 with 32kB of RAM, when the RC2014 does a cold start it requests the "Memory Top?" figure. Setting this to 36863 (`0x8FFF`), or lower, will give you space from `0x9000` to `0xFFFF` for your program.

If you're using the RC2014 with 56kB of RAM, then all of the RAM between `0x2000` and `0x7FFF` is available for your assembly programs, without limitation. So, there's no need to change anything during the cold start.

## RST locations

For convenience, because we can't easily change the ROM code interrupt routines this ROM provides for the RC2014, the ACIA serial Tx and Rx routines are reachable from your assembly program by calling the `RST` instructions from your program.

* Tx: `RST 08H` expects a byte to transmit in the `a` register.
* Rx: `RST 10H` returns a received byte in the `a` register, and will block (loop) until it has a byte to return.
* Rx Check: `RST 18H` will immediately return the number of bytes in the Rx buffer (0 if buffer empty) in the `a` register.

## USR Jump Address & Parameter Access

For the RC2014 with 32k Basic the `USR(x)` jump address is located at `0x8224`.
For example, if the origin of your arbitrary program is located at `0x9000` then the Basic command to set the `USR(x)` jump address is `DOKE &h8224, &h9000`.

Your assembly program can receive a 16 bit parameter passed in from the function by calling `DEINT` at `0x0C47`. The parameter is stored in register pair `DE`.

When your assembly program is finished it can return a 16 bit parameter stored in `A` (MSB) and `B` (LSB) by jumping to `ABPASS` which is located at `0x13BD`.

``` asm
                                ; from Nascom Basic Symbol Tables
DEINT           .EQU    $0C47   ; Function DEINT to get USR(x) into DE registers
ABPASS          .EQU    $13BD   ; Function ABPASS to put output into AB register for return


                .ORG    9000H   ; your code origin, for example
                CALL    DEINT   ; get the USR(x) argument in DE
                 
                                ; your code here
                                
                JP      ABPASS  ; return the 16 bit value to USR(x). Note JP not CALL
```
The `RC2014_LABELS.TXT` file is provided to advise of all the relevant RAM and ROM locations.

# Program Usage

1. Select the preferred origin `.ORG` for your arbitrary program, and assemble a HEX file using your preferred assembler.

2. Start your 32k RAM RC2014 with the `Memory top?` set to 36863 (`0x8FFF`) or lower. This leaves space for your program from `0x9000` through to `0xFFFF`. Adjust this if needed to suit your individual needs.

3. Reset the RC2014 and type `H` when offered the `(C|W|H)` option when booting. `HexLoadr:` will wait for Intel HEX formatted data on the ACIA serial interface.

4. Using a serial terminal, upload the HEX file for your arbitrary program that you prepared in Step 1, using the Linux `cat` utility or similar. If desired the python `slowprint.py` program can also be used for this purpose. `python slowprint.py > /dev/ttyUSB0 < myprogram.hex` or `cat > /dev/ttyUSB0 < myprogram.hex`.

5. When HexLoadr has finished, and you are back at the Basic `ok` prompt, use the `DOKE` command relocate the address for the Basic `USR(x)` command to point to `.ORG` of your arbitrary program. For the RC2014 the `USR(x)` jump address is located at `0x8224`. If your arbitrary program is located at `0x9000` then the Basic command is `DOKE &h8224, &h9000`, for example.

6. Start your program by typing `PRINT USR(0)`, or other variant if you have a parameter to pass to your program.

7. Profit.

## Notes

Note that your program and the `USR(x)` jump address setting will remain in place through a RC2014 Cold or Warm RESET, provided you prevent Basic from initialising the RAM locations you have used. Also, you can reload your assembly program to the same RAM location through multiple Warm and HexLoadr RESETs, without reprogramming the `USR(x)` jump.

Any Basic programs loaded will also remain in place during a Warm or HexLoadr RESET.

This makes loading a new version of your assembly program as easy as 1. hit `RESET` button, 2. type `H`, then 3. `cat` the new Intel HEX version of your program.

# Credits

Derived from the work of @fbergama and @foxweb at RC2014.

https://github.com/RC2014Z80/RC2014/blob/master/ROMs/hexload/hexload.asm



