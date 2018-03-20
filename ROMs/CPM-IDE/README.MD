#CP/M - IDE

<bold>NOTE: TEMPORARILY BROKEN DUE TO ASSEMBLER ISSUE.
[z88dk #655](https://github.com/z88dk/z88dk/issues/655)</bold>

There are several implementations of CP/M available for the RC2014.
Each implementation has its own focus, and the same is true here.

## Concept

This CP/M-IDE is designed to provide support for CP/M while using a normal FATFS formatted IDE drive.
And further, to do so with the minimum of cards and expense.

In addition optimised drivers from the z88dk are implemented for both the ACIA and for the IDE interface.

The ACIA has a 255 byte receive buffer, together with highly optimised buffer management, to minimise potential data loss by buffer overrun. Software control of the 68C50 is provided, but the normal FTDI USB interface is not connected to the correct signal lines to enable hardware flow control.

The IDE interface is optimised for performance and can achieve about 300kB/s throughput. It does this by minimising error management and streamlining read and write routines. The assumption is that modern IDE drives have their own error management and if there are errors from the IDE interface, then there are bigger issues at stake.

The CP/M-IDE system supports up to 4 drives of nominally 16MBytes each. There can be as many CP/M "drives" on the root directory of the FAT32 formatted IDE drive as needed. And CP/M-IDE can be started with any 4 of them. Knock yourself out.


## Hardware

In addition to the RC2014 Classic which contains the CPU and ACIA serial cards, just three cards are necessary.

1. [64kB RAM](https://rc2014.co.uk/modules/64k-ram/)
2. [Pageable ROM](https://rc2014.co.uk/modules/pageable-rom/)
3. [IDE Adapter](https://www.tindie.com/products/edbrindley/ide-adapter-pcb-for-the-rc2014-computer/)

As noted above, the complete system must also include:

4. [CPU board](https://rc2014.co.uk/modules/cpu/z80-cpu-v2-1/)
5. [Clock](https://rc2014.co.uk/modules/clock/)
6. [ACIA Serial](https://rc2014.co.uk/modules/serial-io/)
7. [Backplane](https://rc2014.co.uk/modules/backplane-8/)

Optionally, replacing 4. and 5 with below can save a slot and provides some improvements.

8. [Z80 CPU & Clock](https://www.tindie.com/products/tynemouthsw/z80-cpu-clock-and-reset-module-for-rc2014/)

## Software

The CP/M-IDE is based on the z88dk implementation for the RC2014, together with the DRI CP/M CCP/BDOS, and a shell and a CP/M BIOS constructed specifically for the RC2014 in the above hardware configuration.

In addition to the normal z88dk libraries, a FATFS library provided by ChaN and customised for the RC2014 is installed. This provides a high quality FATFS implementation. Unfortunately, due to the space constraints, it is not possible to include the write functions for FATFS, but this doesn't affect the use of CP/M. It simply means that CP/M "drives" must be prepared on a host using the [cpmtools](http://www.moria.de/~michael/cpmtools/) on your operating system of choice.

### Boot up

When the RC2014 first boots, the z88dk system configures a number of items via a preamble.

The preamble code copies the CCP/BDOS to the correct location, and then checks for the existence of the BIOS. If the BIOS exists, and a valid drive is found, then control is passed directly to the CCP. This is the situation when a CP/M application overwrites the CCP, and it needs to be rewritten before control can be returned to it.

If the CP/M BIOS doesn't exit or it doesn't have a valid drive, then control is returned to the preamble code to continue to load the CP/M BIOS and the ACIA and IDE drivers necessary for operation of the shell and CP/M.

Control is then passed to the shell, that provides a simple command line interface to allow arbitrary FATFS files (pre-prepared as CP/M drives) to be passed to CP/M, and then CP/M booted.

The CLI provides some other basic functions, such as `ls`, `mount` file, `ds`, and `dd` disk functions. And `md` to show the contents of the ROM and RAM.

Once the CP/M BIOS has established that it has a valid CP/M drive, simply because the LBA passed to it is non-zero, then it will page out the ROM, write in a new `Page 0` with relevant CP/M data and interrupt linkages, and then pass control to the CP/M CCP.

An additional CP/M CCP function `EXIT` provides a way to return to the shell to "change disks" by restarting CP/M with different FATFS files input as CP/M disks.


### CP/M System Disk

I have found that the [RunCPM system disk](https://github.com/MockbaTheBorg/RunCPM/tree/master/DISK) contains a good package of CP/M utilities, that can just be loaded onto a disk for a complete ready to run CP/M.

I've also found the [NGS Microshell](http://www.z80.eu/microshell.html) to be very useful, so I add it to my system disk too. No need to add it permanently. In fact, adding it will remove the special `EXIT` function I built into the CCP to return to the shell.

As the CP/M-IDE shell doesn't (currently) have a way to format its own CP/M drives, some example drives are provided as zip files. These zip files can be expanded into the root directory of the IDE drive and used or augmented by the CP/M Tools noted below.


### CP/M TOOLS Usage

CP/M drive files can be read and written using a host computer with any operating system, by using the [`cpmtools`](http://www.moria.de/~michael/cpmtools/) utilities, simply by inserting the PATA IDE drive in a USB drive caddy.

The CP/M TOOLS package v2.20 is available from debian repositories.

Check the disk image, `ls` a CP/M image, copy a file (in this case `bbcbasic.com`).

```bash
> fsed.cpm -f rc2014-16MB a.cpm
> cpmls -f rc2014-16MB a.cpm
> cpmcp -f rc2014-16MB a.cpm ~/Desktop/CPM/bbcbasic.com 0:BBCBASIC.COM
```

The contents of the `/etc/cpmtools/diskdefs` file need to be augmented with disk information specific to the RC2014.

```
diskdef rc2014-32MB
  seclen 512
  tracks 2048
  sectrk 32
  blocksize 4096
  maxdir 512
  skew 0
  boottrk -
  os 2.2
end

diskdef rc2014-16MB
  seclen 512
  tracks 1024
  sectrk 32
  blocksize 4096
  maxdir 512
  skew 0
  boottrk -
  os 2.2
end

diskdef rc2014-8MB
  seclen 512
  tracks 512
  sectrk 32
  blocksize 4096
  maxdir 512
  skew 0
  boottrk -
  os 2.2
end
```

## Shell Command Line Interface

The command line interface is implemented in C, with the underlying functions either in C or in assembly.

### CP/M Functions
- `cpm [file][][][]` - initialise CP/M with up to 4 drive files

### System Functions
- `md [bank][origin]` - memory dump
- `help` - this is it
- `exit` - exit and halt

### File System Functions
- `ls [path]` - directory listing
- `mount [path][option]` - mount a FAT file system

### Disk Functions
- `ds [drive]` - disk status
- `dd [drive][sector]` - disk dump, sector in HEX

