# mapstack.py <map> <ex.txt>: name each xpact frame of an exprobe stack from the link map (nearest symbol below).
import sys, re, bisect
base, syms = 0x180000000, []
for l in open(sys.argv[1], errors='replace'):
    m = re.match(r'\s*[0-9a-f]{4}:[0-9a-f]{8}\s+(\S+)\s+([0-9a-f]{16})\s', l)
    if m: syms.append((int(m.group(2), 16), m.group(1)))
    m = re.search(r'Preferred load address is ([0-9a-f]+)', l)
    if m: base = int(m.group(1), 16)
syms.sort(); keys = [s[0] for s in syms]
for l in open(sys.argv[2]):
    m = re.match(r'\s+xpact[^+]*\+([0-9a-f]+)', l)
    if m:
        a = base + int(m.group(1), 16); i = bisect.bisect_right(keys, a) - 1
        print(f"  {l.strip():34} {syms[i][1]}+{a - syms[i][0]:x}")
    else: print(l.rstrip())
