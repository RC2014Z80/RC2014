import sys
from time import sleep

for line in sys.stdin:

    for ch in line:
        sys.stdout.write( ch );
        sleep(0.01);
    sys.stdout.write('\n');
    sys.stdout.flush();
    sleep(0.1);
