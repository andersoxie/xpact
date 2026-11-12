"""Check relative links in tracked markdown files: report targets that do not exist in the repo."""
import re, subprocess, sys, urllib.parse
from pathlib import Path
from collections import Counter
root = Path.cwd()
files = subprocess.run(["git", "ls-files", "*.md"], capture_output=True, text=True).stdout.split()
tracked = set(subprocess.run(["git", "ls-files"], capture_output=True, text=True).stdout.split("\n"))
dirs = {str(Path(f).parent).replace("\\", "/") for f in tracked}
for f in list(dirs):
    p = Path(f)
    while str(p) not in (".", ""):
        dirs.add(str(p).replace("\\", "/")); p = p.parent
link = re.compile(r"\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
broken = []
for f in files:
    text = Path(f).read_text(encoding="utf-8", errors="replace")
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    for m in link.finditer(text):
        target = m.group(1)
        if re.match(r"^[a-z]+:|^#|^mailto:", target, re.I): continue
        path = urllib.parse.unquote(target.split("#")[0])
        if not path: continue
        resolved = (Path(f).parent / path)
        try: rel = resolved.resolve().relative_to(root.resolve()).as_posix()
        except ValueError: broken.append((f, target, "outside repo")); continue
        if rel not in tracked and rel not in dirs and rel.rstrip("/") not in dirs:
            why = "exists, not tracked" if resolved.exists() else "missing"
            broken.append((f, target, why))
by_ext = Counter(Path(b[1].split("#")[0]).suffix or "(dir)" for b in broken)
print(f"markdown files: {len(files)}, broken relative links: {len(broken)}")
print("by type:", dict(by_ext.most_common()))
by_file = Counter(b[0] for b in broken)
print("files with most broken links:"); [print(f"  {n:4d}  {f}") for f, n in by_file.most_common(15)]
out = Path(sys.argv[1]); out.write_text("\n".join(f"{a}\t{b}\t{c}" for a, b, c in broken), encoding="utf-8")
