# Binary to CP/M converter - Python version


Converts a CP/M file to a .hex file to use it with Grant Searle's download.com.
http://searle.x10host.com/cpm/#InstallingApplications

Python version by Dominique Meurisse, based on C source of Christian Frintrup

## Features
* can create output file (ASCII encoding) with HEX content
* can send HEX content over serial connexion (with 1ms pause between characters)
* can send HEX to stdout (terminal) when no output and no device are selected
* can force CR or LF to CRLF (for text file)
* can read/write file in/to subdirectory or absolute path. Only the filename is kept for CP/M name.
* __can send several files at once__ by using a wildcard in filename (see examples)

## Know issues and limitations
1. CPM must be in `USER 0` before starting btc.py (to gain access to A:DOWNLOAD).
2. Serial connection is established @ 115200 bauds 8N1 (fixed)
3. Sent files to the current CP/M drive. Destination drive must be set with minicom prior the btc.py call.
4. __Minicom must be disconnected__ from serial before starting btc.py . The script will not receives the DOWNLOAD.COM responses WHEN minicom is connected to serial port (Linux)

# Dependencies

If you want to send file directly over serial then [pySerial](https://pyserial.readthedocs.io/en/latest/pyserial_api.html) must be installed.

# Usage
Ensure btc.py available your can start it with `python3 btc.py <parameters>` or `./btc.py <parameter>` of script is set as executable.

```
./btc.py -u <user> <filename>  -o <output> -d <device> -h -t
```

* __-u user :__ 0 .. 9. CP/M user identification. REQUIRED
* __filename :__ the source file to transform in HEX. REQUIRED
* __-o output :__ output filename where the HEX will be stored. Optional
* __-d device :__ serial device where the HEX must be sent. Optional
* __-h :__ display this help.')
* __-t :__ Force \r or \n to \r\n. Text only!

IF none of -o or -d is defined THEN the stdout is used instead!

IF <filename> contains a * wildcard THEN several files are sent! Wildcarded filename entry must be single quoted (Eg: `./btc.py -u 0 '*.COM'  -d /dev/ttyACM0`). -o is ignored when wildcard is used.


# Examples

Convert a file to HEX for user 1 and store it into a local file named `mbasic.hex` .

```
python3 btc.py mbasic.com -u 1 -o mbasic.hex
```

Convert the file `zork1.dat` for user 0 and output it on the screen.

```
./btc.py -u 0 zork1.dat
```

Convert the text file `lists.txt` for user 0, force the CR &/or LF to CRLF. Then send it over serial to /dev/ttyACM0 (for Linux machine).

```
./btc.py -u 0 lists.txt -d /dev/ttyACM0
```

Convert the text file `table.dat` for user 8. Save it to HEX file AND ALSO send it over serial to /dev/ttyACM0 (for Linux machine).

```
./btc.py -u 8 table.dat -o table.hex -d /dev/ttyACM0
```

The following example use a wildcard to identify the target files to sent.

__Remark__: the quotes around the wildcard avoids the operaring system (like Linux) to interpret the wildcard (and substitue it) prior the python script call.

```
./btc.py -u 1 '*.*' -d /dev/ttyACM0
```

This command is allows to send the complete wordstar disk (85 files) from the [multicomp-cpm-disk](https://obsolescence.wixsite.com/obsolescence/multicomp-fpga-cpm-demo-disk) to disk D user 3 .

```
./btc.py -u 3 '/home/domeu/Bureau/RC2014/file-transfert-program/multicomp-cpm-demo/disk_D_user_3/*.*' -d /dev/ttyACM0
```
Here the result of that command:

```
$ ./btc.py -u 3 '/home/domeu/Bureau/RC2014/file-transfert-program/multicomp-cpm-demo/disk_D_user_3/*.*' -d /dev/ttyACM0
/home/domeu/Bureau/RC2014/file-transfert-program/multicomp-cpm-demo/disk_D_user_3/*.*
Files: staff.def, wsu.com, batch.ovr, index.com, rsmsgs.ovr, rinstall.com, csdump.ovr, productr.def, customer.dta, starindx.com, customer.ndx, formsort.ovr, nosel.rel, menu.com, wm.com, coltab.mac, help1.csd, noreport.rel, wsmsgs.ovr, helper.csd, cd.com, ws.ins, sort.com, clientsr.def, products.dta, instcs.dat, nocol.rel, staff.ndx, payments.def, spelstar.dct, mpmpatch.com, ebctab.mac, sample.dat, datastar.com, okstates.ndx, order.def, format.fmt, cs.ovr, clientsr.dta, puteof.com, formgen.com, payments.dta, report.com, cs.com, clientsr.ndx, rgen.com, sample.txt, machines.txt, wsovly1.ovr, csmask.msk, customer.dtb, help2.csd, remsgs.ovr, helper.dmp, sp.com, winstall.com, syseqa.mac, invce.dta, csdump.com, subrdemo.mac, redit.com, mailmrge.ovr, dinstall.com, noerr.rel, ws.com, sorlib.rel, okstates.dta, instcs.com, products.ndx, instcs.ovr, print.tst, formsort.com, productr.ndx, invce.ndx, termcap.sys, style.com, customer.ndy, productr.dta, payments.ndx, invce.def, balsheet.csd, sort.rel, wm.hlp, staff.dta, spelstar.ovr
  1/85        staff.def  - progress: 100.0 %
  2/85          wsu.com  - progress: 100.0 %
  3/85        batch.ovr  - progress: 100.0 %
  4/85        index.com  - progress: 100.0 %
  5/85       rsmsgs.ovr  - progress: 100.0 %
  6/85     rinstall.com  - progress: 100.0 %
  7/85       csdump.ovr  - progress: 100.0 %
  8/85     productr.def  - progress: 100.0 %
  9/85     customer.dta  - progress: 100.0 %
 10/85     starindx.com  - progress: 100.0 %
 11/85     customer.ndx  - progress: 100.0 %
 12/85     formsort.ovr  - progress: 100.0 %
 13/85        nosel.rel  - progress: 100.0 %
 14/85         menu.com  - progress: 100.0 %
 15/85           wm.com  - progress: 100.0 %
 16/85       coltab.mac  - progress: 100.0 %
 17/85        help1.csd  - progress: 100.0 %
 18/85     noreport.rel  - progress: 100.0 %
 19/85       wsmsgs.ovr  - progress: 100.0 %
 20/85       helper.csd  - progress: 100.0 %
 21/85           cd.com  - progress: 100.0 %
 22/85           ws.ins  - progress: 100.0 %
 23/85         sort.com  - progress: 100.0 %
 24/85     clientsr.def  - progress: 100.0 %
 25/85     products.dta  - progress: 100.0 %
 26/85       instcs.dat  - progress: 100.0 %
 27/85        nocol.rel  - progress: 100.0 %
 28/85        staff.ndx  - progress: 100.0 %
 29/85     payments.def  - progress: 100.0 %
 30/85     spelstar.dct  - progress: 100.0 %
 31/85     mpmpatch.com  - progress: 100.0 %
 32/85       ebctab.mac  - progress: 100.0 %
 33/85       sample.dat  - progress: 100.0 %
 34/85     datastar.com  - progress: 100.0 %
 35/85     okstates.ndx  - progress: 100.0 %
 36/85        order.def  - progress: 100.0 %
 37/85       format.fmt  - progress: 100.0 %
 38/85           cs.ovr  - progress: 100.0 %
 39/85     clientsr.dta  - progress: 100.0 %
 40/85       puteof.com  - progress: 100.0 %
 41/85      formgen.com  - progress: 100.0 %
 42/85     payments.dta  - progress: 100.0 %
 43/85       report.com  - progress: 100.0 %
 44/85           cs.com  - progress: 100.0 %
 45/85     clientsr.ndx  - progress: 100.0 %
 46/85         rgen.com  - progress: 100.0 %
 47/85       sample.txt  - progress: 100.0 %
 48/85     machines.txt  - progress: 100.0 %
 49/85      wsovly1.ovr  - progress: 100.0 %
 50/85       csmask.msk  - progress: 100.0 %
 51/85     customer.dtb  - progress: 100.0 %
 52/85        help2.csd  - progress: 100.0 %
 53/85       remsgs.ovr  - progress: 100.0 %
 54/85       helper.dmp  - progress: 100.0 %
 55/85           sp.com  - progress: 100.0 %
 56/85     winstall.com  - progress: 100.0 %
 57/85       syseqa.mac  - progress: 100.0 %
 58/85        invce.dta  - progress: 100.0 %
 59/85       csdump.com  - progress: 100.0 %
 60/85     subrdemo.mac  - progress: 100.0 %
 61/85        redit.com  - progress: 100.0 %
 62/85     mailmrge.ovr  - progress: 100.0 %
 63/85     dinstall.com  - progress: 100.0 %
 64/85        noerr.rel  - progress: 100.0 %
 65/85           ws.com  - progress: 100.0 %
 66/85       sorlib.rel  - progress: 100.0 %
 67/85     okstates.dta  - progress: 100.0 %
 68/85       instcs.com  - progress: 100.0 %
 69/85     products.ndx  - progress: 100.0 %
 70/85       instcs.ovr  - progress: 100.0 %
 71/85        print.tst  - progress: 100.0 %
 72/85     formsort.com  - progress: 100.0 %
 73/85     productr.ndx  - progress: 100.0 %
 74/85        invce.ndx  - progress: 100.0 %
 75/85      termcap.sys  - progress: 100.0 %
 76/85        style.com  - progress: 100.0 %
 77/85     customer.ndy  - progress: 100.0 %
 78/85     productr.dta  - progress: 100.0 %
 79/85     payments.ndx  - progress: 100.0 %
 80/85        invce.def  - progress: 100.0 %
 81/85     balsheet.csd  - progress: 100.0 %
 82/85         sort.rel  - progress: 100.0 %
 83/85           wm.hlp  - progress: 100.0 %
 84/85        staff.dta  - progress: 100.0 %
 85/85     spelstar.ovr  - progress: 100.0 %
```
