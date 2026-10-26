import re
import sys

text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
paths = {p.replace("\\\\", "\\") for p in re.findall(r"'(C:\\\\Users[^']*)'", text)}
lengths = sorted(len(p) for p in paths)
root = r"C:\Users\masou\Desktop\Lia\xpact3.0\xpact-codex-w3c-xml-conformance-benchmarks"
print("paths in errors:", len(lengths), "min", lengths[0], "max", lengths[-1],
      "over 259:", sum(1 for n in lengths if n > 259))
print("repo root:", len(root))
print("longest:", max(paths, key=len))
