# CP/M - IDE

There are several implementations of CP/M available for the RC2014. Each implementation has its own focus, and the same is true here. For larger [RC2014 Zed](https://z80kits.com/shop/rc2014-zed/) based systems with 512kB RAM [RomWBW](https://github.com/wwarthen/RomWBW/tree/master) is the right solution. For your smaller [RC2014 Pro](https://z80kits.com/shop/rc2014-pro/) based systems with 64kB RAM read on.

For further technical reading, a longer [description of CP/M-IDE is here](https://feilipu.me/2022/03/23/cpm-ide-for-rc2014/). This description is slightly outdated, but it covers the basics.

## Concept

This CP/M-IDE is designed to provide support for CP/M 2.2 with either Z80 or 8085 CPUs while using a normal FATFS formatted hard drive. And further, to do so with the minimum of (no) additional modules, complexity, and expense.

In contrast to other CP/M implementations, CP/M-IDE includes performance optimised drivers from the [z88dk](https://github.com/z88dk/z88dk). The z88dk RC2014 support includes serial interface drivers for the ACIA Serial Module, for the SIO/2 Serial Module, and for the Single and Dual UART Serial Modules. Two disk interface types are supported, being the IDE Hard Drive Module for PATA attached drives of all types and also the Compact Flash Module for Compact Flash Cards and Adapters.

While multiple configurations are possible, and can be built up as desired, the most common options are provided as prebuilt HEX files which can be simply burned to a 32kB ROM.

- The RC2014 Z80 CF SIO build supports the __RC2014 Pro__ with the standard SIO/2 Serial Module and the Compact Flash Module 2.0 in their usual configurations.

- The RC2014 Z80 CF UART build supports the RC2014 Pro with either the Single or Dual __UART Serial Module__ and the Compact Flash Module 2.0.

- The RC2014 Z80 PATA SIO build supports the RC2014 Pro Module equipped with the __IDE Hard Drive Module__.

- The RC2014 Z80 CF ACIA build supports the RC2014 Pro with the standard ACIA Serial Module and the Compact Flash Module 2.0.

For the 8085 CPU Module.

- The RC2014 8085 CF ACIA build requires the 8085 CPU Module, the ACIA Serial Module and uses the Compact Flash v2.0 (CF) Module.

- The RC2014 8085 CF UART build requires the 8085 CPU Module, the UART Serial Module and uses the Compact Flash v2.0 (CF) Module.

- The RC2014 8085 PATA UART build requires the 8085 CPU Module, the UART Serial Module and uses the IDE Hard Drive Module.

In the SIO Serial Module builds, both ports are enabled. Both ports have a 127 byte software receive buffer supporting the SIO/2 receive quad hardware buffer, and a 31 byte software transmit buffer. The transmit function has direct cut-through when the software buffer is empty. Hardware __`/RTS`__ flow control of the SIO/2 is provided. Full IM2 interrupt vector steering is implemented.

In the Single and Dual UART Serial Module builds both ports are enabled if present. Both ports have a 127 byte software receive buffer. The UART hardware receive and transmit FIFOs are 16 bytes. Hardware __`/RTS`__ and automatic flow control are enabled.

In the ACIA Serial Module builds, the receive interface has a 255 byte software buffer, together with optimised buffer management supporting the 68B50 ACIA receive double buffer. Hardware __`/RTS`__ flow control of the ACIA is provided. The ACIA transmit interface is also buffered, with direct cut-through when the 31 byte software buffer is empty, to ensure that the CPU is not held in wait state during transmission.

__NOTE:__ All serial interfaces (on the ACIA Serial Module, on the SIO Serial Module, on the UART Serial Module, and on the 8085 CPU Module SOD) are configured for __115200 baud 8n2__.

__NOTE:__ To enable flow control with any Serial Module it is critical to use a USB Serial adapter that supports __`/RTS`__ on Pin 6. Typical FTDI USB Adapters pinout __`/DTR`__ to Pin 6. The [recommended USB Serial adapter](https://www.tindie.com/products/8086net/uusbusb-c-cdc-serial-adaptor-5v/) is available from 8086 Consultancy.

The IDE Hard Drive Module interface driver is optimised for performance and can achieve about 110kB/s. It does this by minimising error management and streamlining read and write routines. The assumption is that modern PATA attached IDE drives have their own error management and if there are errors from the IDE interface, then there are other issues at stake. The CF Module can achieve up to 200kB/s at file-system level, and it seems to provide best performance using SD Cards in SD to CF Card Adapters. CP/M file and directory transfer is described in [Modifications to the CCP and BDOS](readme_ccp_bdos.md).

The IDE Hard Drive Module supports both PATA hard drives (including 3 1/2" magnetic platter, SSD, and DOM storage) and Compact Flash cards in their native 16-bit PATA mode, with buffered I/O provided by the 82C55 device. The IDE Hard Drive Module is the ideal way to attach "spinning rust" to your RC2014. Attaching one physical Master drive is supported.

The CP/M-IDE system supports up to 4 mounted CP/M "drives" (files) of nominally 8 MBytes each. There can be as many CP/M drives stored on the FAT32 formatted disk as desired, and CP/M-IDE can be started with any 4 of them. Collections of hundreds (or even thousands) of CP/M drives can be stored in any number of sub-directories on the FAT32 host disk, to be mounted at will.

A CP/M program runs from `$0100` up to the CCP. The space for each ROM is in [Modifications to the CCP and BDOS](readme_ccp_bdos.md).

<div>
<table style="border: 2px solid #cccccc;">
<tbody>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/P1090689.JPG" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/P1090689.JPG"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><center>RC2014 CP/M-IDE with IDE Module and ACIA Module</center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0543.jpg" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0543.jpg"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><center>RC2014 CP/M-IDE with DOM in an IDE Module and SIO Module (front view)</center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0542.jpg" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0542.jpg"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><center>RC2014 CP/M-IDE with DOM in an IDE Module and SIO Module (back view)</center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_1688.JPG" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_1688.JPG"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><center>RC2014-8085 CP/M-IDE with DOM in an IDE Module and ACIA Module</center></th>
</tr>
</tbody>
</table>
</div>


## Hardware

For the [RC2014 Pro](https://z80kits.com/shop/rc2014-pro/) no additional hardware is required. It is recommended to use a modern Compact Flash card of 1GB (or greater, up to 128GByte, or use a uSD-CF Adapter) to allow unrestricted storage of multiple CP/M drives.

For the RC2014 IDE Module builds, in addition to the [RC2014 Pro](https://z80kits.com/shop/rc2014-pro/) which contains the CPU and SIO Serial modules, just the IDE Hard Drive Module is necessary.

1. [IDE Hard Drive Module](https://rc2014.co.uk/modules/ide-hard-drive-module/).

Using the IDE Hard Drive Module the widest variety of PATA attached hard disks are supported. This is the way to connect 80's and 90's spinning disks for maximum "retro appeal".

__NOTE:__ If you are using the IDE Hard Drive Module 40-pin PATA connector, be aware that this connector does not pass power to the attached disk, DOM, or CF adapter. A 5" disk or 3 1/2" disk must be powered by its own 4-pin MOLEX connector. A 40-pin DOM or CF adapter must be powered by its own accessory power connector. Connecting +5V power to the barrel jack on the IDE Hard Drive Module is not sufficient to power 40-pin devices.

As noted above, the complete RC2014 Pro system must include:

2. [CPU Module](https://rc2014.co.uk/modules/cpu/z80-cpu-v2-1/).
3. [Clock Module](https://rc2014.co.uk/modules/clock/).
4. [64k RAM Module](https://rc2014.co.uk/modules/64k-ram/).
5. [Pageable ROM Module](https://rc2014.co.uk/modules/pageable-rom/).
6. [SIO Dual Serial Module](https://rc2014.co.uk/modules/dual-serial-module-sio2/).
7. [Backplane 8](https://rc2014.co.uk/modules/backplane-8/) or [Backplane Pro](https://rc2014.co.uk/backplanes/backplane-pro/).

If your preference is to use a CF Card, or SD Card in a uSD-CF Adapter, then Dylan Hall's CF Card PPIDE Module can be exchanged for item 1. This Module provides seamless and reliable (CF Specification compliant) CF Card (or also SD Card Adapter) support, but doesn't provide a standard 40 pin or 44 pin IDE connector.

- [CF Card PPIDE Module](https://oshwlab.com/dylan_3481/cf-ppide-for-rc2014_copy).

It is possible to use the standard RC2014 CF Module v2.0 with either the RC2014 Pro, or with the 8085 CPU Module CF builds. As a supported RC2014 Module, the CF Module v2.0 by Tadeusz Pycio provides a very robust (CF Specification compliant) solution that will work with large Compact Flash cards (e.g. 1GB and greater), and with SD to CF Card Adapters.

- [CF Module](https://rc2014.co.uk/modules/compact-flash-module/).
- [CF Module v2.0](https://z80kits.com/shop/compact-flash-module/).

Optionally, replacing items 4. and 5. with the Memory Module (also compatible with Steve Cousins' SC108) avoids the need for a flying `PAGE` wire joining RAM and ROM Modules when using the Backplane 8.

- [Memory Module](https://www.tindie.com/products/feilipu/memory-module-pcb/).

To operate the RC2014 with an 8085 CPU the following CPU Module must be exchanged for items 2. and 3, and either an ACIA Serial Module or a UART Serial Module installed.

__NOTE:__ For use with the 8085 CPU Module, either the ACIA Serial Module or UART Serial Modules are supported.

- [8085 CPU Module](https://www.tindie.com/products/feilipu/8085-cpu-module-pcb/).

To operate the RC2014 with a Single or Dual UART Serial Module, install that module in exchange for item 6. Installation of multiple serial modules is not supported.

- [Dual UART Module](https://rc2014.co.uk/modules/dual-serial-module-16c2550/).

Additionally, the ACIA Serial Module from the [RC2014 Classic II](https://rc2014.co.uk/modules/serial-io/) could be substituted for item 6. the SIO Serial Module.<br>

- [ACIA Serial Module](https://z80kits.com/shop/tynemouth-68b50-clocked-serial-port/).

Also Grant Searle's [CP/M on breadboard](http://searle.x10host.com/cpm/index.html) hardware is supported if a 32kB ROM is used, and Steve Cousins' [SC108 Module (Z80, 128k RAM, 32k ROM)](https://smallcomputercentral.com/rcbus/sc100-series/sc108-z80-processor-rc2014/) Module could be exchanged for items 2., 3., 4., and 5., because Richard Deane cared enough to ask. Thanks Richard.

As noted, when used with the IDE Hard Drive Module, both SD Cards and Compact Flash cards are also supported in their native 16-bit PATA mode, as shown below. Otherwise, when using the CF Module from the RC2014 Pro, SD Cards and Compact Flash cards are supported in the Compact Flash 8-bit compatibility mode.

<div>
<table style="border: 2px solid #cccccc;">
<tbody>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://lh3.googleusercontent.com/-fCgroN5mYU8/WrREnuPPowI/AAAAAAACR8U/IQoillkYPpYYg3ROctaQHdLqDRtZ5hwrwCLcBGAs/s1600/IMG_20180322_235743.jpg" target="_blank"><img src="https://lh3.googleusercontent.com/-fCgroN5mYU8/WrREnuPPowI/AAAAAAACR8U/IQoillkYPpYYg3ROctaQHdLqDRtZ5hwrwCLcBGAs/s320/IMG_20180322_235743.jpg"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><center>RC2014 running CP/M-IDE by DJRM</center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_2255.JPG" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_2255.JPG"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><center>RC2014-8085 running CP/M-IDE with SD to CF Storage Adapter</center></th>
</tr>
</tbody>
</table>
</div>

### Configuration

The modules are configured in their normal settings for CP/M. A jumper for the `PAGE` signal is shown connected via pin 39, although this can be done in any alternative way. To configure the RC2014 Pro see the jumper settings on the RAM Module and ROM Module, below pictures. Specifically the Pageable ROM Module needs to be configured for 32kByte Pages.

Rather than spend time on long written descriptions, one picture is worth 2kByte.

<div>
<table style="border: 2px solid #cccccc;">
<tbody>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/P1090691.JPG" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/P1090691.JPG"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><center>RC2014 CP/M-IDE Modules (excl. ACIA)</center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_1689.JPG" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_1689.JPG"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><center>RC2014 CP/M-IDE 8085 Modules</center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0536.jpg" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0536.jpg"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><center>RC2014 64kByte RAM Module (note jumper positions)</center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0535.jpg" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0535.jpg"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><center>RC2014 Pageable ROM Module (note jumper positions)</center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0530.jpg" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0530.jpg"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><center>RC2014 IDE Hard Drive Module with DOM</center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0532.jpg" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0532.jpg"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><center>RC2014 IDE Hard Drive Module storage options</center></th>
</tr>
</tbody>
</table>
</div>

## CP/M Software

The CP/M-IDE is built using the z88dk compilers and libraries, including a simple boot monitor or shell for the RC2014, together with the standard DRI CP/M CCP/BDOS, and a CP/M BIOS constructed specifically for the RC2014 in the above hardware configurations.

#### CCP & BDOS Extension

The CCP command `EXIT` returns to the shell. You can then start CP/M with different drive files.

The BDOS function 10 treats DEL as backspace. Digital Research Application Note 02 (APN 02) specifies that behaviour.

A command with no drive letter is tried again on `A:` when the `.COM` file is not on the current drive. An explicit drive letter searches only on that drive.

Further information on changes to the CCP and BDOS is in [Modifications to the CCP and BDOS](readme_ccp_bdos.md).

#### BIOS Notes

The FAT volume rules are in the BIOS section of [Modifications to the CCP and BDOS](readme_ccp_bdos.md).

### Installation

Using the correct HEX file for your hardware configuration from this directory, burn it into a 32kB or 64kB EEPROM, or PROM.

To initially configure your hard drive, use either a USB caddy for your PATA IDE drive, or a CF adapter for your Compact Flash card to mount your drive on your host computer. Your host computer should be able to read and write FAT32 formatted drives. Format the drive for FAT32 (or FAT16 if it is quite small). Then __unzip__ and __"Drag and drop"__ or __copy__ some of the example [CP/M drive files](https://github.com/RC2014Z80/RC2014/tree/master/ROMs/CPM-IDE/CPM%20Drives) into the root directory of your drive. At least the `sys.cpm` example file is required (until you customise your own) as it contains many system utilities. Check that each of the drive files is using 8388608 Bytes on your IDE or CF drive. You may put the CP/M drive files into directories (to organise them based on your workflow), or leave them all in the root directory.

Connect the RC2014 hardware as shown above, and then use the commands in [Usage of the Shell Command Interface](#usage-of-the-shell-command-interface).

### Boot-up Process

When the RC2014 first boots, the z88dk `crt0` preamble configures the machine.

The preamble copies the CCP and BDOS to the correct location, and then checks for the BIOS. If the BIOS exists, and a valid drive is found, control passes to the CCP. This is the usual path when a CP/M application overwrites the CCP. The CCP is written again before control returns to it. Otherwise the preamble loads the CP/M BIOS, the serial drivers, and the disk drivers, and then starts the shell.

__NOTE:__ Where the SIO Module or the UART Module is in use, the shell waits for a `:` to select the serial port. It stays on that port until CP/M loads.

Command use is in [Usage of the Shell Command Interface](#usage-of-the-shell-command-interface).

Once `cpm` has a valid CP/M drive, it pages out the ROM, writes a new Page 0 with the CP/M data and interrupt linkages, and passes control to the CCP.

In the 8085 CPU Module builds the CPU Serial Output (SOD) FTDI interface found on the CPU Module is also supported as the CP/M __`LPT:`__ device. It is enabled from within CP/M using __`^P`__ from the CCP command line as normal.

### CP/M System Disk

Because the CCP/BDOS and BIOS are stored in ROM, there are no CP/M-IDE boot sectors or special boot drive. Cold and warm boot are both from ROM. This means that the 4 drives supported by CP/M-IDE are completely orthogonal. It doesn't matter which drive file is mounted on which drive letter, except that the file mounted as the __`A:`__ drive will always be selected as the default drive, if you try to select a nonexistent drive letter. There is no special system disk, except that system utilities are commonly stored on one drive, and this is usually called `sys.cpm`, for convenience. CP/M drive files can take any naming convention desired.

The [RunCPM system disk](https://github.com/MockbaTheBorg/RunCPM/tree/master/DISK) contains a good package of CP/M utilities, that has been loaded onto an example [system disk](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/SYS.CPM.zip) for a complete ready to run CP/M. Typically, by convention only, this disk will be mounted as drive `A:`.

The [NGS Microshell](http://www.z80.eu/microshell.html) can be very useful for those familiar with unix-like shells, so it has been added to the example [system disk](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/SYS.CPM.zip) too. There is no need to replace the DRI CCP with Microshell. In fact, adding it permanently would remove the special `EXIT` function built into the DRI CCP to provide a clean return to the CP/M-IDE shell.

Also the NZ-COM, or Z-System, can be loaded, temporarily overwriting the DRI CCP and BDOS, from the included [NZ-COM disk](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/NZCOM.CPM.zip). Further information on NZ-COM and how to use it can be found in the [NZ-COM User's Manual](https://oldcomputers.dyndns.org/public/pub/manuals/zcpr/nzcom.pdf).

### CP/M Application Disks

The [CP/M Drives directory](https://github.com/RC2014Z80/RC2014/tree/master/ROMs/CPM-IDE/CPM%20Drives) contains a number of CP/M drives containing commonly used applications, such as the [Zork Series](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/ZORK.CPM.zip), [BBC Basic](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/BBCBASIC.CPM.zip), [Hi-Tech C v3.09-15](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/HITECHC.CPM.zip), and [MS BASIC Compiler v5.3](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/MSBASCOM.CPM.zip). MS Basic `mbasic` (Interpreter) 5.21 is available in the [system drive](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/SYS.CPM.zip).

An empty [CP/M 8 MB drive](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/TEMPLATE.CPM.zip) file is provided as a template to create additional user drives. `mkfs.cpm -f rc2014-8MB` writes the directory and leaves the image at 128 KB. `truncate -s 8388608 file.cpm` extends that file to a full drive (`truncate -s 8M` is the same length). The directory already written stays in place, and the added bytes read as zeros. Unzipping the template and renaming it also produces a full 8 MB drive with 2048 directory entries.

`hget` writes an image onto the card without moving the drive to the host. The file has to be one contiguous cluster run before `cpm` will mount it. [Sending a file to the RC2014](#sending-a-file-to-the-rc2014) covers `bin2hex.py`, `frag`, and a `cp` that allocates a fresh chain.

FAT32 can hold more than 65,000 files in one directory. A 128 GB drive holds about 16,000 of these 8 MB CP/M drives. A larger disk can hold more, and that upper limit has not been tested.

### CP/M TOOLS Usage

CP/M drive files can be read and written using a host computer with any operating system, by using the [`cpmtools`](http://www.moria.de/~michael/cpmtools/) utilities, simply by inserting the PATA IDE drive into a USB drive caddy.

The CP/M TOOLS package v2.23 is available from [debian repositories](https://packages.debian.org/sid/cpmtools).

Check the disk image, `ls` a CP/M image, copy a file (in this case `bbcbasic.com`).

```bash
> fsed.cpm -f rc2014-8MB a.cpm
> cpmls -f rc2014-8MB a.cpm
> cpmcp -f rc2014-8MB a.cpm ~/Desktop/CPM/bbcbasic.com 0:BBCBASIC.COM
```
__NOTE:__ Before use of the `cpmtools`, the contents of the host `/etc/cpmtools/diskdefs` file need to be augmented with disk information specific to the RC2014 by appending it to the end of the file.

The CP/M-IDE default is for 8MByte drives, with up to 2048 files each.

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

## Usage of the Shell Command Interface

The shell is `common/yash.c`. The command line is in C. The functions under it are in C or in assembly. The serial interfaces (ACIA, SIO/2, UART, and 8085 SOD) use __115200 baud 8n2__.

Backspace and DEL stop at the prompt. CR+LF, or LF+CR, is one end of line. The second byte does not start an empty command. The shell drops a byte below space or above 126. A NUL at the start of the line is an empty command, and the shell does not run it.

Ctrl-P and Ctrl-N recall up to 8 lines of 80 characters. The shell erases the previous line with backspace. The console drops a bare CR.

Again, here is a view of what success looks like.

<div>
<table style="border: 2px solid #cccccc;">
<tbody>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/cpm-idev8.png" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/cpm-idev8.png"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><center>RC2014 CP/M-IDE SIO - Shell CLI</center></th>
</tr>
</tbody>
</table>
</div>

### CP/M Functions
- `cpm file.a [file.b] [file.c] [file.d]` — start CP/M with 1 to 4 contiguous `.CPM` files on `A:` through `D:`. Give the full path when the file is not in the working directory. `cpm` mounts a file only when it is one cluster run.
- `hget <file>` — receive an Intel HEX file onto the FAT volume. The steps are in [Sending a file to the RC2014](#sending-a-file-to-the-rc2014).
- `mkdrv <file>` — create an empty 8 MB CP/M drive with 2048 directory entries. `frag` must report one cluster run before `cpm` mounts the file.

From the CCP, `EXIT` returns to this shell. See [CCP & BDOS Extension](#ccp--bdos-extension).

### File System Functions
- `ls [path]` — directory listing. `ls` prints the free bytes on the volume after the names.
- `cd <path>` — change the current working directory
- `pwd` — show the current working directory
- `rm <file>` — delete a file. `rm` leaves a directory and a read-only file in place.
- `rmdir <path>` — remove an empty directory
- `mkdir <path>` — create a directory
- `cp <src> <dst>` — copy a file. `cp` allocates a new cluster chain.
- `mv <src> <dst>` — in one directory, `mv` renames the entry. To another directory, `mv` writes a new entry for the same chain and removes the old name. `mv` keeps the existing cluster chain.
- `frag <file>` — cluster-run count for a file
- `mount` — mount the FAT file system

### Disk Functions
- `ds` — disk status
- `dd [sector]` — disk dump, sector in decimal

### System Functions
- `md [origin]` — memory dump, origin in hexadecimal
- `help` — this is it
- `exit` — restart the RC2014

### Sending a file to the RC2014

[`tools/bin2hex/bin2hex.py`](tools/bin2hex/bin2hex.py) converts a normal file into Intel HEX for __`hget`__. One command runs `objcopy -I binary -O ihex` and writes the `.hex` beside the input (`drive.cpm` becomes `drive.hex`). `objcopy` marks each 64 KB boundary below 1 MB with a type `02` record. __`hget`__ advances past 64 KB only on a type `04` record, so the script rewrites those records. An 8 MB `.CPM` image and any smaller binary use the same command. The result has to be 16 MB or less, which is the size __`hget`__ accepts. The tool's own notes are in [`tools/bin2hex/README.md`](tools/bin2hex/README.md).

```bash
python3 tools/bin2hex/bin2hex.py drive.cpm
```

On the shell, with the serial link at __115200 baud 8n2__ and hardware flow control enabled:

```text
hget DRIVE.CPM
```

__`hget`__ prints `Waiting for Intel HEX`. Send `drive.hex` with `ascii-xfr -s` (in minicom, Ctrl-A S, then the ascii protocol). Leave `-e` off. The type `01` record at the end of the file finishes the receive, and a trailing Ctrl-Z would be left for the shell. Hardware flow control lets the receive ring pause the host while a sector is written. Success prints the byte count (`8388608 bytes` for a full CP/M drive). A bad line prints `bad hex`. The name stored on the card is the __`hget`__ argument, in 8.3 form.

__`frag DRIVE.CPM`__ prints the cluster count, the run count, and the size. __`cpm`__ mounts the file only when that is one run.

When __`frag`__ reports more than one run, copy the file to a new name. __`cp`__ allocates a new cluster chain, starting at the next free cluster and then taking each following free cluster, which often lands as a single run:

```text
cp DRIVE.CPM DRIVE2.CPM
frag DRIVE2.CPM
```

When the copy is one run, __`rm DRIVE.CPM`__ drops the fragmented original. __`mv DRIVE2.CPM DRIVE.CPM`__ puts the name back. A rename keeps the clusters of the copy. __`mv`__ of the fragmented file does not allocate a new chain, so it cannot join the runs.

### Working drive

The shell writes on the FAT volume, so a new working drive does not have to be built on a PC. On the card:

```text
mkdrv WORK.CPM
frag WORK.CPM
cpm SYS.CPM WORK.CPM
```

__`mkdrv`__ writes an empty 8 MB drive with 2048 directory entries. __`frag`__ has to report one cluster run before __`cpm`__ will mount the file. __`cp`__, __`mv`__, __`rm`__, __`mkdir`__, and __`rmdir`__ change the FAT volume as well. A file prepared on the host, including a full `.CPM` image, is sent with __`hget`__ as described in [Sending a file to the RC2014](#sending-a-file-to-the-rc2014). Copying the template drive onto the card from a PC still works, and so does `mkfs.cpm -f rc2014-8MB` followed by `truncate -s 8388608`.

When working with a CP/M compiler or editor, keep that work on its own drive file. The shell can __`cp`__ an existing drive to a new name, which allocates a fresh cluster chain.

On first entry to CP/M, mount `sys.cpm` and the new working drive. Copy the CP/M commands you want onto the working drive with `PIP`. Later boots can mount only the working drive on `A:`. The CCP already has `DIR`, `REN`, `ERA`, `TYPE`, and `EXIT`. A program that runs under the CCP is a file inside the CP/M drive. Upload that file with `XMODEM` after __`cpm`__ has started. __`hget`__ stores its file on the FAT volume.

Then, on each subsequent boot-up of CP/M only mounting the working drive in drive `A:` is necessary. After compiling a new project with z88dk, the work-in-progress application `*.COM` file can be uploaded to the RC2014 using `XMODEM` and then tested. If the work-in-progress crashes CP/M, or needs further work, then repeat the process as needed without danger of trashing any other unmounted drives. An example `picocom` command line is provided below, although many other `XMODEM` tools are available.

`picocom -b 115200 -f h --stopbits 2 --send-cmd "sz -vv --xmodem" --receive-cmd "rz -vv -E --xmodem" /dev/ttyUSB0`

Of course other development workflows are possible, as is simply mounting the [ZORK](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/ZORK.CPM.zip) games drive and playing an adventure game.

## Preparing CP/M applications with z88dk using ChaN FatFS (`-subtype=cpm`)

The **CP/M-IDE ROM** is built with bare-metal serial subtypes (`-subtype=sio` / `uart` / `acia`, or the 8085 hybrids). The shell mounts `.CPM` drive files through `common/fatfs.asm` (8085: `fatfs_85.asm`), linked from `cpm22.lst`. That is **firmware**, not a CP/M application.

**CP/M applications** (`.COM` files you upload and run under the CCP) should be built with the RC2014 **CP/M subtype**:

```bash
zcc +rc2014 -subtype=cpm -clib=new app.c -o app -m
```

With that subtype, unprefixed file calls (`open` / `read` / `write` / `lseek` / `close`) use **BDOS FCB** on the mounted CP/M drives (e.g. `A:`). Console I/O is also via BDOS.

Optional **FatFs** on the same IDE/CF media (ChaN `f_*`, independent of FCB) uses the full read/write `ff` package and in-tree diskio:

```bash
z88dk-lib +rc2014 ff time
zcc +rc2014 -subtype=cpm -clib=new app.c \
  -llib/rc2014/ff -llib/rc2014/time -o app -m
```

Both stacks may be used in one binary (BDOS files and FatFs volumes such as `0:`). A CP/M application that wants ChaN `f_*` links `ff`, not the ROM shell.

Policy, dual-stack rules, and fuller recipes:

* [z88dk wiki — Newlib File I/O and FatFs](https://github.com/z88dk/z88dk/wiki/Newlib_File_IO_and_FatFs)
* Package sources: [feilipu/z88dk-libraries](https://github.com/feilipu/z88dk-libraries)
* RC2014 [Using Z88DK](https://github.com/RC2014Z80/RC2014/wiki/Using-Z88DK) (subtypes and general z88dk usage)

## Building Software from Source

The z88dk command lines to build the **CP/M-IDE ROM** (firmware) for the Z80 CPU are below. For the RC2014, build with the `rc2014` target and the relevant subtype, from within the relevant directory.

First though, refer to the library, disk and buffer configuration notes below.

`zcc +rc2014 -subtype=sio -SO3 --opt-code-speed -m --max-allocs-per-node400000 @cpm22.lst -o ../rc2014-cpm22-z80-pata-sio -create-app`

`zcc +rc2014 -subtype=sio -SO3 --opt-code-speed -m --max-allocs-per-node400000 @cpm22.lst -o ../rc2014-cpm22-z80-cf-sio -create-app`

`zcc +rc2014 -subtype=uart -SO3 --opt-code-speed -m --max-allocs-per-node400000 @cpm22.lst -o ../rc2014-cpm22-z80-cf-uart -create-app`

`zcc +rc2014 -subtype=acia -SO3 --opt-code-speed -m --max-allocs-per-node400000 @cpm22.lst -o ../rc2014-cpm22-z80-cf-acia -create-app`


The z88dk command lines to build the CP/M-IDE for the 8085 CPU Module are below. The `rc2014` target and relevant subtype should be selected, from within the relevant directory. Set `Z88DK` to your z88dk install root. The `-I${Z88DK}/include` path must precede the `_DEVELOPMENT/common` include path so classic `<stdio.h>` is used (required for `stdin`/`stdout` on the hybrid 8085 CRT).

The 8085 PATA image names the sccz80 speed options and leaves `lib/z80rules.8` off. `--opt-code-speed=all` runs that inline-int rules file, and with it this image is larger than 32 KiB. The two 8085 CF images still fit with `=all`.

`zcc +rc2014 -subtype=uart85 -O2 --opt-code-speed=lshift32,rshift32,add32,sub32,sub16,intcompare,charcompare,longcompare,ucharmult,floatconst -m -D__CLASSIC -DAMALLOC -I${Z88DK}/include -I${Z88DK}/include/_DEVELOPMENT/common -I${Z88DK}/libsrc/target/rc2014 -L${Z88DK}/lib/clibs/sccz80 @cpm22.lst -o ../rc2014-cpm22-8085-pata-uart -create-app`

`zcc +rc2014 -subtype=uart85 -O2 --opt-code-speed=all -m -D__CLASSIC -DAMALLOC -I${Z88DK}/include -I${Z88DK}/include/_DEVELOPMENT/common -I${Z88DK}/libsrc/target/rc2014 -L${Z88DK}/lib/clibs/sccz80 @cpm22.lst -o ../rc2014-cpm22-8085-cf-uart -create-app`

`zcc +rc2014 -subtype=acia85 -O2 --opt-code-speed=all -m -D__CLASSIC -DAMALLOC -I${Z88DK}/include -I${Z88DK}/include/_DEVELOPMENT/common -I${Z88DK}/libsrc/target/rc2014 -L${Z88DK}/lib/clibs/sccz80 @cpm22.lst -o ../rc2014-cpm22-8085-cf-acia -create-app`

The ROM shell no longer links ChaN `ff_ro`. `common/yash.c` calls the mini-FAT in `common/fatfs.asm`. Volume rules and the BIOS sector hand-off are in [Modifications to the CCP and BDOS](readme_ccp_bdos.md). A [FATFS library](https://github.com/feilipu/z88dk-libraries/tree/master/ff) is still what a CP/M application links when it wants ChaN `f_*` on the IDE volume.

CP/M "drives" are 8 MB `.CPM` files. Prepare them on a host with [cpmtools](http://www.moria.de/~michael/cpmtools/) using the `rc2014-8MB` diskdef in [`cpmtools/readme_cpmtools.md`](cpmtools/readme_cpmtools.md) (`blocksize 4096`, `maxdir 2048`, `boottrk -`).

Again: ROM builds use **bare** subtypes and `common/fatfs.asm`; application `.COM` builds under running CP/M use **`-subtype=cpm`** (FCB file I/O) and optional full `ff` / `time` for FatFs — see [Preparing CP/M applications with z88dk using ChaN FatFS](#preparing-cpm-applications-with-z88dk-using-chan-fatfs--subtypecpm) above.

The sizes of the serial transmit and receive buffers are set within the z88dk RC2014 target configuration files for the [ACIA](https://github.com/z88dk/z88dk/blob/master/libsrc/target/rc2014/config/config_acia.m4), [SIO/2](https://github.com/z88dk/z88dk/blob/master/libsrc/target/rc2014/config/config_sio.m4), and [UART](https://github.com/z88dk/z88dk/blob/master/libsrc/target/rc2014/config/config_uart.m4) respectively.

#### PATA versus Compact Flash

The shell FatFs path uses the z88dk IDE driver. Set `__IO_CF_8_BIT` in `config_target.m4`, then rebuild the rc2014 libraries, then build the HEX.

- PATA (IDE Hard Drive Module, 8255 at `$20`–`$23`): `__IO_CF_8_BIT = 0`.
- Compact Flash Module (ports `$10`–`$17`): `__IO_CF_8_BIT = 1`.

A PATA ROM linked with the CF 8-bit library returns `FR_NOT_READY` on `ls` and `mount 1`. Delayed `mount` still prints `FR_OK` because it does not talk to the disk.

The disk access configuration, for either 16-bit PPIDE or 8-bit CF IDE, is [configured here](https://github.com/z88dk/z88dk/blob/master/libsrc/target/rc2014/config/config_target.m4#L22). PATA HEX files in this tree were built with `__IO_CF_8_BIT = 0`. CF HEX files were built with `__IO_CF_8_BIT = 1`. Rebuild the rc2014 libraries when you change that flag. Do not mix a PATA HEX with a CF library. The availability of the shadow RAM for 128kB RAM systems ([SC108](https://smallcomputercentral.com/rcbus/sc100-series/sc108-z80-processor-rc2014/), etc) is [configured here](https://github.com/z88dk/z88dk/blob/master/libsrc/target/rc2014/config/config_ram.m4#L10). Following changes to any of the configurations, the z88dk libraries for RC2014 should be rebuilt.

## Licence

_"Let this paragraph represent a right to use, distribute, modify, enhance, and otherwise make available in a nonexclusive manner CP/M and its derivatives. This right comes from the company, DRDOS, Inc.'s purchase of Digital Research, the company and all assets, dating back to the mid-1990's. DRDOS, Inc. and I, Bryan Sparks, President of DRDOS, Inc. as its representative, is the owner of CP/M and the successor in interest of Digital Research assets."_
[Reference](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/BryanSparks-CPM-20220707.pdf)
