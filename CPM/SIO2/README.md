These files are modified versions of the ones created by Grant Searle that allows the RC2014 to run CP/M via a Zilog SIO/2 on ports 0x80 - 0x83

SIOA_D .EQU $81
SIOA_C .EQU $80
SIOB_D .EQU $83
SIOB_C .EQU $82

Note that the only 2 files you probably need is ROM.HEX, to be burnt to EPROM and CPM Inc Transient Apps SIO2.img.zip which should be unpacked and the .img file needs to be written to a 128mb CF card with DD or Win32 Image Writer or similar
