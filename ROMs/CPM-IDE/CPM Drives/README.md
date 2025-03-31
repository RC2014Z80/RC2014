# CP/M-IDE Drive Files

This directory contains example CP/M drives stored as compressed zip files. The files can be extracted and stored on a PATA or CF disk formatted with FAT32 (or FAT16 if quite small).

When in the CP/M-IDE shell each resulting file (example listing below) should be checked to confirm it has not been fragmented using __`frag`__. This check needs to be done only once on creation.

Using __`ls`__ a listing of the available CP/M drive files in each directory can be generated. __`cd`__ and __`pwd`__ can be used to move freely within sub-directories as desired.

CP/M-IDE can be started with the __`cpm`__ command with fully qualified paths to up to four (4) files, from any of the thousands of CP/M drives you may have stored.


```
----A 2020/04/26 12:19   8388608  BBCBASIC.CPM
----A 2022/06/12 16:42   8388608  HITECHC.CPM
----A 2024/02/26 07:08   8388608  ITDARK.CPM
----A 2020/04/26 12:20   8388608  MSBASCOM.CPM
----A 2020/04/26 12:20   8388608  MSCOBOL.CPM
----A 2020/05/13 18:03   8388608  NZCOM.CPM
----A 2020/05/10 20:55   8388608  PLI.CPM
----A 2021/03/01 13:30   8388608  SLRTOOL.CPM
----A 2025/03/16 20:55   8388608  SYS.CPM
----A 2020/04/01 10:01   8388608  TEMPLATE.CPM
----A 2022/07/10 20:52   8388608  TURBOP.CPM
----A 2020/04/26 13:37   8388608  USER.CPM
----A 2020/04/26 12:21   8388608  ZORK.CPM
----A 2021/03/01 13:30   8388608  SLRTOO~1.CPM
  14 File(s), 117440512 bytes total
   0 Dir(s), 1599078400 bytes free
```

From within CP/M directory listings of each of the above drive files are provided below.

## SYS.CPM

```
ASM     .COM   8k : CAL     .COM  16k : DDIR    .COM   8k : DDT     .COM   8k
DUMP    .COM   4k : ED      .COM   8k : ERASE   .SUB   4k : FULLPRMP.SUB   4k
INFO    .COM   4k : KERMIT  .COM  32k : LOAD    .COM   4k : LS      .COM   8k
LU      .COM  20k : LUA     .COM   4k : MAC     .COM  16k : MBASIC  .COM  24k
MLOAD   .COM   4k : MOVCPM  .COM  12k : NORMPRMP.SUB   4k : NSWP    .COM  12k
PIP     .COM   8k : SD      .COM   8k : SH      .COM  12k : SH      .OVR  12k
SHSAVE  .COM   4k : STAT    .COM   8k : SUBMIT  .COM   4k : SURVEY  .COM   4k
SYSGEN  .COM   4k : UNARC   .COM   8k : UNCR    .COM   8k : USQ     .COM   4k
XMODEM  .COM   4k : XSUB    .COM   4k : YASH    .COM  36k : YASH85  .COM  40k
YASH85CF.COM  40k : YASHCF  .COM  36k : Z80ASM  .COM  28k : ZEXALL  .COM  12k
ZEXDOC  .COM  12k : ZSID    .COM  12k : ZTRAN   .COM   4k
         Drive A0   Files: 43/516k   Free: 7612k 
```
The [NGS Microshell](http://www.z80.eu/microshell.html) can be very useful for those familiar with unix-like shells, so it has been added to the example [system disk](https://github.com/RC2014Z80/RC2014/blob/master/ROMs/CPM-IDE/CPM%20Drives/SYS.CPM.zip) too. There is no need to replace the DRI CCP with Microshell. In fact, adding it permanently would remove the special `EXIT` function built into the DRI CCP to provide a clean return to the CP/M-IDE shell. It can be launched with __`SH`__.

The __`YASH`__ application can be used to modify the files from the underlying FAT32 drive from within CP/M. Capabilities include creating CP/M drive files. Listing, copying and deleting files. And mounting additional CP/M drive files from within CP/M.

```
> help
yash v1.2 2025
The following functions are built in:
  dmount drive: [path]file - mount a CP/M drive
  mkdrv [file][extents][bytes] - create a FATFS CP/M drive file, dir directory extents, of bytes size
  frag [file] - check for file fragmentation
  ls [path] - directory listing
  rm [file] - delete a file
  cp [src][dest] - copy a file
  mv [src][dest] - move (rename) a file
  cd [path] - change the current working directory
  pwd - show the current working directory
  mkdir [path] - create a new directory
  chmod [path][attr][mask] - change file or directory attributes
  mount [drive] - mount a FAT file system
  umount [drive] - unmount a FAT file system
  ds [drive] - disk status
  dd [drive][sector] - disk dump, drive in decimal, sector in decimal
  md [origin] - memory dump, origin in hexadecimal
  help - this is it
  exit - exit and return to CCP

```

## [BBCBASIC.CPM](https://github.com/jblang/bbcbasic-z80)

```
                              BBC BASIC (Z80)

                         Generic CP/M Version 3.00

                    (C) Copyright R.T.Russell 1982-1999

1. INTRODUCTION

   BBC  BASIC (Z80) has been designed to be as compatible as  possible  with 
   Version 4 of the 6502 BBC BASIC resident in the BBC Micro Master  series.  
   The language syntax is not always identical to that of the 6502  version, 
   but in most cases the Z80 version is more tolerant.

   BBC  BASIC (Z80) is as machine independent as possible and, as  supplied, 
   it  will  run  on any CP/M 2.2 (or later) system using  a  Z80  processor 
   (checks  are carried out to ensure that the processor is a Z80  and  that 
   the version of CP/M is at least 2.2).  It is minimally configured for  an 
   ADM3a-compatible VDU.

   This  documentation  should be read in conjunction with  a  standard  BBC 
   BASIC  manual.  Only those features which differ from the standard  Acorn 
   versions are documented here.
```

```
ANIMAL  .BBC   4k : ANIMAL  .DAT   4k : BBCBASIC.COM  16k : BBCBASIC.TXT  16k
BBCDIST .MAC   8k : CONVERT .COM   4k : CRC     .COM   4k : CRCKLIST.CRC   4k
F-INDEX .BBC   8k : F-RAND0 .BBC   4k : F-RAND1 .BBC   4k : F-RAND2 .BBC   8k
F-RSER1 .BBC   4k : F-RSER2 .BBC   4k : F-RSTD  .BBC   4k : F-WESER1.BBC   4k
F-WESER2.BBC   4k : F-WSER1 .BBC   4k : F-WSER2 .BBC   4k : F-WSTD  .BBC   4k
MERGE   .BBC   4k : READ    .ME    4k : SORT    .BBC   4k : SORTREAL.BBC   4k
         Drive B0   Files: 24/132k   Free: 7996k 
```

## [HITECHC.CPM](https://github.com/agn453/HI-TECH-Z80-C)

```
                            HI-TECH C COMPILER
                              User's Manual
                                March 1989

       1. Introduction

            The HI-TECH C Compiler  is  a  set  of  software  which
       translates  programs written in the C language to executable
       machine code programs. Versions are available which  compile
       programs  for  operation under the host operating system, or
       which produce programs for  execution  in  embedded  systems
       without an operating system.

       1.1. Features

            Some of HI-TECH C's features are:

            A single command will compile, assemble and link entire
            programs.

            The compiler performs strong type checking  and  issues
            warnings  about  various constructs which may represent
            programming errors.

            The generated code is extremely small and fast in  exe-
            cution.

            A full run-time library is  provided  implementing  all
            standard C input/output and other functions.

            The source code for all run-time routines is provided.

            A powerful general purpose macro assembler is included.

            Programs may be generated to  execute  under  the  host
            operating  system,  or  customized  for installation in
            ROM.
```

```
$EXEC   .COM   4k : ASSERT  .H     4k : C309    .COM  20k : C309-15 .COM  28k
CGEN    .COM  44k : CONIO   .H     4k : CPM     .H     8k : CPP     .COM  28k
CREF    .COM  20k : CRTCPM  .OBJ   4k : CTYPE   .H     4k : DEBUG   .COM  16k
DEHUFF  .COM  12k : DRTCPM  .OBJ   4k : EXEC    .H     4k : FLOAT   .H     4k
HITECH  .H     4k : HTC-BIN .LBR 480k : LIBC    .LIB  84k : LIBF    .LIB  32k
LIBOVR  .LIB   4k : LIBR    .COM  20k : LIMITS  .H     4k : LINQ    .COM  32k
MATH    .H     4k : N-BODY  .C     8k : NRTCPM  .OBJ   4k : NULU    .COM  16k
OBJTOHEX.COM  24k : OPTIM   .COM  28k : OPTIONS .      4k : OVERLAY .H     4k
P1      .COM  40k : RRTCPM  .OBJ   4k : SETJMP  .H     4k : SIGNAL  .H     4k
STAT    .H     4k : STDARG  .H     4k : STDDEF  .H     4k : STDINT  .H     4k
STDIO   .H     4k : STDLIB  .H     4k : STRING  .H     4k : SYMTOAS .COM  16k
SYS     .H     4k : TIME    .H     4k : UNIXIO  .H     4k : ZAS     .COM  40k
         Drive B0   Files: 48/1108k   Free: 7020k 
```

## [ITDARK.CPM](https://github.com/kianryan/InTheDark) including [Turbo Pascal 3.0](http://www.retroarchive.org/cpm/lang/TP_301A.ZIP)

__In The Dark__

A rogue-like survival game for CP/M, DOS and modern systems.

![](https://github.com/kianryan/InTheDark/blob/main/rogue.gif)

```
ALL     .INC   4k : ANSI    .INC   4k : CPM     .INC   4k : DEBUG   .INC   4k
GRAPHICS.INC   8k : INPUT   .INC   4k : ITDARK80.COM  24k : ITDARK80.LBR  92k
ITDARK80.PAS   4k : ITEMS   .INC   4k : MAIN    .INC   4k : MONSTER .INC   4k
PLAYER  .INC   4k : ROOM    .INC  12k : TURBO   .COM  32k : TURBO   .MSG   4k
TURBO   .OVR   4k : TYPES   .INC   4k
         Drive B0   Files: 18/220k   Free: 7908k 
```

## [MSBASCOM.CPM](http://www.retroarchive.org/cpm/lang/BASCOM.ZIP)

[Microsoft BASIC Compiler v5.3](https://winworldpc.com/product/microsoft-basic/80-compiler-5x)

```
BASCOM  .COM  32k : BASCOM  .HLP  16k : BASCOM2 .HLP  32k : BASLIB  .REL  28k
BRUN    .COM  16k : CREF    .COM   4k : CREF80  .COM   4k : D       .COM   4k
L80     .COM  12k : LIB80   .COM   8k : M80     .COM  20k : MBASIC  .COM  24k
OBSLIB  .REL  48k : RANTEST .ASC   4k : RANTEST .BAS   4k : RANTEST .COM   4k
RANTEST .REL   4k : SAMPLE  .BAS   4k : SAMPLE  .COM   4k : SAMPLE  .REL   4k
         Drive B0   Files: 20/276k   Free: 7852k 
```

## [MSCOBOL.CPM](http://www.retroarchive.org/cpm/lang/mscobol.zip)

[Microsoft COBOL Compiler v4.65](http://www.bitsavers.org/pdf/microsoft/cpm/Microsoft_COBOL-80_1978.pdf)

```
CDADDS  .MAC   8k : CDADDS  .REL   4k : CDADM3  .MAC   8k : CDADM3  .REL   4k
CDANSI  .MAC   8k : CDANSI  .REL   4k : CDBEE   .MAC   8k : CDBEE   .REL   4k
CDHZ15  .MAC   8k : CDHZ15  .REL   4k : CDISB   .MAC   4k : CDISB   .REL   4k
CDPERK  .MAC   4k : CDPERK  .REL   4k : CDSROC  .MAC   4k : CDSROC  .REL   4k
CDWH19  .MAC   4k : CDWH19  .REL   4k : CDZEPH  .MAC   8k : CDZEPH  .REL   4k
COBLBX  .REL  28k : COBLIB  .REL  52k : COBOL   .COM  32k : COBOL1  .OVR  16k
COBOL2  .OVR  16k : COBOL3  .OVR  20k : COBOL4  .OVR   8k : CREF80  .COM   4k
CRTDRV  .REL   4k : CRTEST  .COB   8k : CVISAM  .COM  40k : DEBUG   .REL   8k
L80     .COM  20k : LIB     .COM   8k : M80     .COM  20k : REBUILD .COM  20k
RECOVR  .COB   8k : RUNCOB  .COM  20k : SEQCVT  .COM   8k : SQUARO  .$P    4k
SQUARO  .COB   4k
         Drive B0   Files: 41/452k   Free: 7676k 
```

## NZCOM.CPM

The NZ-COM, or Z-System, can be loaded, temporarily overwriting the DRI CCP and BDOS.

Further information on NZ-COM and how to use it can be found in the [NZ-COM User's Manual](https://oldcomputers.dyndns.org/public/pub/manuals/zcpr/nzcom.pdf).

```
!VERS--1.2H    0k : ALIAS   .CMD   4k : ARUNZ   .COM   8k : BGZRDS19.LBR   4k
CLEDINST.COM   8k : CLEDSAVE.COM   4k : CONFIG  .LBR  24k : COPY    .COM   8k
CPSET   .COM   4k : CRUNCH  .COM   8k : DOCFILES.LBR  20k : EDITNDR .COM   8k
FCP     .LBR  12k : FF      .COM   4k : HELP    .COM   8k : HLPFILES.LBR  20k
IF      .COM   8k : JETLDR  .COM  12k : LBREXT  .COM   8k : LBRHELP .COM   8k
LDIR    .COM   4k : LPUT    .COM   8k : LSH     .COM  12k : LSH     .WZ   12k
LSH-HELP.COM   4k : LSHINST .COM  12k : LX      .COM   4k : MKZCM   .COM   8k
NAME    .COM   4k : NZ-DBASE.INF   4k : NZBLITZ .COM   4k : NZBLTZ14.CFG   4k
NZBLTZ14.HZP   8k : NZCOM   .COM  12k : NZCOM   .LBR  16k : NZCPR   .LBR  40k
PATH    .COM   4k : PUBLIC  .COM   4k : PWD     .COM   4k : RCP     .LBR  20k
RELEASE .NOT  16k : SAINST  .COM   8k : SALIAS  .COM   8k : SAVENDR .COM   4k
SDZ     .COM   8k : SHOW    .COM  12k : SUB     .COM   4k : TCAP    .LBR   4k
TCJ     .INF   4k : TCJ25   .WZ    8k : TCJ26   .WZ   12k : TCJ27   .WZ   16k
TCJ28   .WZ   20k : TCJ29   .WZ   28k : TCJ30   .WZ   20k : TCJ31UPD.WZ   36k
TCJ32   .WZ   24k : TCJ33UPD.WZ   28k : TCSELECT.COM   4k : TY3ERA  .COM   4k
TY3REN  .COM   4k : TY4ERA  .COM   4k : TY4REN  .COM   4k : TY4SAVE .COM   4k
TY4SP   .COM   4k : UNCRUNCH.COM   8k : VIEW    .COM   8k : XTCAP   .COM   4k
Z3LOC   .COM   4k : Z3TCAP  .TCP  12k : ZCNFG   .COM   8k : ZERR    .COM   4k
ZEX     .COM  12k : ZF-DIM  .COM  16k : ZF-REV  .COM  16k : ZFILEB38.LZT  16k
ZFILER  .CMD   4k : ZHELPERS.LZT   4k : ZLT     .COM   8k : ZNODES66.LZT   4k
ZSYSTEM .IZF   4k
         Drive B0   Files: 81/788k   Free: 7340k 
```

## [PLI.CPM](http://www.cpm.z80.de/download/pli80_14.zip)

Digital Research PL/I-80 V1.4 with sample programs and documentation

```
A       .PLI   4k : ACK     .PLI   4k : ACKTST  .PLI   4k : ALLTST  .PLI   4k
ANNUITY .PLI   4k : CALL    .PLI   4k : COPY    .PLI   4k : COPYLPT .PLI   4k
CPMDIO  .ASM  24k : CREATE  .PLI   4k : DECPOLY .PLI   4k : DEMO    .PLI   4k
DEPREC  .PLI  12k : DFACT   .PLI   4k : DIO80   .DCL   4k : DIOCALLS.PLI  12k
DIOCOPY .PLI   4k : DIOMOD  .DCL   4k : DIORAND .PLI   4k : DIV2    .ASM   4k
DTEST   .PLI   4k : ENTER   .PLI   4k : EXPR1   .PLI   4k : EXPR2   .PLI   4k
FCB     .DCL   4k : FDIV2   .ASM   4k : FDTEST  .PLI   4k : FFACT   .PLI   4k
FLTPOLY .PLI   4k : FLTPOLY2.PLI   4k : FSCAN   .PLI   4k : HEXDUMP .PLI  12k
IFACT   .PLI   4k : INVERT  .PLI   4k : KEYFILE .PLI   4k : LABELS  .PLI   4k
LIB     .COM   8k : LINK    .COM  16k : LOAN1   .PLI   4k : LOAN2   .PLI   8k
MAININVT.PLI   4k : MATSIZE .LIB   4k : MPMCALLA.PLI  16k : MPMCALLB.PLI  12k
MPMDIO  .ASM  16k : MPMDIO  .DCL   4k : NETWORK .PLI  12k : OPTIMIST.COM  12k
OPTIMIST.PLI   4k : PLI     .COM   8k : PLI0    .OVL  20k : PLI1    .OVL  36k
PLI2    .OVL  36k : PLILIB  .IRL  72k : RECORD  .DCL   4k : RELNOTES.PRN  36k
REPORT  .PLI   4k : RETRIEVE.PLI   4k : REVERSE .PLI   4k : REVERT  .PLI   4k
RFACT   .PLI   4k : RMAC    .COM  16k : SAMPLE  .PLI   4k : TE      .COM  20k
TEST    .PLI   4k : UPDATE  .PLI   4k : XREF    .COM  16k : Z80     .LIB   8k
         Drive B0   Files: 68/612k   Free: 7516k 
```

## [SLRTOOL.CPM](http://www.retroarchive.org/cpm/lang/lang.htm)

```
Z80ASM is a powerful relocating macro assembler for Z80-based
CP/M systems. It takes assembly language source statements from
a disk file, converts them into their binary equivalent, and
stores the output in either a core-image, Intel hex format, or
relocatable object file. The mnemonics recognized are those of
Zilog/Mostek. The optional listing output may be sent to a disk
file, the console and/or the printer, in any combination. Output
files may also be generated containing cross-reference information
on each symbol used.
```

```
180FIG  .COM   4k : CONFIG  .COM   4k : LNKFIG  .COM   4k : MAKESYM .COM   4k
MAKESYM .DOC   4k : NZLNKFIX.ZEX   4k : README  .LNK   4k : SLR180  .COM  28k
SLR180  .DOC   4k : SLRIB   .COM   4k : SLRNK   .COM  12k : SLRNK1  .COM  12k
SLRNKFIX.ZEX   4k : SYNTAX  .HLP   8k : SYSSLR  .REL  24k : VSLR    .REL   4k
Z3SLR   .REL  12k : Z80ASM  .COM  28k : Z80ASM  .DOC   4k
         Drive B0   Files: 19/172k   Free: 7956k 
```

## SLRTOO~1.CPM (SLRTOOL+.CPM)

```
180FIG  .COM   4k : CONFIG  .COM   4k : CONFIGP .COM   8k : ED80INST.COM  20k
ED80INST.REL  24k : ED80INST.Z80 112k : LNKFIG  .COM   4k : MAKESYM .COM   4k
MAKESYM .DOC   4k : NZLNKFIX.ZEX   4k : README  .LNK   4k : S8      .COM  28k
SLR     .IRV   4k : SLR180  .COM  28k : SLR180  .DOC   4k : SLRIB   .COM   4k
SLRMAC  .COM  28k : SLRNK   .COM  12k : SLRNK1  .COM  12k : SLRNKFIX.ZEX   4k
SLRNKP  .COM  20k : SLRZ80+ .COM  32k : SYNTAX  .HLP   8k : SYSSLR  .REL  24k
VSLR    .REL   4k : Z3SLR   .REL  12k : Z8-NEW  .IRV   4k : Z80ASM  .COM  28k
Z80ASM  .DOC   4k : Z80ASM+ .COM  32k : Z80ASM- .MSG   4k
         Drive B0   Files: 31/488k   Free: 7640k 
```

## [TURBOP.CPM](http://www.retroarchive.org/cpm/lang/TP_301A.ZIP)

[Borland Turbo Pascal v3.0 Reference Manual](https://bitsavers.trailing-edge.com/pdf/borland/turbo_pascal/Turbo_Pascal_Version_3.0_Reference_Manual_1986.pdf)

```
MC      .HLP   8k : READ    .ME    8k : TINST   .COM  28k : TINST   .DTA   8k
TINST   .MSG   4k : TURBO   .COM  32k : TURBO   .MSG   4k : TURBO   .OVR   4k
         Drive B0   Files: 8/96k   Free: 8032k 
```

## ZORK.CPM

[Contains ZORK1, ZORK2, and ZORK3.](https://en.wikipedia.org/wiki/Zork)

```
ZORK I: The Great Underground Empire
Copyright (c) 1981, 1982, 1983 Infocom, Inc. All rights reserved.
ZORK is a registered trademark of Infocom, Inc.
Revision 88 / Serial number 840726

West of House
You are standing in an open field west of a white house, with
a boarded front door.
There is a small mailbox here.
```

```
ZORK II: The Wizard of Frobozz
Copyright (c) 1981, 1982, 1983 Infocom, Inc. All rights reserved.
ZORK is a registered trademark of Infocom, Inc.
Version 48 / Serial number 840904

Inside the Barrow
You are inside an ancient barrow hidden deep within a dark
forest. The barrow opens into a narrow tunnel at its southern
end. You can see a faint glow at the far end.
A strangely familiar brass lantern is lying on the ground.
A sword of Elvish workmanship is on the ground.
```

```
ZORK III: The Dungeon Master
Copyright 1982 by Infocom, Inc. All rights reserved.
ZORK is a trademark of Infocom, Inc.
Release 17 / Serial number 840727

Endless Stair
You are at the bottom of a seemingly endless stair, winding
its way upward beyond your vision. An eerie light, coming from
all around you, casts strange shadows on the walls. To the
south is a dark and winding trail.

Your old friend, the brass lantern, is at your feet.
```

```
FILE_ID .DIZ   4k : ZORK1   .COM  12k : ZORK1   .DAT  84k : ZORK2   .COM  12k
ZORK2   .DAT  88k : ZORK3   .COM  12k : ZORK3   .DAT  84k
         Drive B0   Files: 7/296k   Free: 7832k 
```

