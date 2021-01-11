10 REM ************************************
20 REM *                                  *
30 REM * Prime number generator           *
40 REM * Sieve of Eratosthenes            *
50 REM * Tim Holyoake, 28th December 2020 *
60 REM *                                  *
70 REM * For RC2014 8K BASIC 4.7          *
80 REM *                                  *
90 REM ************************************
100 CLS
110 PRINT "Enter prime number limit"
120 INPUT L
130 IF (L < 2) THEN GOTO 1000
140 DIM A(L)
150 A(1)=0
160 FOR N=2 TO L
170 REM *** SET NUMBERS 2 TO L AS POSSIBLE PRIME
180 A(N)=1
190 NEXT N
200 REM *** IMPLEMENT SIEVE
210 FOR I= 2 TO SQR(L)
220 IF A(I)=1 THEN GOTO 240
230 GOTO 400
240 PRINT "Removing multiples of ";I
250 REM *** REMOVE MULTIPLES
260 C=0
270 J=I
280 J=(I*I)+(C*I)
290 IF J>L THEN GOTO 400
300 A(J)=0
310 C=C+1
320 GOTO 280
400 NEXT I
500 REM *** PRINT RESULTS
510 FOR K=1 TO L
520 IF A(K)=0 THEN PRINT ".";
530 IF A(K)=1 THEN PRINT K;
540 NEXT K
1000 END
