Handy subroutines to send escape characters for setting Row & Col or Colours

Let ink = 1      (number from 0 to 255.  Basic colours are 0 to 16)
Gosub 1000

Let paper = 1      (number from 0 to 255.  Basic colours are 0 to 16)
Gosub 1050

Let row = 1
Let col = 1
Gosub 1100

Let xo = 10
Let xi = 10
Let y0 = 20
let yi = 20
Gosub 2000

Gosub 3000   (Resets to default)
