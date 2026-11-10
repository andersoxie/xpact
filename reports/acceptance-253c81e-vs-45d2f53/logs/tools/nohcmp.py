# nohcmp.py <expat> <baseline> <ours>: agreement with Expat per field, for both versions, and baseline -> ours changes.
import sys, re
def rows(p):
    d = {}
    for l in open(p, encoding='utf-8', errors='replace'):
        f = l.rstrip('\n').split('\t'); d[f[0]] = f[1:]
    return d
ex, a, b = (rows(p) for p in sys.argv[1:4])
def agree(v, idx): return sum(all(v[n][i] == ex[n][i] for i in idx) for n in ex)
fields = [("verdict", [0]), ("verdict+code", [0, 1]), ("+line+column", [0, 1, 2, 3]), ("+byte index", [0, 1, 2, 3, 4]), ("all incl. per-call positions", [0, 1, 2, 3, 4, 5])]
print("field\tbaseline\tours\t(of %d)" % len(ex))
for name, idx in fields: print(f"{name}\t{agree(a, idx)}\t{agree(b, idx)}")
ch = [n for n in ex if a[n] != b[n]]
better = sum(sum(x == y for x, y in zip(b[n], ex[n])) > sum(x == y for x, y in zip(a[n], ex[n])) for n in ch)
worse = [n for n in ch if sum(x == y for x, y in zip(b[n], ex[n])) < sum(x == y for x, y in zip(a[n], ex[n]))]
print(f"changed baseline->ours: {len(ch)}; closer to Expat: {better}; further from Expat: {len(worse)}; same distance: {len(ch)-better-len(worse)}")
for n in worse: print("  FURTHER:", n, "base", a[n], "ours", b[n], "expat", ex[n])
if len(sys.argv) > 4:
    for n in ch: print("  changed:", n, "base", a[n], "ours", b[n], "expat", ex[n], file=open(sys.argv[4], 'a'))
