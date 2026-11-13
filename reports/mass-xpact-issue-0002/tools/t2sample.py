"""Time Test 2 jobs per engine on a sample of W3C cases. Usage: t2sample.py <repo> <every-nth> <dll>..."""
import sys, time
from pathlib import Path
repo = Path(sys.argv[1]); nth = int(sys.argv[2]); dlls = sys.argv[3:]
sys.path.insert(0, str(repo / "reports" / "issue-0154" / "tools" / "harness"))
from pool import Pool
import w3c
cases = [c for i, (c, a) in enumerate(w3c.cases()) if i % nth == 0 and c.path.is_file()]
print(len(cases), "cases")
def job(c):
    return {"file": str(c.path), "entity_root": str(w3c.SUITE), "namespaces": c.namespaces, "compare_splits": 4096}
for name, kw in [("expat", {})] + [("xpact", {"dll": d}) for d in dlls]:
    with Pool(name, timeout=300, **kw) as p:
        t = time.perf_counter(); res = [p.run(job(c)) for c in cases]
        print(f"{name} {kw.get('dll','')}: {time.perf_counter() - t:.1f}s")
