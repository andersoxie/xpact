# fuzzcmp.py <expat.tsv> <baseline.tsv> <ours.tsv> [<out dir>]: compare the fuzz results (acceptance run, #67).
# Per engine: crashes/hangs; per way (whole, bytes, seven, random) the verdict, error code and event digest against
# Expat; consistency (the same verdict, code and events whole and in pieces, as Expat always gives); and the
# baseline -> ours changes, judged by Expat.
import collections, os, sys

WAYS = ["whole", "bytes", "seven", "random"]

def load(p):
    rows, crashed = {}, {}
    for l in open(p):
        f = l.rstrip('\n').split('\t')
        if len(f) < 8: continue
        n = int(f[0])
        if f[1] == 'all': crashed[n] = f"{f[2]} {f[3]}"
        else: rows[(n, f[1])] = (f[2], f[3], f[4], f[5], f[6], f[7])  # status code line col byte digest
    return rows, crashed

e, ec = load(sys.argv[1]); a, ac = load(sys.argv[2]); b, bc = load(sys.argv[3])
files = sorted({k[0] for k in e})
out = sys.argv[4] if len(sys.argv) > 4 else None
lines = []
def say(s=""): print(s); lines.append(s)

def stats(v, vc, name):
    s = collections.Counter()
    for n in files:
        if n in vc: s['crash/hang'] += 1; continue
        for w in WAYS:
            x, y = v.get((n, w)), e.get((n, w))
            if not x or not y: s['missing'] += 1; continue
            s['ways'] += 1
            s['verdict = Expat'] += x[0] == y[0]
            s['verdict+code = Expat'] += x[:2] == y[:2]
            s['+position = Expat'] += x[:5] == y[:5]
            s['events = Expat (accepted docs)'] += x[0] == y[0] == '1' and x[5] == y[5]
            s['accepted by both'] += x[0] == y[0] == '1'
        ws = [v.get((n, w)) for w in WAYS]
        if all(ws):
            s['docs'] += 1
            s['consistent verdict+code'] += len({w[:2] for w in ws}) == 1
            s['consistent events'] += len({w[5] for w in ws if w[0] == '1'}) <= 1
    return s

say(f"documents: {len(files)}; ways per document: {len(WAYS)} ({', '.join(WAYS)})")
say(f"Expat crashes/hangs: {len(ec)}")
se = collections.Counter()
for n in files:
    ws = [e.get((n, w)) for w in WAYS]
    if all(ws): se['consistent'] += len({w[:2] for w in ws}) == 1 and len({w[5] for w in ws if w[0] == '1'}) <= 1
say(f"Expat consistent whole/pieces: {se['consistent']} of {len(files)}")
sa, sb = stats(a, ac, 'baseline'), stats(b, bc, 'ours')
say("\nmeasure\tbaseline\tours")
for k in ['crash/hang', 'ways', 'verdict = Expat', 'verdict+code = Expat', '+position = Expat', 'accepted by both', 'events = Expat (accepted docs)', 'docs', 'consistent verdict+code', 'consistent events']:
    say(f"{k}\t{sa[k]}\t{sb[k]}")
say(f"\ncrash/hang files baseline: {sorted(ac)}")
say(f"crash/hang files ours: {sorted(bc)}")
# baseline -> ours changes
better = worse = same = 0; worse_list = []
for n in files:
    for w in WAYS:
        x, y, z = a.get((n, w)), b.get((n, w)), e.get((n, w))
        if not x or not y or x == y: continue
        sx = sum(p == q for p, q in zip(x, z)); sy = sum(p == q for p, q in zip(y, z))
        if sy > sx: better += 1
        elif sy < sx: worse += 1; worse_list.append((n, w, x, y, z))
        else: same += 1
say(f"\nbaseline -> ours changed results: {better + worse + same}; closer to Expat {better}, further {worse}, same distance {same}")
kinds = collections.Counter((('verdict' if x[0] != y[0] else 'code' if x[1] != y[1] else 'position' if x[2:5] != y[2:5] else 'events')) for n, w, x, y, z in worse_list)
say(f"further from Expat, by first changed field: {dict(kinds)}")
for r in worse_list[:15]: say(f"  file {r[0]} {r[1]}: baseline {r[2]} ours {r[3]} expat {r[4]}")
if out:
    os.makedirs(out, exist_ok=True)
    open(os.path.join(out, 'summary.txt'), 'w').write('\n'.join(lines) + '\n')
    with open(os.path.join(out, 'further-from-expat.tsv'), 'w') as f:
        for r in worse_list: f.write(f"{r[0]}\t{r[1]}\t{' '.join(r[2])}\t{' '.join(r[3])}\t{' '.join(r[4])}\n")
