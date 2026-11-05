# fuzzgen.py <seed list> <out dir> <count> <seed>: write <count> mutated XML documents made from the W3C seed
# files, deterministically from <seed>, plus list.txt (acceptance run, mass-xpact #67). Mutations: byte flips,
# random bytes, deletions, duplications, splices of two seeds, truncation, and inserted XML-significant fragments
# (markup openers and closers, references, invalid UTF-8, CR, NUL, deep nesting, long names and texts).
import os, random, sys

seeds = [l.strip() for l in open(sys.argv[1]) if l.strip()]
out, count, rng = sys.argv[2], int(sys.argv[3]), random.Random(int(sys.argv[4]))
os.makedirs(out, exist_ok=True)
pool = [open(p, 'rb').read() for p in seeds]
pool = [d for d in pool if 0 < len(d) <= 4096]
frags = [b'<', b'>', b'</', b'/>', b'&', b';', b'&amp;', b'&lt;', b'&#x0;', b'&#65;', b'&#xD800;', b'&e;', b'%e;', b']]>',
         b'<!--', b'-->', b'--', b'<![CDATA[', b'<?', b'?>', b'<?xml version="1.0"?>', b'<!DOCTYPE d [', b']>',
         b'<!ENTITY e "x">', b'<!ENTITY e "&e;">', b'<!ENTITY % e "x">', b'<!ATTLIST a b CDATA "c">', b'<!ELEMENT a ANY>',
         b'"', b"'", b'=', b' ', b'\t', b'\r', b'\r\n', b'\n', b'\x00', b'\xc3', b'\xc3(', b'\xe2\x82', b'\xff\xfe', b'\xef\xbb\xbf',
         b'xmlns:a="u"', b'a:b', b':', b'<a>' * 40, b'</a>' * 40, b'x' * 300, b'n' * 200 + b'=""']

def mutate(d):
    d = bytearray(d)
    for _ in range(rng.choice([1, 1, 2, 3, 5, 8])):
        op = rng.randrange(8); i = rng.randrange(len(d) + 1) if d else 0
        if op == 0 and d: d[min(i, len(d) - 1)] ^= 1 << rng.randrange(8)
        elif op == 1: d[i:i] = bytes([rng.randrange(256)])
        elif op == 2 and d: del d[i:i + rng.randrange(1, 16)]
        elif op == 3 and d: j = rng.randrange(len(d)); d[i:i] = d[j:j + rng.randrange(1, 32)]
        elif op == 4: o = rng.choice(pool); j = rng.randrange(len(o)); d[i:] = o[j:]
        elif op == 5 and d: del d[rng.randrange(len(d)):]
        else: d[i:i] = rng.choice(frags)
    return bytes(d[:8192])

with open(os.path.join(out, 'list.txt'), 'w') as lst:
    for k in range(1, count + 1):
        p = os.path.join(out, f'f{k:05d}.xml')
        open(p, 'wb').write(mutate(rng.choice(pool)))
        lst.write(os.path.abspath(p) + '\n')
print(f"{count} documents from {len(pool)} seeds in {out}")
