## Simple Mandlebrot program

ASCII version uses different characters to represent the density of the mandlebrot image.

`python ../slowprint.py > /dev/ttyUSB0 < ascii.bas`

Colour version uses escape characters to change colour to represent the density of the mandlebrot image.  Works great with the Pi Zero Terminal Module.

`python ../slowprint.py > /dev/ttyUSB0 < colour.bas`

Play around with the variables to change the appearance.

Omitting blank space makes it run faster.

### Benchmarking

_MS Basic 4.7_

- Searle  Std 11'46"  - 100%<br>
- feilipu Std 10'23"  -  88%<br>
- feilipu APU  9'44"  -  83%

_MS Basic 5.21_

- Microsoft  10'51"

_MS Basic 5.29_

- Microsoft  10'51"

_MS BASCOM 5.3a_

- Microsoft  3'40"
