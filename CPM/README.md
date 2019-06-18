CP/M related files

In order to run CP/M on the RC2014 there must be a monitor loaded from ROM which can then load CP/M from compact flash.

If you wish to create your own ROM, you will need 2 files; firstly monitorload.hex burned on to ROM, then 0x0100 bytes later, monitor.bin which can be found in the 68B50 ACIA folder.  The ROM available from Tindie has these burned at 0x8000 and 0x8100 respectively.

The monitorload.hex is a very simple program that copies itself and the monitor from the low area of ROM up to RAM, then pages out the ROM (and therefore pages in the lower RAM), and then copies the monitor back down to run from 0x0000 from RAM.

To get CP/M on to compact flash, you may be able to copy the image file directly on to CF card - however, read all the caveats in the Compact Flash Image file first.

The harder, but more reliable method is to follow Grant Searle's instructions and files found at [searle.hostei.com/grant/cpm/](http://searle.hostei.com/grant/cpm/). However, because this was written with the Z80 SIO/2 keep in mind you will need to substitute the modified files in the 68B50 ACIA folder.
