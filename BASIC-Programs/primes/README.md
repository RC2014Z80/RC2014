## primes

RC2014 BASIC - Sieve of Eratosthenes prime number generator

The 32K RAM RC2014 Classic ][ has enough memory to generate the prime numbers between 2 and 7,842 using this algorithm.

Original repository by Tim Holyoake [`@psychotimmy`](https://github.com/psychotimmy/primes)

`python ../slowprint.py > /dev/ttyUSB0 < primes.bas`

Omitting blank space makes it run faster.

### Benchmarking

Finding first 7,500 primes

_MS Basic 4.7_

- Searle  4.7b  1'57"  - 100%<br>
- feilipu 4.7c  1'48"  -  92%<br>

_MS Basic 5.29_

- Microsoft     2'08"

_MS BASCOM 5.3a_

- Microsoft  
