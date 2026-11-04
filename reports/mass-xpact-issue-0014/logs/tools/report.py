"""Map sampled RVAs to Eiffel features: python -I report.py <xpact.map> <F_code dir> <samples.txt> [top]

The map file comes from relinking the DLL with -MAP (see build.ps1); the generated C in F_code
has a "/* {CLASS}.feature */" comment before each finalized routine F<n>_<m>."""
import bisect
import collections
import re
import sys
from pathlib import Path

mp, fcode, smp = sys.argv[1:4]
top = int(sys.argv[4]) if len(sys.argv) > 4 else 40
syms = []
for line in open(mp, errors="replace"):
    m = re.match(r"\s*[0-9a-f]{4}:[0-9a-f]{8}\s+(\S+)\s+([0-9a-f]{16})\s+(f?)\s*(\S*)", line)
    if m and m.group(3) == "f":
        syms.append((int(m.group(2), 16) - 0x180000000, m.group(1), m.group(4)))
syms.sort()
addrs = [s[0] for s in syms]
names = {}
for c in Path(fcode).glob("*/*.c"):
    prev = None
    for line in open(c, errors="replace"):
        if line.startswith("/* {"):
            prev = line[3:].strip(" */\n")
        elif prev:
            m = re.match(r"[A-Za-z0-9_ *]+?\b(F\d+_\d+)\s*\(", line)
            if m:
                names[m.group(1)] = prev
            prev = None


def label(sym, obj):
    if sym in names:
        return names[sym]
    m = re.match(r"(F\d+_\d+)_\d+_\d+$", sym)  # polymorphic dispatch wrapper of F<n>_<m>
    if m and m.group(1) in names:
        return names[m.group(1)] + " (dispatch)"
    return f"{sym}  [{obj}]"


cnt = collections.Counter()
for line in open(smp):
    rva = int(line, 16)
    i = bisect.bisect_right(addrs, rva) - 1
    if rva > 0x10000000 or i < 0:
        cnt["<outside xpact.dll>"] += 1
        continue
    cnt[label(syms[i][1], syms[i][2])] += 1
tot = sum(cnt.values())
print(f"{tot} samples")
for k, v in cnt.most_common(top):
    print(f"{v * 100 / tot:5.1f}% {v:6d}  {k}")
