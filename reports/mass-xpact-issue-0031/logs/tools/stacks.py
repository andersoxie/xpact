"""stacks.py <map> <F_code> <stacks.txt> [focus-substring]: inclusive % per feature; with focus, the callers of it."""
import bisect, collections, re, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
mp, fcode, smp = sys.argv[1:4]; focus = sys.argv[4] if len(sys.argv) > 4 else None
syms = []
for line in open(mp, errors="replace"):
    m = re.match(r"\s*[0-9a-f]{4}:[0-9a-f]{8}\s+(\S+)\s+([0-9a-f]{16})\s+(f?)\s*(\S*)", line)
    if m and m.group(3) == "f": syms.append((int(m.group(2), 16) - 0x180000000, m.group(1)))
syms.sort(); addrs = [s[0] for s in syms]
names = {}
for c in Path(fcode).glob("*/*.c"):
    prev = None
    for line in open(c, errors="replace"):
        if line.startswith("/* {"): prev = line[3:].strip(" */\n")
        elif prev:
            m = re.match(r"[A-Za-z0-9_ *]+?\b(F\d+_\d+)\s*\(", line)
            if m: names[m.group(1)] = prev
            prev = None
def lab(rva):
    s = syms[bisect.bisect_right(addrs, rva) - 1][1]
    m = re.match(r"(F\d+_\d+)(_\d+_\d+)?$", s)
    if m and m.group(1) in names: return names[m.group(1)] + (" (dispatch)" if m.group(2) else "")
    return s
incl = collections.Counter(); callers = collections.Counter(); n = 0
for line in open(smp):
    fr = [lab(int(x, 16)) for x in line.split()]
    if not fr: continue
    n += 1
    for f in set(fr): incl[f] += 1
    if focus:
        for i, f in enumerate(fr):
            if focus in f:
                j = i + 1
                while j < len(fr) and (focus in fr[j] or "dispatch" in fr[j]): j += 1
                callers[fr[j] if j < len(fr) else "?"] += 1
                break
print(n, "samples")
if focus:
    for k, v in callers.most_common(25): print(f"{v*100/n:5.1f}%  {k}")
else:
    for k, v in incl.most_common(60): print(f"{v*100/n:5.1f}%  {k}")
