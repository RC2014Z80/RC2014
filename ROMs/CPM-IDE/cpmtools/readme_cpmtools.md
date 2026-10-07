# cpmtools on the host — diskdef, and two upstream bugs

Host-side `cpmtools` reads and writes the CP/M files inside an 8 MB `.CPM` image
(see [CP/M TOOLS Usage](../README.md#cpm-tools-usage)). The host operating system copies the `.CPM`
files themselves on the FAT volume. It does not see the files stored inside an image.

This file records the `rc2014-8MB` diskdef, the two bugs found while validating it, and
the recipes to rebuild the tools.

## The diskdef

Appended to the host `/etc/cpmtools/diskdefs`. The geometry matches the 8 MB
drive images (4 KB blocks, 64 tracks × 256 sectors = 8,388,608
bytes exactly, which is the size of the images in `CPM Drives/*.CPM.zip`).

```
diskdef rc2014-8MB
  seclen 512
  tracks 64
  sectrk 256
  blocksize 4096
  maxdir 2048
  skew 0
  boottrk -
  os 2.2
end
```

`boottrk -` is **not** a typo or a placeholder. `cpmfs.c` parses it with
`d->boottrk = strtol(argv[1], 0, 0)`, and `strtol("-")` returns 0 — the intended
"non-bootable" value. The CP/M directory therefore starts at LBA 0, which is what the
real images have.

Backups kept beside it: `diskdefs.bak` (pristine, pre-edit) and `diskdefs.keep`.

## Usage

```bash
cpmcp -f rc2014-8MB SYS.CPM 0:*.* SYS/     # extract a whole image
cpmls -f rc2014-8MB SYS.CPM                # list
fsed.cpm -f rc2014-8MB a.cpm               # interactive editor
```

Verified against `CPM Drives/SYS.CPM.zip`: 44 files extract intact, and the listing is
byte-identical between the apt build and our build.

## Bug 1 — `cpmglobfree` assert (cpmtools, cosmetic)

```
$ cpmls -f rc2014-8MB SYS.CPM 'NOSUCH*'
cpmls: cpmfs.c:704: cpmglobfree: Assertion `dirent' failed.   (SIGABRT)
```

`cpmfs.c:704` is `assert(dirent);` inside `cpmglobfree()`. The mechanism:

1. `cpmglob()` (`cpmfs.c:663`) starts with `*gargv=(char**)0;` and only allocates when a
   pattern matches.
2. A pattern that matches nothing leaves `gargv == NULL` and `gargc == 0`.
3. `cpmls.c:427` calls `cpmglobfree(gargv, gargc)` → `assert(dirent)` fires on NULL.

**Trigger:** any glob or literal name that matches no file — usually a typo. Not
format-specific, and unrelated to the heap bug below.

**Severity:** cosmetic. Compiled with `NDEBUG` the loop body never runs and `free(NULL)`
is a no-op, so the whole thing disappears. A debug-assertion build should not abort on a
user typo.

**Status:** still present in upstream `lipro-cpm4l/cpmtools` master (last push
2021-05-11). No upstream issue or PR found. The `johnsonjh/cpmtools` fork carries the
one-line fix, not upstreamed:

```c
-  assert(dirent);
+  assert(dirent || entries>=0);   /* always true -> never fires */
```

Deliberately **not** applied to the installed build, so the install stays a faithful
upstream 2.23 with only the libdsk backend dropped.

## Bug 2 — heap corruption (libdsk, **not** cpmtools)

```
$ mkfs.cpm -f rc2014-8MB w.img && cpmcp -f rc2014-8MB w.img src.txt 0:HELLO.TXT
$ cpmls -f rc2014-8MB w.img
malloc(): invalid size (unsorted)   (SIGABRT)
```

Root cause is a heap buffer overflow **inside `libdsk.so`**, caught with both ASan and
valgrind on the shipped `/usr/bin/cpmls`:

```
fread (iofread.c)                WRITE of size 252416
posix_read  (libdsk.so.4)
dsk_pread   (libdsk.so.4)
dsk_lread   (libdsk.so.4)
dsk_defgetgeom (libdsk.so.4)     <- malloc(512), then overread
  at device_libdsk.c:66         <- dsk_getgeom(this->dev, &this->geom)
Address 0x4b3c510 is 0 bytes after a block of size 512
```

`device_libdsk.c:66` calls libdsk's **geometry autoprobe unconditionally at open**,
whenever a diskdef has no `libdsk:format` line. libdsk 1.5.9's "Opus Discovery"
heuristic inspects the start of the image to guess a geometry; with a `boottrk 0`
format the CP/M directory sits at LBA 0, libdsk misreads those directory bytes as
geometry hints, and overreads its own 512-byte buffer.

Isolated by bisection — with the geometry otherwise identical:

| `boottrk` | `cpmls` after `cpmcp` |
|-----------|------------------------|
| `0` / `-` | `malloc(): invalid size` abort |
| `2`       | clean |

`tracks`, `maxdir` and `sectrk` are all innocent. It is content-dependent, which is why
the real firmware images read fine and only freshly written images abort.

**Upstream status.** This is Debian bug **#1079619** ("cpmtools package produces garbage
output with cpmls") — same misfire, different symptom, because the corruption can be
silent. Debian shipped `debian/patches/cpmtools-libdsk-probe-robustness.patch` in
cpmtools **2.23-6**, and we already run 2.23-7, so the patch is present and does not
help: it hardens `Device_setGeometry`, which runs *after* the overflow. The patch header
itself says the heuristic "has been improved in libdsk 1.5.20". There is no cpmtools
version that fixes this — the fix is in libdsk, and Ubuntu ships only libdsk 1.5.9.

**Fix applied:** build cpmtools against `device_posix.c` instead of `device_libdsk.c`,
which skips the autoprobe entirely. Costs only `-T libdsk-type`, which this project never
uses. See the skill for the recipe.

## Installed state

cpmtools 2.23 built `-O2` without libdsk, in `/usr/local/bin` (precedes `/usr/bin`):

```
cpmls  cpmcp  cpmrm  cpmchattr  cpmchmod  mkfs.cpm  fsck.cpm  fsed.cpm
```

Man pages in `/usr/local/share/man/man1/`. The apt package `cpmtools` was **removed**
(`apt-get remove`, not `purge`, so the `diskdefs` conffile survived). To go back:
`apt-get install cpmtools` restores 2.23-7 with the libdsk bug.

## Gotchas worth remembering

- **`CPMTOOLSFMT` is a format *name*, not a diskdefs path.** Setting it to a filename
  yields `unknown format <path>`. The diskdefs search path is `./diskdefs` in the
  **current directory** first, then the compile-time `DISKDEFS`. Put a scratch
  `diskdefs` in a scratch cwd to test format variants.
- **`mkfs.cpm` does not pad the image to the full format size** in this build. A fresh
  image comes out at 128 KB for `rc2014-8MB`. `truncate -s 8388608` afterwards extends
  it (`truncate -s 8M` is the same length). Truncating to that length first also works,
  because this `mkfs.cpm` does not shrink a file that is already full size.
- **`cpmls` never writes.** `-i` means *print inode numbers*. The writer is `cpmcp`.
  Reading a real image and writing a new one are different code paths; do not use one as
  a smoke test for the other.
