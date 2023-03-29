BASIC Crib Notes

colon to put multiple statements on a line, good for commenting eg :REM

logical operations AND OR NOT happen on 16 bit signed integers

conditional branching ON <expression> GOTO <list of line numbers>
or ON <expression> GOSUB <list of line number>

NEXT can terminate multiple FOR loops
NEXT without a variable identifier is faster

INPUT values separated by commas

WAIT monitors status of ports 0 to 255

PEEK and POKE address is calculated by <address - 65536> to get to higher addresses.
DEEK and DOKE works the same.

DEF will create a user defined function on one line, which might be better than a GOSUB subroutine

A string is created by adding $ to the variable name.

HEX$(nn) - convert a SIGNED integer (-32768 to +32767) to a string containing the hex value
BIN$(nn) - convert a SIGNED integer (-32768 to +32767) to a string containing the binary value
&Hnn - interpret the value after the &H as a HEX value (signed 16 bit)
&Bnn - interpret the value after the &B as a BINARY value (signed 16 bit)


Functions for a BASIC Monitor (Borrowed from NASBUG)


A – hexadecimal arithmetic

A xxxx yyyy responds with:  SSSS DDDD JJ

SSSS is sum of xxxx and yyyy. Values in hexadecimal.
DDDD is difference of xxxx and yyyy, yyyy-xxxx. Values in hexadecimal.
JJ is displacement required in a Jump Relative instruction which starts at xxxx, to cause a jump to yyyy. Value in signed integer.


C – copy

C xxxx yyyy zzzz

Copy a block of length zzzz from xxxx to yyyy. One byte is copied at a time, starting with the first byte, so if there is an overlap in the two areas data may be destroyed. This command is useful for filling a block with a single value. Make yyyy one greater than xxxx and put the required value into address xxxx. Set zzzz to the number of bytes required. Values in hexadecimal.


E – execute

E xxxx yy

Execute program at xxxx, supplying integer signed integer input parameter yy. Values in hexadecimal.


I – intelligent copy

I xxxx yyyy zzzz

Like the Copy command but starts copying at the end of the block which will not cause data corruption in an overlapping section. Values in hexadecimal.


M – modify store

M xxxx

Modify memory starting at address xxxx. The address is displayed followed by the current data. This value may be changed. Enter a “.” at the end of the line to end the command. If you enter several values then the successive address values are changed. This allows several values to be entered at once. All data is, of course, entered in hexadecimal notation. Values in hexadecimal.


T – tabulate

T xxxx yyyy

Tabulate (display) a block of memory starting at xxxx and continuing to yyyy-1. It is inadvisable to display more than 68H addresses as the top line scrolls off the screen. Values in hexadecimal.

BASIC Monitor Program Logic

Get input string, maximum of 16 characters
Tokenise it maximum of 4 tokens, separated by spaces
    ASC returns ascii code of first character in string
    MID$ returns characters from some point in string
    VAL returns numerical value of string
    LEN$ returns length of a string
Execute the routine based on the first token
Repeat

Notes made while writing the monitor.bas program.

feilipu in March 2023
