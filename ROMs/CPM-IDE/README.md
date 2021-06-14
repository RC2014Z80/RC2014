# CP/M - IDE

There are several implementations of CP/M available for the RC2014.
Each implementation has its own focus, and the same is true here.

## Concept

This CP/M-IDE is designed to provide support for CP/M while using a normal FATFS formatted PATA drive. And further, to do so with the minimum of cards, complexity, and expense.

In addition to other CP/M implementations, CP/M-IDE includes performance optimised drivers from the z88dk RC2014 support package for the ACIA serial interface, for the IDE disk interface, and also for the SIO/2 serial interface.

In the ACIA build, the receive interface has a 255 byte software buffer, together with highly optimised buffer management supporting the 68C50 ACIA receive double buffer. Hardware (RTS) flow control of the ACIA is provided. The ACIA transmit interface is also buffered, with direct cut-through when the 63 byte software buffer is empty, to ensure that the CPU is not held in wait state during serial transmission.

In the SIO/2 build, both ports enabled. Both ports have a 255 byte software receive buffer supporting the SIO/2 receive quad hardware buffer, and a 31 byte software transmit buffer. The transmit function has direct cut-through when the software buffer is empty. Hardware (RTS) flow control of the SIO/2 is provided. Full IM2 interrupt vector steering is implemented.

The IDE interface is optimised for performance and can achieve about 100kB/s throughput using FatFS libraries in C. It does this by minimising error management and streamlining read and write routines. The assumption is that modern IDE drives have their own error management and if there are errors from the IDE interface, then there are bigger issues at stake.

The IDE interface supports both PATA hard drives (including SSD IDE and DOM storage) and Compact Flash cards in native 16 bit PATA mode with buffered I/O provided by the 82C55 device.

The CP/M-IDE system supports up to 4 active drives of nominally 8 MBytes each. There can be as many CP/M "drives" stored on the FAT32 formatted disk as needed, and CP/M-IDE can be started with any 4 of them. Collections of hundreds of CP/M "drives" can be stored in any number of sub-directories on the FAT32 disk. Knock yourself out.

<div>
<table style="border: 2px solid #cccccc;">
<tbody>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/P1090689.JPG" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/P1090689.JPG"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014 CP/M-IDE with ACIA<center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0543.jpg" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0543.jpg"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014 CP/M-IDE with SIO/2 (front view)<center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0542.jpg" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0542.jpg"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014 CP/M-IDE with SIO/2 (back view)<center></th>
</tr>
</tbody>
</table>
</div>


## Hardware

In addition to the [RC2014 Plus](https://www.tindie.com/products/Semachthemonkey/rc2014-plus-homebrew-z80-computer-kit/) which contains the CPU and SIO/2 serial modules, just the IDE module is necessary.
An additional 32k RAM must be installed in the 64k RAM module.

1. [IDE Hard Drive Module](https://rc2014.co.uk/modules/ide-hard-drive-module/).
2. [64kB RAM Module](https://rc2014.co.uk/modules/64k-ram/).

As noted above, the complete system must also include:

3. [CPU Module](https://rc2014.co.uk/modules/cpu/z80-cpu-v2-1/).
4. [Clock Module](https://rc2014.co.uk/modules/clock/).
5. [Pageable ROM Module](https://rc2014.co.uk/modules/pageable-rom/).
6. [SIO/2 Dual Serial Module](https://rc2014.co.uk/modules/dual-serial-module-sio2/).
7. [Backplane 8](https://rc2014.co.uk/modules/backplane-8/) or Backplane Pro.

Optionally, replacing 3. and 4. with below can save a slot and provides some improvements.

- [Z80 CPU & Clock Module](https://www.tindie.com/products/tynemouthsw/z80-cpu-clock-and-reset-module-for-rc2014/).

Optionally, replacing 2. and 5. with below avoids the need for a flying `PAGE` wire joining RAM and ROM Modules when using the Backplane 8.

- [Memory Module](https://www.tindie.com/products/feilipu/memory-module-pcb/).

Additionally, the ACIA serial card could be substituted for the SIO/2 dual serial interface.

- [ACIA Serial Module](https://rc2014.co.uk/modules/serial-io/).

Also works with Grant Searle's [9 Chip CP/M](http://searle.hostei.com/grant/cpm/index.html) if a 32kB ROM is used, and with Steve Cousins' [SC108 (Z80, RAM, ROM)](https://smallcomputercentral.com/projects/z80-processor-module-for-rc2014/), because Richard Deane cared enough to ask. Thanks Richard.

As noted Compact Flash cards are also supported in native 16 bit PATA mode, as demonstrated below.

<div>
<table style="border: 2px solid #cccccc;">
<tbody>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://lh3.googleusercontent.com/-fCgroN5mYU8/WrREnuPPowI/AAAAAAACR8U/IQoillkYPpYYg3ROctaQHdLqDRtZ5hwrwCLcBGAs/s1600/IMG_20180322_235743.jpg" target="_blank"><img src="https://lh3.googleusercontent.com/-fCgroN5mYU8/WrREnuPPowI/AAAAAAACR8U/IQoillkYPpYYg3ROctaQHdLqDRtZ5hwrwCLcBGAs/s320/IMG_20180322_235743.jpg"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014 running CP/M-IDE by DJRM<center></th>
</tr>
</tbody>
</table>
</div>

## Configuration

The cards are configured in their normal settings for CP/M. A jumper for the `PAGE` signal is shown on pin 39, although this can be done in any alternative way.

Rather than spend time on long descriptions, one picture is worth 2kByte.

<div>
<table style="border: 2px solid #cccccc;">
<tbody>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/P1090691.JPG" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/P1090691.JPG"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014 CP/M Modules (excl. ACIA)<center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0536.jpg" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0536.jpg"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014 64kByte RAM Module<center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0535.jpg" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0535.jpg"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014 Pageable ROM Module<center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0530.jpg" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0530.jpg"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014 82C55 IDE Module<center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0532.jpg" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0532.jpg"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014 82C55 IDE Module disk options<center></th>
</tr>
</tbody>
</table>
</div>

## Software

The CP/M-IDE is based on the z88dk with a simple command shell for the RC2014, together with the DRI CP/M CCP/BDOS, and a CP/M BIOS constructed specifically for the RC2014 in the above hardware configuration. The DRI CCP and BDOS have been optimised for performance using extended Z80 CPU instructions. Z80 `LDI` instructions (for example) have been used to improve buffer copy performance.

### Installation

Using the correct HEX file for the hardware configuration (RC2014 ACIA Module, RC2014 SIO/2 Module) from this directory, burn it into a 32kB or 64kB EEPROM, or PROM.

Use either a USB caddy for your PATA IDE drive, or a CF adapter for your Compact Flash card to mount your drive on your host computer. Your host computer should be able to read and write FAT32 formatted drives. Format the drive for FAT32 (or FAT16 if it is quite small). Drag some of the CP/M drive files into the root directory of your drive. At least the `SYS.CPM` file is required. Check that each of the drive files are using 8388608 Bytes on your IDE or CF drive. You may put the CP/M drive files into directories (to organise them based on your workflow), or leave them all in the root directory.

Connect the hardware as shown, and then use the commands given in the Shell Command Line, below.

### Building

The z88dk command line to build the CP/M-IDE is below. Either the ACIA or SIO subtype should be selected, in the relevant directory.

```bash
zcc +rc2014 -subtype=acia -SO3 -m -llib/rc2014/ff_ro --math32 --max-allocs-per-node400000 @cpm22.lst -o ../rc2014-acia-cpm22 -create-app

zcc +rc2014 -subtype=sio -SO3 -m -llib/rc2014/ff_ro --math32 --max-allocs-per-node400000 @cpm22.lst -o ../rc2014-sio-cpm22 -create-app
```

Prior to running the above build commands, in addition to the normal z88dk provided libraries, a [FATFS library](https://github.com/feilipu/z88dk-libraries/tree/master/ff) provided by [ChaN](http://elm-chan.org/fsw/ff/00index_e.html) and customised for read-only for the RC2014 must be installed, by manually copying `ff_ro.lib` into the rc2014 library directory. This provides a high quality FATFS implementation. Unfortunately, due to ROM space constraints, it is not possible to include the FATFS write functions within the CP/M-IDE ROM. This does not affect the use of disk read or write by CP/M or z88dk applications compiled using the library. It simply means that CP/M-IDE "drives" must be prepared on a host using the [cpmtools](http://www.moria.de/~michael/cpmtools/) on your operating system of choice. Also read-write version (default) of the FATFS library should be installed so that applications compiled using z88dk can read and write to the FATFS file system.

The size of the serial transmit and receive buffers are set within the z88dk RC2014 target configuration files for the [ACIA](https://github.com/z88dk/z88dk/blob/master/libsrc/_DEVELOPMENT/target/rc2014/config/config_acia.m4) and [SIO/2](https://github.com/z88dk/z88dk/blob/master/libsrc/_DEVELOPMENT/target/rc2014/config/config_sio.m4) respectively.

### Boot up

When the RC2014 first boots, the z88dk system configures a number of items via a preamble.

The preamble code copies the CCP/BDOS to the correct location, and then checks for the existence of the BIOS. If the BIOS exists, and a valid drive is found, then control is passed directly to the CCP. This is the situation when a CP/M application overwrites the CCP, and it needs to be rewritten before control can be returned to it.

If the CP/M BIOS doesn't exist or it doesn't have a valid drive, then control is returned to the preamble code to continue to load the CP/M BIOS, the ACIA or SIO drivers, and the IDE drivers necessary for operation of the shell and CP/M.

Control is then passed to the command shell, that provides a simple command line interface to allow arbitrary FATFS files (pre-prepared as CP/M drives) to be passed to CP/M, and then CP/M booted.

Where the SIO/2 dual serial board is being used, the shell will wait for a `:` to establish which serial interface is being used. The SIOB (`tty`) port does not have remote echo enabled, as is customary with teletype interfaces.

CP/M can be started by command `cpm [file][][][]` At least one valid file name must be provided. Up to 4 CP/M drive files are supported.

The CLI provides some other basic functions, such as `ls`, `cd`, `pwd`, `mount` file, `ds`, and `dd` disk functions. And `md` to show the contents of the ROM and RAM.

Once the CP/M BIOS has established that it has a valid CP/M drive available, simply because the LBA passed to it is non-zero, then it will page out the ROM, write in a new `Page 0` with relevant CP/M data and interrupt linkages, and then pass control to the CP/M CCP.

### CP/M System Disk

The [RunCPM system disk](https://github.com/MockbaTheBorg/RunCPM/tree/master/DISK) contains a good package of CP/M utilities, that has been loaded onto an example [system disk](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/SYS.CPM.zip) for a complete ready to run CP/M.

Also, the [NGS Microshell](http://www.z80.eu/microshell.html) can be very useful, so it has been added to the example [system disk](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/SYS.CPM.zip) too. There is no need to replace the DRI CCP with Microshell. In fact, adding it permanently would remove the special `EXIT` function built into the DRI CCP to return to the shell.

As the CP/M-IDE shell doesn't have a way to format its own CP/M drives (due to ROM space constraints), some template and example drives are provided as zip files. These zip files can be expanded into the directory structure of the IDE drive and used or augmented by the CP/M Tools noted below.

Because the CCP/BDOS and BIOS are stored in ROM, there is no IDE "system disk". Cold and warm boot are from ROM. This means that the 4 drives supported by CP/M-IDE are completely orthogonal. It doesn't matter which drive file is in which drive letter. Except that the drive file in the `A:` drive will always be selected as the default drive, when you try to select a non-existent drive letter.

### CP/M Application Disks

The [CP/M Drives directory](https://github.com/RC2014Z80/RC2014/tree/master/ROMs/CPM-IDE/CPM%20Drives) contains a number of CP/M drives containing commonly used applications, such as the [Zork Series](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/ZORK.CPM.zip), [BBC Basic](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/BBCBASIC.CPM.zip), [Hi-Tech C v3.09](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/HITECHC.CPM.zip), and [MS BASIC Compiler v5.3](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/MSBASCOM.CPM.zip). MS Basic (Interpreter) 5.29 is available in the [system drive](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/SYS.CPM.zip).

An empty [CP/M 8 MB drive](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/TEMPLATE.CPM.zip) file is provided as a template to create additional user drives. Unfortunately, the CP/M tools package doesn't properly extend CP/M drive files out to the full size of 8388608 bytes when it creates them on FATFS. Using (unzipping) this template, and renaming it as desired, on a FATFS drive is all that is needed to create a new CP/M drive on any PATA hard drive or Compact Flash card. Each new file created provides a new 8 MB CP/M drive which can store up to 2048 files.

FAT32 supports over 65,000 files in each directory. Using a 128GB drive it is possible to store more than that many CP/M-IDE drives on one IDE drive, but this upper limit hasn't been tested.

### CP/M TOOLS Usage

CP/M drive files can be read and written using a host computer with any operating system, by using the [`cpmtools`](http://www.moria.de/~michael/cpmtools/) utilities, simply by inserting the PATA IDE drive into a USB drive caddy.

The CP/M TOOLS package v2.20 is available from debian repositories.

Check the disk image, `ls` a CP/M image, copy a file (in this case `bbcbasic.com`).

```bash
> fsed.cpm -f rc2014-8MB a.cpm
> cpmls -f rc2014-8MB a.cpm
> cpmcp -f rc2014-8MB a.cpm ~/Desktop/CPM/bbcbasic.com 0:BBCBASIC.COM
```
The contents of the `/etc/cpmtools/diskdefs` file need to be augmented with disk information specific to the RC2014 before use.
This default is for 8MByte drives, with up to 2048 files each.

```
diskdef rc2014-8MB
  seclen 512
  tracks 64
  sectrk 256
  blocksize 4096
  maxdir 2048
  skew 0
  boottrk -
  os 2.2
end

```

## Shell Command Interface

The shell command line interface is implemented in C, with the underlying functions either in C or in assembly.

Again, here is a view of what success looks like.

<div>
<table style="border: 2px solid #cccccc;">
<tbody>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/cpm-idev3.png" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/cpm-idev3.png"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014 CP/M-IDE Shell CLI<center></th>
</tr>
</tbody>
</table>
</div>

### CP/M Functions
- `cpm [file][][][]` - initialise CP/M with up to 4 drive files

### System Functions
- `md [origin]` - memory dump
- `help` - this is it
- `exit` - exit and restart shell

### File System Functions
- `ls [path]` - directory listing
- `cd [path]` - change the current working directory
- `pwd` - show the current working directory
- `mount [option]` - mount a FAT file system, option 0 = delayed, 1 = immediate

### Disk Functions
- `ds` - disk status
- `dd [sector]` - disk dump, sector in decimal

## CP/M CCP Extension

An additional CP/M CCP function `EXIT` provides a way to return to the shell to "change disks" by restarting CP/M with different FATFS files as input for the CP/M drives. `EXIT` initialises a clean reboot of the RC2014, and returns to the command shell.
