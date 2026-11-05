# cpcmp.py <expat> <baseline> <ours>: per-call positions; count calls equal to Expat (status+line+col+byte), and
# calls where baseline and ours differ, split into ours-matches-Expat / baseline-matches-Expat / neither.
import sys, collections
def load(p):
    d = {}
    for l in open(p):
        k, c, *v = l.rstrip('\r\n').split('\t'); d[(int(k), int(c))] = tuple(v)
    return d
e, a, b = (load(p) for p in sys.argv[1:4])
keys = sorted(set(a) | set(b))
eq = lambda x, k: x.get(k) == e.get(k)
diff = [k for k in keys if a.get(k) != b.get(k)]
print(f"calls {len(keys)}: equal to Expat baseline {sum(eq(a,k) for k in keys)}, ours {sum(eq(b,k) for k in keys)}")
print(f"calls changed {len(diff)}: ours = Expat {sum(eq(b,k) and not eq(a,k) for k in diff)}, baseline = Expat {sum(eq(a,k) and not eq(b,k) for k in diff)}, neither {sum(not eq(a,k) and not eq(b,k) for k in diff)}")
kinds = collections.Counter()
for k in diff:
    x, y, z = a.get(k), b.get(k), e.get(k)
    kinds[("status" if x[0] != y[0] else "") + ("line/col" if x[1:3] != y[1:3] else "") + ("byte" if x[3] != y[3] else "")] += 1
print("what changed:", dict(kinds))
for k in diff[:6]: print("  ", k, "base", a.get(k), "ours", b.get(k), "expat", e.get(k))
