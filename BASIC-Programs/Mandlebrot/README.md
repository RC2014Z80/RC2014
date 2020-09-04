Simple Mandlebrot program

Ascii version uses different characters to represent the density of the mandlebrot image.

`python ../slowprint.py > /dev/ttyUSB0 < ascii.bas`

Colour version uses escape characters to change colour to represent the density of the mandlebrot image.  Works great with the Pi Zero Terminal Module.

`python ../slowprint.py > /dev/ttyUSB0 < colour.bas`

Play around with the variables to change the appearance.

Benchmarking - MS Basic 4.7

Searle  Std 11'44"  - 100%
feilipu Std 10'46"  -  92%
feilipu APU 10'08"  -  86%
