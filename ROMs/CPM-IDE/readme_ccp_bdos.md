# Modifications to the CCP and BDOS

Each firmware tree has its own `cpm22.asm`. The CCP and BDOS logic is the same in all seven. The block-move helpers are spelled with Z80 `LDI` on the Z80 trees and with `ld a,(hl+)` / `ld (de+),a` on the 8085 trees. The origin constant at the top of the file is the only other per-ROM difference.

The comparison below is against the Clark A. Calkins reconstruction of CP/M 2.2 (27 February 1981). That listing is the unmodified original this port was built from, and its header is still at the top of `cpm22.asm`. The version bytes stored in the image are unchanged: version 2, release 2, revision 0. The BIOS section records the FAT volume rules and the LBA hand-off.

## Origins

BDOS starts on a 256-byte page (`_cpm_bdos_head`). CCP starts `$20` below the previous page so that page stays the BDOS origin, and `ALIGN $100` places the BDOS BSS tail on the BIOS origin. `_cpm_dsk0_base` is `$F800` on every port. The BIOS code has to finish before that, so each BIOS origin is the highest page that still fits, and the CCP and BDOS origins move with it. The seven ROMs do not share one CCP or BDOS address.

| ROM | CCP | BDOS | BIOS | BIOS ends | Spare before `$F800` | Disk |
|-----|-----|------|------|-----------|---------------------:|------|
| z80-pata-sio | `$D9E0` | `$E200` | `$F100` | `$F740` | 192 | PATA 16-bit |
| z80-cf-sio | `$D9E0` | `$E200` | `$F100` | `$F6C0` | 320 | CF 8-bit |
| z80-cf-uart | `$DAE0` | `$E300` | `$F200` | `$F6C7` | 313 | CF 8-bit |
| z80-cf-acia | `$DBE0` | `$E400` | `$F300` | `$F799` | 103 | CF 8-bit |
| 8085-pata-uart | `$DAE0` | `$E300` | `$F200` | `$F7B0` | 80 | PATA 16-bit |
| 8085-cf-uart | `$DAE0` | `$E300` | `$F200` | `$F739` | 199 | CF 8-bit |
| 8085-cf-acia | `$DAE0` | `$E300` | `$F200` | `$F70F` | 241 | CF 8-bit |

Z80 CF ACIA is the short BIOS, `$499` bytes, so `$F300` ends at `$F799`. `$F400` would run through `$F899`. Z80 CF SIO uses the same `$D9E0` / `$E200` / `$F100` set as Z80 PATA SIO. Placed at `$F200`, its disk tables end 15 bytes past `$F800`. Z80 PATA SIO is `$640` bytes and from `$F200` would end at `$F840`, so that set stays at `$F100`. Z80 CF UART ends at `$F6C7`. From `$F300` the disk headers pass `$F800`, so it stays with the `$F200` builds. After the 48-byte BDOS stack, the `ALIGN` pad is 137 bytes on Z80 and 147 bytes on 8085. On 8085 PATA the spare column is 80, which leaves one byte after the parameter block.

The Calkins listing is one `ORG (MEM-7)*1024` image (CCP at `$E400` on a 64 KB machine) with its variables embedded after the code. This tree assembles the code and initialised data under `PHASE` at the addresses above, and puts the mutable cells in `SECTION bss_user`. The preamble copies the phased image into RAM. The 48-byte BDOS stack, which in the Calkins listing sits in the middle of the data pool, is at the end of that BSS. `ALIGN $100` then makes `_cpm_bdos_bss_tail` the BIOS origin. `GTNXPOS` (2 bytes) and `GTNXRUN` (1 byte) are new cells in that pool. `SAVEFCB` is the one word the search actually stores. The Calkins pool reserved two words and never read the second.

The disk parameter block is the last fixed BIOS table. The spare column is `$F800` minus `dpbase`. The four headers and the parameter block occupy the last 79 bytes of that gap, so the free bytes are 79 fewer than the column. Initialised BIOS data ends at `$FE2A` on every port. Serial rings stay at the top of RAM by their own `ALIGN` (`inc l` / `AND (size-1)` / `OR base`). SIO transmit buffers are 32 bytes.

The transient program area runs from `$0100` to the CCP origin in that table. The two SIO ROMs start the CCP at `$D9E0` and leave 55520 bytes. The other five start higher. Four mounted drives is the disk table those origins were built around. `REGISTER_SP` sits at the CCP origin so the shell stack stays below the CCP.

## CCP

The Calkins command table has six commands (`NUMCMDS = 6`): `DIR`, `ERA`, `TYPE`, `SAVE`, `REN`, `USER`. This tree adds `EXIT` (`NUMCMDS = 7`) ahead of the unknown-command path. `EXIT` prints `Exiting CP/M`, clears `_cpm_bios_canary`, toggles the ROM with `out ($38),a`, and jumps to `__Exit`, which restarts the shell. A large program may have overwritten the shell heap, so the restart initialises from the beginning.

A nameless command whose `.COM` is missing on the current drive is retried on `A:`. `UNKWN2` opens the file once. On a miss, `CHGDRV` is still zero when the user did not type a drive letter. The code sets `CHGDRV` to 1 and calls `DSELECT`, which selects drive A, then opens the file again. An explicit `d:` leaves `CHGDRV` nonzero, so that second open is skipped.

The six serial-number bytes (`PATTRN1` / `PATTRN2`) are commented out, and `UNKNOWN` no longer calls `VERIFY`. The Calkins CCP halts when those two copies disagree. The `HALT` routine is still in the file.

`MOVE3` of the three-byte `.COM` extension is three `LDI` instructions on Z80 and three `ld a,(hl+)` / `ld (de+),a` pairs on 8085.

## BDOS

### Console rubout

Function 10 (buffered console input) treats DEL (`7Fh`) as backspace. Digital Research Application Note 02 specifies that. The Calkins `RDBUF3` path echoes the deleted character and retreats one place in the buffer, which is the original rubout behaviour.

### Next directory entry

`GETNEXT` closes the current extent and opens the next one. With 4 KB blocks and `EXM = 1`, a new directory entry starts every 32 KB.

The same-entry case is the Calkins test, written out as its own branch. After the extent byte is incremented, a nonzero `(extent & EXTMASK)` means the next record still belongs to the directory entry just closed. A write leaves `CLOSEFLG` at `0FFh` because the close stored that entry, and `GETNEXT` reopens it with `OPENIT1`. A read leaves `CLOSEFLG` clear, and `FINDFST` searches that same entry from the front of the directory.

A zero mask means the next record needs a new directory entry. A close that stored the current entry leaves `CLOSEFLG` at `0FFh` and `FILEPOS` on that slot. `GTNEXT2` records the slot in `GTNXPOS` and `FINDNXT` continues at the next entry. If the name is not found by the end of the directory, `STFILPOS` wraps to entry 0 and `FINDNXT` runs again. While `GTNXRUN` is set, `FINDNXT` returns not-found when `FILEPOS` comes back to `GTNXPOS`, so the scan wraps once and does not examine the closed entry a second time. A read, or a close that did not store the entry, leaves `CLOSEFLG` clear and takes the Calkins path: `FINDFST` from entry 0. Sequential writes still resume after the extent just closed. A missing entry on a write still calls `GETEMPTY`. A missing entry on a read is still an error.

`DIR` and `OPEN` call `FINDFST`, which clears `GTNXRUN`, so those searches still start at the front.

### `DIRBUF`

`DIRBUF` is `PUBLIC`. The Calkins label is local to the BDOS. The BIOS stores the active 128-byte slice address there during a directory read, which is what lets `FCB2HL`, `CHECKSUM`, and `MOVEDIR` see the record in place. The BIOS does not call the BDOS block-move helpers.

Function 40 (write random, zero fill) clears 128 bytes at `DIRBUF` and then writes that buffer. Calkins clears a private `dirbf`. Here `DIRBUF` overlays `hstbuf`, so `flush_host` writes a dirty host sector and drops the cache before those bytes are cleared. The following unallocated write fills the new block from the zeros. A failed flush returns a disk error and leaves the cache as it was.

### Block moves

The Calkins byte loops that copy the directory buffer, the disk parameter block, and the file records are the `LDI_128`, `LDI_32`, `LDI_16`, `LDI_15`, and `LDI_8` helpers. On Z80 each step is `LDI`. On 8085 each step is `ld a,(hl+)` / `ld (de+),a`. `LDI_128` calls `LDI_32` four times.

## Directory deblocking

CP/M 2.2 always transfers 128-byte records through `SETDMA` / `READ` / `WRITE`. The host disk is 512-byte IDE/CF sectors, so the BIOS deblocks four CP/M records per host sector in `hstbuf`. File I/O (default DMA `0x80`, TPA) still copies 128 bytes between that host slice and the caller's DMA. That copy is required: the program looks at the address it passed to `SETDMA`, and a 512-byte IDE transfer cannot be aimed at a 128-byte hole in a `.COM` (or at `0x80`). Z80 builds use unrolled `LDI`; 8085 builds use `ld a,(hl+)` / `ld (de+),a`.

Directory I/O is different. BDOS snapshots DPH `DIRBUF` at `SELDSK` and then `SETDMA`s that address for every directory record. On all seven firmware builds:

- DPH `DIRBUF` overlays `hstbuf` (the separate 128-byte `dirbf` is gone: 128 bytes of BIOS RAM recovered).
- When DMA already lies in the 512-byte host window, `READ` does not copy. The BIOS writes the active 128-byte slice address into the BDOS `DIRBUF` word so `FCB2HL` / `CHECKSUM` / `MOVEDIR` see the record in place.
- Directory `WRITE` still copies the record into the slice (then `WRITE` C=1 flushes the host sector immediately).
- `DIRBUF` is `PUBLIC` so the BIOS can retarget it.

`z88dk-ticks` with stub `ide_read_sector` / `ide_write_sector` on 32 sequential directory records:

| Path | 128-byte copies | IDE 512-byte reads | T-states (I/O loop) |
|------|----------------:|-------------------:|--------------------:|
| File DMA (unchanged) | 32 | 8 | 6 334 724 |
| Directory, old copy | 32 | 8 | 6 337 091 |
| Directory, overlay | 0 | 8 | 6 271 491 |

That is 65 600 T-states saved per 32 directory records (about 2 050 T each, about 0.28 ms at 7.372 MHz), with the same number of CF/IDE reads. Open, search, rename, and other directory-heavy calls benefit. `PIP`, `MBASIC`, and `.COM` load to the TPA do not.

The recovered `dirbf` is 128 bytes, which is not a full page. The per-ROM origins are in the table above.

## BIOS

The shell reads a FAT16 or a FAT32 volume. A cluster is 32 KB or less.

A FAT16 root entry count must be a non-zero multiple of 16. A root of 2048 entries fills the 16-bit directory offset. The shell can still list that root. FAT32 must be version 0 and must have a zero root count.

`ls` stops at the last name of a full directory. A name that starts with byte `0xE5` is stored as `0x05`.

`mkdir` and `cp` free a new cluster chain when the directory update does not finish. `cp` also releases that chain when the source has walked as many clusters as the volume has. It does this before the new name is written. `mkdrv` removes and syncs the directory name before it frees a chain it cannot finish. `frag` stops if a cluster chain does not reach an end mark.

`cpm` stores the base LBA of each drive file. The BIOS adds the track and the sector for CP/M I/O. After an IDE or PPIDE command the BIOS waits for DRQ. It does not wait for ready after the data transfer. A posted write waits until the next command. Compact Flash 8-bit and PATA 16-bit do this the same way.
