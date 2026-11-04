import re, sys, collections
t = open(sys.argv[1], encoding="utf-8", errors="replace").read()
errs = [b for b in re.split(r"\nError code: ", t)[1:] if not b.startswith("Obsolete")]
for b in errs[:10]: print("ERROR", b[:600])
rows = []
for b in t.split("Error code: Obsolete Call")[1:]:
    if "as_string_8" not in b: continue
    rows.append((int(re.search(r"\nLine: (\d+)", b).group(1)), re.search(r"\nFeature: (\S+)", b).group(1), re.search(r"\n->\s*(.*)", b).group(1).strip()))
print(len(rows), "conversions;", "System Recompiled" in t and "compiled" or "NOT compiled")
for r in sorted(rows): print(*r, sep="\t")
