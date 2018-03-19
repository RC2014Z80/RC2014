import sys
from time import sleep

for line in sys.stdin:

    for ch in line:
        sys.stdout.write( ch );

    sys.stdout.write('\r\n');
    sys.stdout.flush();
    sleep(0.5);
