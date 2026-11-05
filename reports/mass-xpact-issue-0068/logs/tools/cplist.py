# cplist.py <list> <expat> <base> <ours>: every call where the baseline equals Expat and ours does not.
import sys
names = [l.rstrip('\r\n') for l in open(sys.argv[1]) if l.strip()]
def load(p):
    d = {}
    for l in open(p):
        k, c, *v = l.rstrip('\r\n').split('\t'); d[(int(k), int(c))] = tuple(v)
    return d
e, a, b = (load(p) for p in sys.argv[2:5])
for k in sorted(a):
    if a[k] == e.get(k) and b.get(k) != e.get(k):
        data = open(names[k[0]-1], 'rb').read(); i = int(e[k][3]); j = int(b[k][3])
        print(names[k[0]-1][-40:], "call", k[1], "expat", e[k], "ours", b[k], "| from ours:", repr(data[j:i+4]))
