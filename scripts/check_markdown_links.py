"""Find broken relative links in the repository's Markdown files (standard library only).

  python scripts/check_markdown_links.py            # every tracked .md file
  python scripts/check_markdown_links.py docs README.md
Checks links like [text](path) and [text](path#anchor) that point inside the repository: the target file or
folder must exist. Web links (http, https, mailto) and pure #anchors are not checked.
Exit code: 0 = no broken link, 1 = at least one broken link (each printed as file:line: target).
"""
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
LINK = re.compile(r"\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
FENCE = re.compile(r"^\s*(```|~~~)")


def tracked_markdown(paths):
    args = ["git", "ls-files", "--cached", "--others", "--exclude-standard", "--", *(paths or ["."])]
    out = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, check=True).stdout
    return [ROOT / p for p in out.splitlines() if p.lower().endswith(".md")]


def broken_links(md):
    in_code = False
    for number, line in enumerate(md.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        if FENCE.match(line):
            in_code = not in_code
            continue
        if in_code:
            continue
        for target in LINK.findall(re.sub(r"`[^`]*`", "", line)):
            if re.match(r"^(https?:|mailto:|#|data:)", target):
                continue
            path = unquote(target.split("#", 1)[0])
            if path and not (md.parent / path).exists():
                yield number, target


def main():
    bad = 0
    for md in tracked_markdown(sys.argv[1:]):
        for number, target in broken_links(md):
            print(f"{md.relative_to(ROOT).as_posix()}:{number}: {target}")
            bad += 1
    print(f"broken links: {bad}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
