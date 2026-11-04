"""dumpmem.py <minidump> <hex address> [<bytes>]: print memory from a minidump's Memory64List (mass-xpact #20)."""
import struct
import sys


def ranges(data):
    sig, ver, nstreams, rva = struct.unpack_from("<IIII", data, 0)
    for i in range(nstreams):
        stype, size, srva = struct.unpack_from("<III", data, rva + 12 * i)
        if stype == 9:  # Memory64ListStream
            count, base_rva = struct.unpack_from("<QQ", data, srva)
            off = base_rva
            for j in range(count):
                start, length = struct.unpack_from("<QQ", data, srva + 16 + 16 * j)
                yield start, length, off
                off += length
        elif stype == 5:  # MemoryListStream
            count, = struct.unpack_from("<I", data, srva)
            for j in range(count):
                start, length, off = struct.unpack_from("<QII", data, srva + 4 + 16 * j)
                yield start, length, off


def read(data, address, n):
    for start, length, off in ranges(data):
        if start <= address < start + length:
            k = min(n, start + length - address)
            return data[off + address - start: off + address - start + k]
    return None


def main():
    data = open(sys.argv[1], "rb").read()
    address = int(sys.argv[2], 16)
    n = int(sys.argv[3]) if len(sys.argv) > 3 else 128
    b = read(data, address, n)
    if b is None:
        print("address not in dump")
        return
    for i in range(0, len(b), 16):
        row = b[i:i + 16]
        qs = " ".join("%016x" % struct.unpack_from("<Q", row, k)[0] for k in range(0, len(row) - 7, 8))
        print("%016x  %s  %s" % (address + i, row.hex(" "), qs))


main()
