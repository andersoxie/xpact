"""Old vs new xpact.dll through benchmarks/fair_speed/fair_speed.exe: did #273 (rescue guards) and #274
(call lock) cost speed? 5 alternating rounds per case, median; checksums must match.
usage: python -I old_vs_new.py <fair_speed.exe> <inputs dir> <old xpact.dll> <new xpact.dll>"""
import statistics, subprocess, sys
from pathlib import Path
exe, inputs, old, new = sys.argv[1], Path(sys.argv[2]), sys.argv[3], sys.argv[4]
cases = [("elements-1MB-utf8.xml", c) for c in (0, 4096, 16, 1)] + [("text-1MB-utf8.xml", c) for c in (0, 16, 1)] + \
        [("attributes-1MB-utf8.xml", 0), ("dtd-1MB-utf8.xml", 0), ("namespaces-1MB-utf8.xml", 0), ("elements-10KB-utf8.xml", 0)]
def run(dll, f, chunk, it):
    p = subprocess.run([exe, dll, str(inputs / f), str(chunk), "1", "1" if f.startswith("namespaces") else "0", str(it)],
                       capture_output=True, text=True, timeout=900).stdout.split()
    return float(p[2]), p[3], p[0]
print("| Document | Piece | old ms | new ms | new/old | checksums |"); print("|---|---:|---:|---:|---:|---|")
for f, chunk in cases:
    single = run(old, f, chunk, 1)[0] / 1000
    it = max(1, round(0.25 / max(single, 1e-6)))
    t = {"old": [], "new": []}; sums = set()
    for k in range(5):
        for name in (["old", "new"] if k % 2 == 0 else ["new", "old"]):
            ms, cs, st = run(old if name == "old" else new, f, chunk, it); t[name].append(ms); sums.add((cs, st))
    o, n = statistics.median(t["old"]), statistics.median(t["new"])
    print(f"| {f} | {chunk or 'whole'} | {o:.3f} | {n:.3f} | {n / o:.2f} | {'same' if len(sums) == 1 else 'DIFFER ' + str(sums)} |", flush=True)
