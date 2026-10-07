#!/usr/bin/env python3
"""Convert a binary to Intel HEX for the CP/M-IDE hget command.

One step: run objcopy -I binary -O ihex, then write the records hget
stores. objcopy marks each 64 KB boundary below 1 MB with a type 02
segment record. hget advances its page only on a type 04 record, so an
8 MB image would stop at 65536 bytes. This program reads the objcopy
bytes and writes type 00 data with a type 04 record on each new page.
"""

import os
import subprocess
import sys
import tempfile

PAGE = 0x10000
MAX_BYTES = 0x100 * PAGE  # hget rejects a byte at page 0x100 (16 MB)


def die(msg):
    print("bin2hex: " + msg, file=sys.stderr)
    sys.exit(1)


def default_hex(src):
    root, ext = os.path.splitext(src)
    if ext.lower() == ".hex":
        return src + ".hex"
    return root + ".hex"


def run_objcopy(src, dst):
    try:
        subprocess.run(
            ["objcopy", "-I", "binary", "-O", "ihex", src, dst],
            check=True,
        )
    except FileNotFoundError:
        die("objcopy not found (install binutils)")
    except subprocess.CalledProcessError as err:
        die("objcopy failed (%d)" % err.returncode)


def parse_ihex(text):
    """Return (absolute address, data) pairs. Type 02 and 04 set the base."""
    base = 0
    chunks = []
    for lineno, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line:
            continue
        if line[0] != ":" or len(line) < 11 or (len(line) % 2) == 0:
            die("line %d: not an Intel HEX record" % lineno)
        try:
            rec = bytes.fromhex(line[1:])
        except ValueError:
            die("line %d: bad hex" % lineno)
        if (sum(rec) & 0xFF) != 0:
            die("line %d: checksum" % lineno)
        count = rec[0]
        addr = (rec[1] << 8) | rec[2]
        kind = rec[3]
        data = rec[4:-1]
        if len(data) != count:
            die("line %d: length" % lineno)
        if kind == 0:
            chunks.append((base + addr, data))
        elif kind == 1:
            break
        elif kind == 2:
            if count != 2:
                die("line %d: type 02 length" % lineno)
            base = ((data[0] << 8) | data[1]) << 4
        elif kind == 4:
            if count != 2:
                die("line %d: type 04 length" % lineno)
            base = ((data[0] << 8) | data[1]) << 16
        elif kind in (3, 5):
            pass
        else:
            die("line %d: record type %02d" % (lineno, kind))
    return chunks


def flatten(chunks):
    """One image that starts at address 0, with no gap and no overlap."""
    if not chunks:
        return b""
    out = bytearray()
    expect = 0
    for addr, data in chunks:
        if addr != expect:
            die("gap or overlap at 0x%X (expected 0x%X)" % (addr, expect))
        out += data
        expect = addr + len(data)
    if len(out) > MAX_BYTES:
        die("%d bytes exceeds the 16 MB hget limit" % len(out))
    return bytes(out)


def emit(data, out):
    def rec(kind, addr, payload):
        body = bytes((len(payload), (addr >> 8) & 255, addr & 255, kind)) + payload
        cks = (-sum(body)) & 255
        out.write(":" + body.hex().upper() + "%02X\n" % cks)

    page = -1
    for off in range(0, len(data), 16):
        p = off >> 16
        if p != page:
            rec(4, 0, bytes(((p >> 8) & 255, p & 255)))
            page = p
        rec(0, off & 0xFFFF, data[off:off + 16])
    rec(1, 0, b"")


def convert(src, dst):
    with tempfile.TemporaryDirectory() as td:
        tmp = os.path.join(td, "obj.hex")
        run_objcopy(src, tmp)
        with open(tmp, "r", encoding="ascii") as f:
            chunks = parse_ihex(f.read())
    data = flatten(chunks)
    tmp_out = dst + ".tmp"
    try:
        with open(tmp_out, "w", encoding="ascii", newline="\n") as f:
            emit(data, f)
        os.replace(tmp_out, dst)
    except Exception:
        if os.path.exists(tmp_out):
            os.remove(tmp_out)
        raise
    return len(data)


def main(argv):
    if len(argv) < 2 or len(argv) > 3 or argv[1] in ("-h", "--help"):
        die("usage: bin2hex.py BINARY [HEX]")
    src = argv[1]
    dst = argv[2] if len(argv) == 3 else default_hex(src)
    if not os.path.isfile(src):
        die("no such file: " + src)
    if os.path.abspath(src) == os.path.abspath(dst):
        die("refusing to overwrite the input")
    n = convert(src, dst)
    print("%d bytes -> %s" % (n, dst))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
