Handy subroutines to send escape characters for setting Row & Col or Colours

Let ink = 1      (number from 0 to 255.  Basic colours are 0 to 16)
Gosub 1000

Let paper = 1      (number from 0 to 255.  Basic colours are 0 to 16)
Gosub 1050

Let row = 1
Let col = 1
Gosub 1100

Gosub 3000   (Resets to default)

Gosub 4000    (Clears the screen)

Gosub 5000    (Hide cursor)

Gosub 6000    (Show cursor)
