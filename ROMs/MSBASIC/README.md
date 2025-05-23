# RC2014 MS BASIC v4.7, (C) 1978 Microsoft

This ROM works with the __Mini__, __Micro__, and __Classic__ versions of the RC2014, with 32k of RAM and 8kb of ROM. This is the ROM to choose if you want fast I/O from a standard RC2014, together with the capability to upload and run C or assembly programs from within MS Basic. It is the default BASIC for the __RC2014 Mini II__, found in ROM Page 0.

ACIA 68B50 interrupt driven serial I/O to run modified NASCOM Microsoft Basic 4.7. The receive interface has a 255 byte software buffer, together with highly optimised buffer management supporting the 68B50 ACIA receive double buffer. Receive hardware __`/RTS`__ flow control is provided. The transmit interface is also buffered, with direct cut-through when the 63 byte software buffer is empty, to ensure that the CPU is not held in wait state during serial transmission. Use __115200 baud with 8n2__.

Also, this ROM provides both Intel HEX loading functions and an `RST`, `INT0`, and `NMI` RAM Jump Table, starting at `0x8000`. This allows you to upload Assembly or compiled C programs, and then run them as described below.

The goal of this extension to standard MS Basic is to load any arbitrary C or assembly program in Intel HEX format into an arbitrary location in the Z80 address space, and allow you to start and use your program from NASCOM Basic. Your program can be created in assembler, or in C, provided the code is available in Intel HEX format.

Additional BASIC statements `MEEK I,J` and `MOKE I` allow convenient editing of small assembly programs from the BASIC command line.

## Start up debugging

On initial power up, or on `RESET`, there is a `BEL` (`0x07`) character output from the serial port. If you have a terminal supporting `BEL` you will hear it. Otherwise check that `0x07` is being transmitted by looking at the characters received. If you do not hear or see `BEL` then it is likely that your terminal is not properly configured, or that the Z80 Module, ACIA Serial Module, or ROM Module has a fault.

Immediately following a RAM Module sanity check will ensure that the serial port can be fully initialised, and then BASIC loaded. If the RAM Module sanity check fails a character will be continually output, which can be used to infer what is causing the problem. Seeing either `0xFF` or `0x00` would infer that there is no RAM in the required location. Other values infer that there is a problem with the address lines or data lines.

Otherwise, by entering `C` or `W` on your keyboard, you should see this start up message on your terminal the BASIC prompt `Ok`.

```bash
RC2014 - MS Basic Loader
z88dk - feilipu

Cold | Warm start (C|W) ? C

Memory top?
Z80 BASIC Ver 4.7c
Copyright (C) 1978 by Microsoft
31948 Bytes free

Ok

```

## Alternative Hardware Options

Alternative versions of this Microsoft BASIC v.4.7 solution exist for many RC2014 __Classic__ based systems. These are maintained at the [NASCOM_BASIC repository](https://github.com/feilipu/NASCOM_BASIC_4.7). Specific solutions are available for systems containing an [Am9511A APU Module](https://www.tindie.com/products/feilipu/am9511a-apu-module-pcb/) where all calculations are done with the Arithmetic Processing Unit, for systems containing an [8085 CPU Module](https://www.tindie.com/products/feilipu/8085-cpu-module-pcb/) with optimisations for the 8085 CPU, for the 16550 [Single UART Module](https://z80kits.com/shop/16c550-single-uart-serial-module/) and [Dual UART Module](https://z80kits.com/shop/16c2550-dual-uart-serial-module/), and for several combinations of the above hardware options.

# Assembly (or compiled C) Program Usage

Please refer to [Appendix D of the NASCOM 2 Basic Manual](https://github.com/feilipu/NASCOM_BASIC_4.7/blob/master/NASCOM_Basic_Manual.pdf) for information on loading and running Assembly Language programs.

## Using `MEEK` and `MOKE` for assembly entry

The `MEEK I,J` and `MOKE I` statements can be used to hand edit assembly programs, where `I` is the address of interest as a signed integer, and `J` is the number of 16 byte blocks to display. `MOKE` byte entry can be skipped with carriage return, and is exited with `CTRL C`.

Address entry can also be converted from HEX to signed integer using the `&` HEX prefix, i.e. in `MOKE &9000` `0x9000` is converted to `−28672` which is simpler than calculating this signed 16 bit integer by hand, and `MEEK &9000,&10` will tabulate and print 16 blocks of 16 bytes of memory from memory address `0x9000`.

Once the assembly program is entered using `MOKE`, the origin address of the user assembly program needs to be manually entered into the `USRLOC` address `0x8204` using the `DOKE`. Then the program can be run using the BASIC `PRINT USR(0)` or `? USR(0)` commands.

### Usage Example

<a href="https://raw.githubusercontent.com/feilipu/NASCOM_BASIC_4.7/master/HexLoadr-v1.0.png" target="_blank"><img src="https://raw.githubusercontent.com/feilipu/NASCOM_BASIC_4.7/master/HexLoadr-v1.0.png"/></a>

## Using Zen assembler for entering assembly programs

There are several [Intel HEX versions of the Zen assembler](https://github.com/feilipu/NASCOM_BASIC_4.7/tree/master/rc2014_Zen) with different origins prepared to use from within RC2014 MS BASIC. Use the `HLOAD` keyword to load your choice of HEX file based on how much RAM you wish to leave available for BASIC, and launch Zen with `? USR(0)`. Exit back to MS BASIC with `Q`.

Use the Zen `ORG` and `LOAD` keywords to place assembled programs above the Zen End of File Pointer `EOFP`. Use Zen `H` command to determine where `EOFP` is located. The Zen `ORG` keyword should indicate where program will eventually be located, usually at the default of `0x9000`. On return to BASIC, assembled programs can be launched using the `? USR(0)` command either from immediate mode, or from within a BASIC program as a subroutine, after setting the correct `USRLOC` location for the assembly program's `ORG` using `DOKE`, if the program is being run with Zen in situ. Or use the Zen `X` command to save (write) the assembled program to the serial port in Intel HEX format, and then reload it with the MS Basic `HLOAD` and run normally using the `? USR(0)` command.

## Using `HLOAD` for uploading compiled and assembled programs.

1. Select the preferred origin `.ORG` for your arbitrary program, and assemble a HEX file using your preferred assembler, or compile a C program [using z88dk](https://github.com/RC2014Z80/RC2014/wiki/Using-Z88DK). For RC2014 32kB systems suitable origins commence from `0x8400`, and the default origin for z88dk RC2014 is `0x9000`.

2. At the BASIC interpreter type `HLOAD`, then the command will initiate and look for your program's Intel HEX formatted information on the serial interface.

3. Using a serial terminal, upload the HEX file for your arbitrary program that you prepared in Step 1, using the Linux `cat` utility or similar. If desired the python `slowprint.py` program can also be used for this purpose. `python slowprint.py > /dev/ttyUSB0 < myprogram.hex` or `cat > /dev/ttyUSB0 < myprogram.hex`. The RC2014 interface can absorb full rate uploads, and flow control is enabled, so using `slowprint.py` is an unnecessary precaution.

4. Once the final line of the HEX code is read into memory, `HLOAD` will return to NASCOM Basic with `ok`.

5. Start your program by typing `PRINT USR(0)`, or `? USR(0)`, or other variant if you have an input parameter to pass to your program.

The `HLOAD` program can be exited without uploading a valid file by typing `:` followed by `CR CR CR CR CR CR`, or any other character.

The top of BASIC memory can be readjusted by using the `RESET` statement, when required. `RESET` is functionally equivalent to a cold start.

## USR Jump Address & Parameter Access

For the RC2014 with 32k Nascom Basic the `USRLOC` loaded user program address is located at `0x8204`.

Your assembly program can receive a 16 bit parameter passed in from the function by calling `DEINT` at `0x0AE1`. The parameter is stored in register pair `DE`.

When your assembly program is finished it can return a 16 bit parameter stored in `A` (MSB) and `B` (LSB) by jumping to `ABPASS` which is located at `0x1274`.

Note that these address of these functions can also be read from `0x024B` for `DEINT` and `0x024D` for `ABPASS`, as noted in the NASCOM Basic Manual.

``` asm
                                ; from Nascom Basic Symbol Tables
DEINT           .EQU    $0AE1   ; Function DEINT to get USR(x) into DE registers
ABPASS          .EQU    $1274   ; Function ABPASS to put output into AB register for return


                .ORG    9000H   ; your code origin, for example
                CALL    DEINT   ; get the USR(x) argument in DE

                                ; your code here

                JP      ABPASS  ; return the 16 bit value to USR(x). Note JP not CALL
```

## RST locations

For convenience, because we can't easily change the ROM code interrupt routines this ROM provides for the RC2014, the ACIA serial Tx and Rx routines are reachable from your assembly program by calling the `RST` instructions from your program.

* Tx: `RST 08` expects a byte to transmit in the `a` register.
* Rx: `RST 10` returns a received byte in the `a` register, and will block (loop) until it has a byte to return.
* Rx Check: `RST 18` will immediately return the number of bytes in the Rx buffer (0 if buffer empty) in the `a` register.
* Unused: `RST 20`, `RST 28`, `RST 30` are available to the user.
* INT: `RST 38` is used by the ACIA 68B50 Serial Device through the IM1 `INT` location.
* NMI: `NMI` is unused and is available to the user.

All `RST nn` targets can be rewritten in a `JP` table originating at `0x8000` in RAM. This allows the use of debugging tools and reorganising the efficient `RST` instructions as needed. Check the source to see the address of each `RST xx`. By default, if not defined, the unused `RST nn` targets return a `?UF Error` code. For more information on configuring and using the `RST nn` targets [refer to the example in the Wiki](https://github.com/RC2014Z80/RC2014/wiki/Using-Z88DK#basic-subtype).

## Notes

Note that your C or assembly program and the `USRLOC` address setting will remain in place through a RC2014 Warm Reset, provided you prevent BASIC from initialising the RAM locations you have used. Also, you can reload your assembly program to the same RAM location through multiple Warm Resets, without reprogramming the `USRLOC` jump.

Any BASIC programs loaded will also remain in place during a Warm Reset.

BASIC programs can also be uploaded with the Linux `cat` utility, as flow control is enabled. Using interstitial character delay for uploads is unnecessary.

Issuing the `RESET` keyword will clear the RC2014 RAM, and provide an option to return the original memory size. `RESET` is functionally equivalent to a cold start.

The standard `WIDTH` statement has been extended to support setting the comma column screen width using `WIDTH I,J` where `I` is the screen width, and `J` is the comma column screen width.

# Credits

Derived from the work of @fbergama and @foxweb at RC2014.

https://github.com/RC2014Z80/RC2014/blob/master/ROMs/hexload/hexload.asm

# Copyright

NASCOM ROM BASIC Ver 4.7, (C) 1978 Microsoft

Scanned from source published in 80-BUS NEWS from Vol 2, Issue 3 (May-June 1983) to Vol 3, Issue 3 (May-June 1984).

Adapted for the freeware Zilog Macro Assembler 2.10 to produce the original ROM code (checksum A934H). PA

http://www.nascomhomepage.com/

---

The HEX number handling updates to the original BASIC within this file are copyright (C) Grant Searle

You have permission to use this for NON COMMERCIAL USE ONLY.
If you wish to use it elsewhere, please include an acknowledgement to myself.

http://searle.wales/

---

The UART and ACIA drivers and rework to support MS Basic MEEK, MOKE, HLOAD, RESET, and the 8085 and Z80 instruction tuning are copyright (C) 2020-25 Phillip Stevens.

This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.

Further source maintenance at https://github.com/feilipu/NASCOM_BASIC_4.7

@feilipu, March 2025

