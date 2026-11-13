# cpkind.py <list> <expat> <baseline> <ours>: for calls where the baseline equals Expat and ours does not, what
# text starts at Expat's reported byte (the pending construct), and how far ours is ahead.
import sys, collections
names = [l.rstrip('\r\n') for l in open(sys.argv[1]) if l.strip()]
def load(p):
    d = {}
    for l in open(p):
        k, c, *v = l.rstrip('\r\n').split('\t'); d[(int(k), int(c))] = tuple(v)
    return d
e, a, b = (load(p) for p in sys.argv[2:5])
kind = collections.Counter(); files = collections.defaultdict(set); ahead = collections.Counter()
for k in a:
    if a[k] == e.get(k) and b.get(k) != e.get(k):
        data = open(names[k[0]-1], 'rb').read(); i = int(e[k][3])
        s = data[i:i+2]
        t = ('start/end tag' if s[:1] == b'<' and s[1:2] not in b'!?' else 'comment/CDATA/decl' if s == b'<!' else 'PI' if s == b'<?' else
             'reference' if s[:1] == b'&' else 'text' if s else 'end of input')
        kind[t] += 1; files[t].add(k[0]); ahead['ours ahead' if int(b[k][3]) > i else 'ours behind' if int(b[k][3]) < i else 'same byte, other line/col'] += 1
for t, n in kind.most_common(): print(f"{t}: {n} calls in {len(files[t])} files")
print(dict(ahead))
