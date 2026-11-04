"""region.py <minidump> <hex address>: the dump memory range holding the address, and nearby ranges."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dumpmem_lib as d
data = open(sys.argv[1], "rb").read(); a = int(sys.argv[2], 16)
rs = sorted((s, l) for s, l, o in d.ranges(data))
for s, l in rs:
    if s <= a < s + l or abs(s - a) < 0x2000000:
        print("%016x +%08x%s" % (s, l, "  <== offset %x" % (a - s) if s <= a < s + l else ""))
