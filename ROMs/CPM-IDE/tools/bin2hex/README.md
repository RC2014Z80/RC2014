# bin2hex

`bin2hex.py` turns a normal file into Intel HEX for the CP/M-IDE shell command `hget`. One command is the whole conversion. It runs `objcopy -I binary -O ihex` and writes a `.hex` file `hget` can store, including an 8 MB `.CPM` drive.

GNU binutils is required (`objcopy`).

## Usage

From this directory:

```bash
python3 bin2hex.py drive.cpm
python3 bin2hex.py drive.cpm /tmp/drive.hex
python3 bin2hex.py prog.com
```

From the repository root:

```bash
python3 tools/bin2hex/bin2hex.py drive.cpm
```

With one argument the hex file is written beside the input and the suffix becomes `.hex` (`drive.cpm` becomes `drive.hex`, `prog.com` becomes `prog.hex`). A second argument is the output path. The script will not overwrite the input file.

It prints the byte count and the output path. `objcopy` is invoked as:

```text
objcopy -I binary -O ihex BINARY TEMP.hex
```

## Records hget accepts

`objcopy` writes a type `02` segment record at each 64 KB boundary below 1 MB, then switches to type `04` above 1 MB. `hget` keeps a 64 KB page and advances that page only when it reads a type `04` record. A type `02` line leaves the page unchanged, so the next data record fails and the transfer stops at 65536 bytes with `FR_DISK_ERR`.

`bin2hex.py` reads the `objcopy` image, checks that the bytes are one contiguous run from address 0, and writes:

- a type `04` record at the start of each 64 KB page
- type `00` data records, 16 bytes each, in order from address 0
- a type `01` record to end the file

A file larger than 16 MB is rejected. That is the size `hget` accepts (`hg_page` stops at `0x100`).

## On the RC2014

Open the serial link at 115200 baud 8n2 and turn on hardware flow control, so the receive ring can pause the host while a sector is written. On the shell:

```text
hget DRIVE.CPM
```

The shell prints `Waiting for Intel HEX`. Send the hex file with `ascii-xfr -s` (in minicom, Ctrl-A S, then the ascii protocol). Leave `-e` off. The type `01` record finishes the receive, and a trailing Ctrl-Z would be left for the shell. Success prints the original length (`8388608 bytes` for a full CP/M drive). A bad line prints `bad hex`. The name stored on the card is the `hget` argument, in 8.3 form. The same steps work for any other binary.

`frag DRIVE.CPM` prints clusters, runs, and bytes:

```text
16384 cluster(s), 1 run(s), 8388608 bytes
```

`cpm` mounts a file only when `frag` reports one run.

When `frag` reports more than one run, copy the file to a new name. `cp` allocates a new cluster chain, starting at the next free cluster and then taking the following free clusters. That often lands as a single run:

```text
cp DRIVE.CPM DRIVE2.CPM
frag DRIVE2.CPM
```

When the copy is one run, `rm DRIVE.CPM` removes the fragmented original. `mv DRIVE2.CPM DRIVE.CPM` puts the name back. A rename in the same directory keeps the new chain. `mv` of the fragmented file does not allocate clusters, so the runs stay split.
