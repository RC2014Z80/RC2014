# CP/M - IDE

There are several implementations of CP/M available for the RC2014. Each implementation has its own focus, and the same is true here. For larger [RC2014 Zed](https://z80kits.com/shop/rc2014-zed/) based systems with 512kB RAM [RomWBW](https://github.com/wwarthen/RomWBW/tree/master) is the right solution. For your smaller [RC2014 Pro](https://z80kits.com/shop/rc2014-pro/) based systems with 64kB RAM read on.

For further technical reading, an additional extensive [description of CP/M-IDE can be found here](https://feilipu.me/2022/03/23/cpm-ide-for-rc2014/).

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

In the SIO Serial Module builds, both ports are enabled. Both ports have a 127 byte software receive buffer supporting the SIO/2 receive quad hardware buffer, and a 15 byte software transmit buffer. The transmit function has direct cut-through when the software buffer is empty. Hardware __`/RTS`__ flow control of the SIO/2 is provided. Full IM2 interrupt vector steering is implemented.

In the Single and Dual UART Serial Module builds both ports are enabled if present. Both ports have a 127 byte software receive buffer supporting the UART 16 byte hardware receive and transmit buffers. Hardware __`/RTS`__ and Automatic Flow Control is enabled.

In the ACIA Serial Module builds, the receive interface has a 255 byte software buffer, together with optimised buffer management supporting the 68B50 ACIA receive double buffer. Hardware __`/RTS`__ flow control of the ACIA is provided. The ACIA transmit interface is also buffered, with direct cut-through when the 31 byte software buffer is empty, to ensure that the CPU is not held in wait state during transmission.

__NOTE:__ All serial interfaces (on the ACIA Serial Module, on the SIO Serial Module, on the UART Serial Module, and on the 8085 CPU Module SOD) are configured for __115200 baud 8n2__.

__NOTE:__ To enable flow control with any Serial Module it is critical to use a USB Serial adapter that supports __`/RTS`__ on Pin 6. Typical FTDI USB Adapters pinout __`/DTR`__ to Pin 6. The [recommended USB Serial adapter](https://www.tindie.com/products/8086net/uusbusb-c-cdc-serial-adaptor-5v/) is available from 8086 Consultancy.

The IDE Hard Drive Module interface driver is optimised for performance and can achieve about 110kB/s throughput, using the ChaN FATFS libraries. It does this by minimising error management and streamlining read and write routines. The assumption is that modern PATA attached IDE drives have their own error management and if there are errors from the IDE interface, then there are other issues at stake. The CF Module can achieve up to 200kB/s throughput at FATFS level, and it seems to provide best performance using SD Cards in SD to CF Card Adapters. Within CP/M performance is approximately half the FATFS performance, because the CP/M deblocking algorithm requires a double buffer copy process.

The IDE Hard Drive Module supports both PATA hard drives (including 3 1/2" magnetic platter, SSD, and DOM storage) and Compact Flash cards in their native 16-bit PATA mode, with buffered I/O provided by the 82C55 device. The IDE Hard Drive Module is the ideal way to attach "spinning rust" to your RC2014. Attaching one physical Master drive is supported.

The CP/M-IDE system supports up to 4 mounted CP/M "drives" (files) of nominally 8 MBytes each. There can be as many CP/M drives stored on the FAT32 formatted disk as desired, and CP/M-IDE can be started with any 4 of them. Collections of hundreds (or even thousands) of CP/M drives can be stored in any number of sub-directories on the FAT32 host disk, to be mounted at will.

All CP/M-IDE builds provide at least 56kB of free TPA for the user's CP/M applications. This large free TPA achieved by limiting the number of concurrently mounted CP/M drives to 4.

<div>
<table style="border: 2px solid #cccccc;">
<tbody>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/P1090689.JPG" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/P1090689.JPG"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014 CP/M-IDE with IDE Module and ACIA Module<center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0543.jpg" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0543.jpg"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014 CP/M-IDE with DOM in an IDE Module and SIO Module (front view)<center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0542.jpg" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0542.jpg"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014 CP/M-IDE with DOM in an IDE Module and SIO Module (back view)<center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_1688.JPG" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_1688.JPG"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014-8085 CP/M-IDE with DOM in an IDE Module and ACIA Module<center></th>
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

To operate the RC2014 with an 8085 CPU the following CPU Module must be exchanged for items 2. and 3, and either a ACIA Serial Module or UART Serial Module installed.

__NOTE:__ For use with the 8085 CPU Module, either the ACIA Serial Module or UART Serial Modules are supported.

- [8085 CPU Module](https://www.tindie.com/products/feilipu/8085-cpu-module-pcb/).

To operate the RC2014 with a Single UART or UART Dual UART Serial Module, it must be installed in exchange for item 6. Installation of Multiple Serial Modules is not supported.

- [Dual UART Module](https://rc2014.co.uk/modules/dual-serial-module-16c2550/).

Additionally, the ACIA Serial Module from the [RC2014 Classic II](https://rc2014.co.uk/modules/serial-io/) could be substituted for item 6. the SIO Serial Module.<br>

- [ACIA Serial Module](https://z80kits.com/shop/tynemouth-68b50-clocked-serial-port/).

Also Grant Searle's [CP/M on breadboard](http://searle.x10host.com/cpm/index.html) hardware is supported if a 32kB ROM is used, and Steve Cousins' [SC108 Module (Z80, 128k RAM, 32k ROM)](https://smallcomputercentral.com/projects/z80-processor-module-for-rc2014/) Module could be exchanged for items 2., 3., 4., and 5., because Richard Deane cared enough to ask. Thanks Richard.

As noted, when used with the IDE Hard Drive Module, both SD Cards and Compact Flash cards are also supported in their native 16-bit PATA mode, as shown below. Otherwise, when using the CF Module from the RC2014 Pro, SD Cards and Compact Flash cards are supported in the Compact Flash 8-bit compatibility mode.

<div>
<table style="border: 2px solid #cccccc;">
<tbody>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://lh3.googleusercontent.com/-fCgroN5mYU8/WrREnuPPowI/AAAAAAACR8U/IQoillkYPpYYg3ROctaQHdLqDRtZ5hwrwCLcBGAs/s1600/IMG_20180322_235743.jpg" target="_blank"><img src="https://lh3.googleusercontent.com/-fCgroN5mYU8/WrREnuPPowI/AAAAAAACR8U/IQoillkYPpYYg3ROctaQHdLqDRtZ5hwrwCLcBGAs/s320/IMG_20180322_235743.jpg"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014 running CP/M-IDE by DJRM<center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_2255.JPG" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_2255.JPG"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014-8085 running CP/M-IDE with SD to CF Storage Adapter<center></th>
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
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014 CP/M-IDE Modules (excl. ACIA)<center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_1689.JPG" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_1689.JPG"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014 CP/M-IDE 8085 Modules<center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0536.jpg" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0536.jpg"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014 64kByte RAM Module (note jumper positions)<center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0535.jpg" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0535.jpg"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014 Pageable ROM Module (note jumper positions)<center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0530.jpg" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0530.jpg"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014 IDE Hard Drive Module with DOM<center></th>
</tr>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0532.jpg" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/IMG_0532.jpg"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014 IDE Hard Drive Module storage options<center></th>
</tr>
</tbody>
</table>
</div>

## Software

The CP/M-IDE is built using the z88dk compilers and libraries, including a simple boot monitor or shell for the RC2014, together with the standard DRI CP/M CCP/BDOS, and a CP/M BIOS constructed specifically for the RC2014 in the above hardware configurations. The DRI CCP and BDOS have been optimised for performance using Z80 CPU extended instructions and 8085 CPU extended instructions, where possible. For example the Z80 `LDI` instructions have been used to improve buffer copy performance.

### Installation

Using the correct HEX file for your hardware configuration from this directory, burn it into a 32kB or 64kB EEPROM, or PROM.

To initially configure your hard drive, use either a USB caddy for your PATA IDE drive, or a CF adapter for your Compact Flash card to mount your drive on your host computer. Your host computer should be able to read and write FAT32 formatted drives. Format the drive for FAT32 (or FAT16 if it is quite small). Then __unzip__ and __"Drag and drop"__ or __copy__ some of the example [CP/M drive files](https://github.com/RC2014Z80/RC2014/tree/master/ROMs/CPM-IDE/CPM%20Drives) into the root directory of your drive. At least the `sys.cpm` example file is required (until you customise your own) as it contains many system utilities. Check that each of the drive files is using 8388608 Bytes on your IDE or CF drive. You may put the CP/M drive files into directories (to organise them based on your workflow), or leave them all in the root directory.

Connect the RC2014 hardware as shown above, and then use the commands given in the shell Command Line Interface, below.

### Boot-up Process

When the RC2014 first boots, the z88dk provided `crt0` configures a number of items via preamble code.

The preamble code copies the CCP/BDOS to the correct location, and then checks for the existence of the BIOS. If the BIOS exists, and a valid drive is found, then control is passed directly to the CCP. This is the usual situation when a CP/M application overwrites the CCP, and it needs to be rewritten before control can be returned to it. Otherwise control is returned to the preamble code to continue to load the CP/M BIOS, the serial drivers, and the disk drivers necessary for operation of the shell and CP/M.

Control is then passed to the command shell, that provides a simple command line interface to allow arbitrary FATFS files (pre-prepared as CP/M drives) to be mounted for use within CP/M, and then CP/M booted.

__NOTE:__ Where the SIO Module or the UART Module is being used, on startup the shell will wait for a `:` to establish which serial port is being used and will continue to interact on this port until CP/M is loaded.

CP/M can be started by command __`cpm file.a [file.b] [file.c] [file.d]`__. At least one valid file name must be provided. CP/M can be started with to up to four (4) files to be mounted on __`A:`__, __`B:`__, __`C:`__, and __`D:`__ drives, from any of the thousands of CP/M drive files you may have available. Up to 4 CP/M drive files can be concurrently mounted. Each CP/M drive file must be contiguous, but can be located anywhere on the FATFS drive (any LBA) in any directory, provided the full path is used to reference it.

The shell provides some other basic functions, such as __`frag`__, __`hload`__, __`ls`__, __`cd`__, and __`pwd`__ file functions, and __`mount`__, __`ds`__, and __`dd`__ disk functions. And __`md`__ to show the contents of the ROM and RAM. __`frag`__ can be used to confirm whether a CP/M drive file (or any other FAT32 file) is contiguous or fragmented. __`hload`__ can be used to upload and directly run a CP/M application, rather than from a drive. __`exit`__ can be used to restart the RC2014 if desired.

Once the shell __`cpm`__ command has established that it has a valid CP/M drive available, then it will page out the ROM, write in a new `Page 0` with relevant CP/M data and interrupt linkages, and then pass control to the CP/M CCP.

In the 8085 CPU Module builds the CPU Serial Output (SOD) FTDI interface found on the CPU Module is also supported as the CP/M __`LPT:`__ device. It is enabled from within CP/M using __`^P`__ from the CCP command line as normal.

### CP/M System Disk

Because the CCP/BDOS and BIOS are stored in ROM, there are no CP/M-IDE boot sectors or special boot drive. Cold and warm boot are both from ROM. This means that the 4 drives supported by CP/M-IDE are completely orthogonal. It doesn't matter which drive file is mounted on which drive letter, except that the file mounted as the __`A:`__ drive will always be selected as the default drive, if you try to select a nonexistent drive letter. There is no special system disk, except that system utilities are commonly stored on one drive, and this is usually called `sys.cpm`, for convenience. CP/M drive files can take any naming convention desired.

The [RunCPM system disk](https://github.com/MockbaTheBorg/RunCPM/tree/master/DISK) contains a good package of CP/M utilities, that has been loaded onto an example [system disk](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/SYS.CPM.zip) for a complete ready to run CP/M. Typically, by convention only, this disk will be mounted as drive `A:`.

The [NGS Microshell](http://www.z80.eu/microshell.html) can be very useful for those familiar with unix-like shells, so it has been added to the example [system disk](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/SYS.CPM.zip) too. There is no need to replace the DRI CCP with Microshell. In fact, adding it permanently would remove the special `EXIT` function built into the DRI CCP to provide a clean return to the CP/M-IDE shell.

Also the NZ-COM, or Z-System, can be loaded, temporarily overwriting the DRI CCP and BDOS, from the included [NZ-COM disk](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/NZCOM.CPM.zip). Further information on NZ-COM and how to use it can be found in the [NZ-COM User's Manual](https://oldcomputers.dyndns.org/public/pub/manuals/zcpr/nzcom.pdf).

As the CP/M-IDE shell doesn't have a way to format its own CP/M drives (due to ROM space constraints), a template CP/M drive is provided as a zip file. Many copies of the template zip file and any other example application zip files can be expanded and copied onto the IDE drive, and used or augmented by the CP/M Tools as noted below.

The [`yash`](https://github.com/z88dk/z88dk-ext/blob/master/os-related/CPM/yash.c) CP/M application can be uploaded using the shell `hload` and it can then create drive files using `mkdrv` command.

### CP/M Application Disks

The [CP/M Drives directory](https://github.com/RC2014Z80/RC2014/tree/master/ROMs/CPM-IDE/CPM%20Drives) contains a number of CP/M drives containing commonly used applications, such as the [Zork Series](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/ZORK.CPM.zip), [BBC Basic](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/BBCBASIC.CPM.zip), [Hi-Tech C v3.09-15](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/HITECHC.CPM.zip), and [MS BASIC Compiler v5.3](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/MSBASCOM.CPM.zip). MS Basic `mbasic` (Interpreter) 5.21 is available in the [system drive](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/SYS.CPM.zip).

An empty [CP/M 8 MB drive](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/TEMPLATE.CPM.zip) file is provided as a template to create additional user drives. Unfortunately, the CP/M tools package doesn't properly extend CP/M drive files out to the full size of 8388608 bytes when it creates them on FATFS. Using (unzipping) this template, and renaming it as desired, on a FATFS drive is all that is needed to create a new CP/M drive on any PATA hard drive or Compact Flash card. Each new file created provides a new 8 MB CP/M drive which can store up to 2048 files.

The [`yash`](https://github.com/z88dk/z88dk-ext/blob/master/os-related/CPM/yash.c) application can also be used to create, manage, and delete CP/M drive files without moving the PATA drive to a host computer. This application supports both read and write to the underlying FATFS file system.

FAT32 supports over 65,000 files in each directory. Using a 128GB drive it is possible to store more than that many 8MB CP/M-IDE drive drives on one IDE drive, although this upper limit hasn't been tested.

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

### Shell Command Interface

The shell command line interface is implemented in C, with the underlying functions either in C or in assembly. The serial interfaces (ACIA, SIO/2, UART, and 8085 SOD) are configured for __115200 baud 8n2__.

Again, here is a view of what success looks like.

<div>
<table style="border: 2px solid #cccccc;">
<tbody>
<tr>
<td style="border: 1px solid #cccccc; padding: 6px;"><a href="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/cpm-idev8.png" target="_blank"><img src="https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/cpm-idev8.png"/></a></td>
</tr>
<tr>
<th style="border: 1px solid #cccccc; padding: 6px;"><centre>RC2014 CP/M-IDE SIO - Shell CLI<center></th>
</tr>
</tbody>
</table>
</div>

### CP/M Functions
- `cpm file.a [file.b] [file.c] [file.d]` - initialise CP/M with up to 4 drive files
- `hload` - load an Intel HEX CP/M file and run it

### File System Functions
- `frag [file]` - check for file fragmentation
- `ls [path]` - directory listing
- `cd [path]` - change the current working directory
- `pwd` - show the current working directory
- `mount [option]` - mount a FAT file system, option 0 = delayed, 1 = immediate

### Disk Functions
- `ds` - disk status
- `dd [sector]` - disk dump, sector in decimal

### System Functions
- `md [origin]` - memory dump, origin in hexadecimal
- `help` - this is it
- `exit` - exit and restart shell

### CP/M CCP Extension

An additional CP/M CCP function `EXIT` provides a way to return to the shell to "change disks" by restarting CP/M with different FATFS files as input for the mounted CP/M drives. `EXIT` initialises a clean reboot of the RC2014, and returns to the command shell.

## Usage

When commencing a new project it can be convenient to start with a new clean working drive. Either the [`yash`](https://github.com/z88dk/z88dk-ext/blob/master/os-related/CPM/yash.c) shell can be used from within CP/M to create a new drive file. Or the system drive can be temporarily attached to a PC and normal file management can be used to copy the template drive file provided, and rename the newly created drive file appropriately for the project.

Alternatively when working with a CP/M compiler, or editor, making a copy of the compiler drive file and working from that copy (rather than the original) can be quite useful.

On first boot into CP/M, mount the `sys.cpm` system drive and the new working drive. It can then be useful to copy some CP/M commands onto the working drive using `PIP.COM`, then the `sys.cpm` system drive does not need to be mounted on further boots. Generally `XMODEM.COM` is all that is necessary to upload work in progress, as the CP/M CCP has `DIR`, `REN`, `ERA`, `TYPE`, and `EXIT` commands built in.

Then, on each subsequent boot-up of CP/M only mounting the working drive in drive `A:` is necessary. After compiling a new project with z88dk, the work-in-progress application `*.COM` file can be uploaded to the RC2014 using `XMODEM` and then tested. If the work-in-progress crashes CP/M, or needs further work, then repeat the process as needed without danger of trashing any other unmounted drives. An example `picocom` command line is provided below, although many other `XMODEM` tools are available.

`picocom -b 115200 -f h --stopbits 2 --send-cmd "sz -vv --xmodem" --receive-cmd "rz -vv -E --xmodem" /dev/ttyUSB0`

Of course other development workflows are possible, as is simply mounting the [ZORK](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/ZORK.CPM.zip) games drive and playing an adventure game.

## Building Software from Source

The z88dk command lines to build the CP/M-IDE for Z80 CPU is below. For the RC2014 build the `rc2014` target and relevant subtype should be used, from within the relevant directory.

First though, refer to the library, disk and buffer configuration notes below.

`zcc +rc2014 -subtype=sio -SO3 --opt-code-speed -m -llib/rc2014/ff_ro --max-allocs-per-node400000 @cpm22.lst -o ../rc2014-cpm22-z80-pata-sio -create-app`

`zcc +rc2014 -subtype=sio -SO3 --opt-code-speed -m -llib/rc2014/ff_ro --max-allocs-per-node400000 @cpm22.lst -o ../rc2014-cpm22-z80-cf-sio -create-app`

`zcc +rc2014 -subtype=uart -SO3 --opt-code-speed -m -llib/rc2014/ff_ro --max-allocs-per-node400000 @cpm22.lst -o ../rc2014-cpm22-z80-cf-uart -create-app`

`zcc +rc2014 -subtype=acia -SO3 --opt-code-speed -m -llib/rc2014/ff_ro --max-allocs-per-node400000 @cpm22.lst -o ../rc2014-cpm22-z80-cf-acia -create-app`


Alternate z88dk command lines to build the CP/M-IDE for the 8085 CPU Module is below. The `rc2014` target and relevant subtype should be selected, from within the relevant directory.

`zcc +rc2014 -subtype=uart85 -O2 --opt-code-speed=all -m -D__CLASSIC -DAMALLOC -l_DEVELOPMENT/lib/sccz80/lib/rc2014/ff_85_ro @cpm22.lst -o ../rc2014-cpm22-8085-pata-uart -create-app`

`zcc +rc2014 -subtype=uart85 -O2 --opt-code-speed=all -m -D__CLASSIC -DAMALLOC -l_DEVELOPMENT/lib/sccz80/lib/rc2014/ff_85_ro @cpm22.lst -o ../rc2014-cpm22-8085-cf-uart -create-app`

`zcc +rc2014 -subtype=acia85 -O2 --opt-code-speed=all -m -D__CLASSIC -DAMALLOC -l_DEVELOPMENT/lib/sccz80/lib/rc2014/ff_85_ro @cpm22.lst -o ../rc2014-cpm22-8085-cf-acia -create-app`

Prior to running the above build commands, in addition to the normal z88dk provided libraries, a [FATFS library](https://github.com/feilipu/z88dk-libraries/tree/master/ff) provided by [ChaN](http://elm-chan.org/fsw/ff/00index_e.html) and customised for read-only for the RC2014 must be installed, by manually copying the `ff_ro.lib` (and `ff_85_ro.lib`for the 8085 CPU Module) library files into the z88dk RC2014 newlib library directory.

Due to ROM space constraints, it is not possible to include the FATFS write functions within the CP/M-IDE ROM shell. This does not affect the use of disk read or write by CP/M or z88dk applications compiled using the default FATFS library. It simply means that CP/M-IDE "drives" must be prepared on a host using the [cpmtools](http://www.moria.de/~michael/cpmtools/) on your operating system of choice. The default (read/write) version of the [FATFS library](https://github.com/feilipu/z88dk-libraries/tree/master/ff) should be installed so that applications you compile using z88dk can read and write to the FATFS file system.

The size of the serial transmit and receive buffers are set within the z88dk RC2014 target configuration files for the [ACIA](https://github.com/z88dk/z88dk/blob/master/libsrc/_DEVELOPMENT/target/rc2014/config/config_acia.m4), [SIO/2](https://github.com/z88dk/z88dk/blob/master/libsrc/_DEVELOPMENT/target/rc2014/config/config_sio.m4), and [UART](https://github.com/z88dk/z88dk/blob/master/libsrc/_DEVELOPMENT/target/rc2014/config/config_uart.m4) respectively.

The disk access configuration, for either 16-bit PPIDE or 8-bit CF IDE, is [configured here](https://github.com/z88dk/z88dk/blob/master/libsrc/_DEVELOPMENT/target/rc2014/config/config_target.m4#L22). And the availability of the shadow RAM for 128kB RAM systems ([SC108](https://smallcomputercentral.com/projects/z80-processor-module-for-rc2014/), etc) is [configured here](https://github.com/z88dk/z88dk/blob/master/libsrc/_DEVELOPMENT/target/rc2014/config/config_ram.m4#L10). Following changes to any of the configurations the z88dk libraries for RC2014 should be rebuilt.


## Licence

_"Let this paragraph represent a right to use, distribute, modify, enhance, and otherwise make available in a nonexclusive manner CP/M and its derivatives. This right comes from the company, DRDOS, Inc.'s purchase of Digital Research, the company and all assets, dating back to the mid-1990's. DRDOS, Inc. and I, Bryan Sparks, President of DRDOS, Inc. as its representative, is the owner of CP/M and the successor in interest of Digital Research assets."_
[Reference](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/docs/BryanSparks-CPM-20220707.pdf)
