  1 LET DELAY=50
        5 PRINT "Push buttons 0 - 7 to change speed"
        10 FOR F=1 TO 6
        20 OUT 0,2^F
        30 GOSUB 100
        40 NEXT F
        50 FOR F=7 TO 0 STEP -1
        60 OUT 0,2^F
        70 GOSUB 100
        80 NEXT F
        90 GOTO 10
        100 FOR Z=1 TO DELAY
        110 IF INP(0)<>0 THEN LET DELAY=SQR(INP(0))*50
        120 NEXT Z
        130 RETURN 
