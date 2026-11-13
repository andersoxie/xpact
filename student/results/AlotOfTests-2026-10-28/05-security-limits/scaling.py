"""Test 5c: does xpact's time grow linearly when a document is streamed in 64 KB chunks?"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "harness"))
from pool import Pool  # noqa: E402

KB = 1024
shapes = {"text": lambda n: "<d>" + "t" * n + "</d>",
          "small-elements": lambda n: "<d>" + "<e>x</e>" * (n // 8) + "</d>"}
print("shape            size     mode          xpact s   expat s")
for shape, make in shapes.items():
    for n in (128 * KB, 256 * KB, 512 * KB, 1024 * KB, 2048 * KB):
        data = make(n)
        for mode in (None, "every:65536"):
            res = []
            for eng in ("xpact", "expat"):
                with Pool(eng, timeout=180) as p:
                    r = p.run({"data": data, "split": mode, "keep_events": False})
                res.append(f"{r.get('seconds', r['verdict'])!s:>8}")
            print(f"{shape:15} {n // KB:5} KB  {mode or 'whole':12} {res[0]}  {res[1]}", flush=True)
