10 R=216 : REM 0xD8 - Register
20 D=208 : REM 0xD0 - Data
30 OUT R,7 : OUT D,62 : REM Set mixer register to enable Channel A only
40 OUT R,8 : OUT D,15 : REM Set Channel A volume to max
50 FOR N=1 TO 255
60 OUT R,0 : OUT D,N : REM Set pitch of Channel A too N
70 OUT 0,N : REM Output to Digital I/O LEDs too
80 GOSUB 100
90 NEXT N
99 OUT R,7 : OUT D,63 : REM Turn off sound
100 FOR X=1 TO 64 : NEXT X : RETURN
