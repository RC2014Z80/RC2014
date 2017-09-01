Binary to CP/M converter v0.2
By Christian Frintrup

Converts a CP/M file to a .hex file to use it with Grant Searle's download.com.
http://searle.hostei.com/grant/cpm/#InstallingApplications

Down load main.c and build it with.
 
 gcc main.c -o btc

Ensure btc is somewhere your $PATH vairable can see

Usage: btc input-file [-u user-number, default 0] [-h help]
 
Examples: btc mbasic.com -u1 > mbasic.hex
          
btc zork1.dat
