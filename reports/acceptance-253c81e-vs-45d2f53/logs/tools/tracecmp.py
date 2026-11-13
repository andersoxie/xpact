# tracecmp.py <expat> <baseline> <ours>: per file, which sections changed baseline -> ours, and for those,
# whether the final status/error and the whole event list equal Expat's before and after.
import sys, re
def secs(p):
    d = {}; cur = None
    for line in open(p, encoding='utf-8', errors='replace'):
        line = line.rstrip('\r\n')
        if line.startswith('== '): cur = re.sub(r'.*xmlconf.', '', line[3:]); d[cur] = []
        elif cur is not None: d[cur].append(line)
    return d
def end(s): return [re.sub(r'^END@[^ ]* ', '', l) for l in s if l.startswith('END@')]
ex, a, b = secs(sys.argv[1]), secs(sys.argv[2]), secs(sys.argv[3])
ch = sorted(n for n in b if a.get(n) != b.get(n))
print(f"{len(b)} files, {len(ch)} changed; end = Expat: before {sum(end(a.get(n, ["MISSING"]))==end(ex.get(n, [])) for n in ch)}, after {sum(end(b[n])==end(ex.get(n, [])) for n in ch)}; "
      f"events = Expat: before {sum(a.get(n, ["MISSING"])==ex.get(n, []) for n in ch)}, after {sum(b[n]==ex.get(n, []) for n in ch)}")
for n in ch: print("   ", n, "| end before", end(a.get(n, ["MISSING"])), "after", end(b[n]), "Expat", end(ex.get(n, [])))
