## Simple Mandlebrot program

ASCII version uses different characters to represent the density of the mandlebrot image.

`python3 ../slowprint.py > /dev/ttyUSB0 < ascii.bas`

Colour version uses escape characters to change colour to represent the density of the mandlebrot image.  Works great with the Pi Zero Terminal Module.

`python3 ../slowprint.py > /dev/ttyUSB0 < colour.bas`

Play around with the variables to change the appearance.

Omitting blank space makes it run faster.

### Benchmarking

_MS Basic 4.7_

- Searle  Std       - 4.7b  11'46"  - 100%<br>
<br>
- feilipu Z80       - 4.7c  10'44"  -  91%<br>
- feilipu Z80+APU   - 4.7c  10'10"  -  86%<br>
- feilipu 8085      - 4.7c  10'55"  -  92%<br>
- feilipu 8085+APU  - 4.7c  10'18"  -  88%

_MS Basic 5.21_

- Microsoft  10'51"

_MS Basic 5.29_

- Microsoft  10'51"

_MS BASCOM 5.3a_

- Microsoft  3'40"

