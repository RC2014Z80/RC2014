new
clear
10 REM Created by Filippo Bergamasco,
11 REM and modified by DaveP for the RC2014
12 REM Adapted for z88dk by feilipu
20 REM Version 1.0
30 Print "Loading Data"
40 let mb=&H8900
50 print "Start Address: ";hex$(mb)
60 REM Go to READ Subroutine.
70 GOSUB 1000
80 print "End Address:   ";hex$(mb-1)

90 REM Change USR(0) Pointer for HexLoad
100 GOSUB 1100

110 REM RUN THE HEXLOAD CODE!
120 print usr(0)

130 REM Change USR(0) Pointer to 0x9000
140 GOSUB 1200

150 REM RUN THE PROGRAMME CODE!
160 print usr(0)
170 END 

1000 REM Routine to load Data
1010 REM Needs var mb set to start location
1020 read a
1030 if a>255 then RETURN
1040 rem print HEX$(mb),a
1050 poke mb, a
1060 let mb=mb+1
1070 goto 1020

1100 REM Location of usr address &H8049
1110 print "USR(0) -> HexLoad"
1120 let mb=&H8049 
1130 doke mb, &H8900
1140 RETURN 

1200 REM Location of usr address &H8049
1210 print "USR(0) -> 0x9000, z88dk default"
1220 let mb=&H8049
1230 doke mb, &H9000
1240 RETURN

9010 data 33,116,137,205,109,137,215,254,58,32,251,14
9040 data 0,205,83,137,71,205,83,137,87,205,83,137
9070 data 95,205,83,137,254,1,40,23,254,0,32,33
9100 data 205,83,137,18,19,16,249,205,83,137,121,183
9130 data 32,26,62,35,207,24,207,205,83,137,121,183
9160 data 32,14,33,206,137,205,109,137,201,33,172,137
9190 data 205,109,137,201,33,189,137,205,109,137,201,205
9220 data 100,137,7,7,7,7,111,205,100,137,181,111
9250 data 129,79,125,201,215,214,48,254,10,216,214,7
9280 data 201,126,183,200,207,35,24,249,72,69,88,32
9310 data 76,79,65,68,69,82,32,98,121,32,70,105
9340 data 108,105,112,112,111,32,66,101,114,103,97,109
9370 data 97,115,99,111,32,38,32,102,101,105,108,105
9400 data 112,117,32,102,111,114,32,122,56,56,100,107
9430 data 10,13,58,0,10,13,73,110,118,97,108,105
9460 data 100,32,84,121,112,101,10,13,0,10,13,66
9490 data 97,100,32,67,104,101,99,107,115,117,109,10
9520 data 13,0,10,13,68,111,110,101,10,13,0,0
9550 data 999
9999 END
run
