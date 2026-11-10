"""Write a manifest.tsv (the shared-fixtures format) for every file in a folder (mass-xpact #81, #83).

Usage, from the repository root:
  python -I student/results/shared-fixtures/manifest_from_folder.py <folder> <set name> <source text> [--glob *.xml]
The manifest is written next to the folder (its parent). Expat 2.8.1 is the reference: no expected column.
Then: compare.py --manifest <that manifest.tsv> ...
"""
import argparse
import csv
import hashlib
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder", type=Path)
    ap.add_argument("set_name")
    ap.add_argument("source")
    ap.add_argument("--glob", default="*")
    ap.add_argument("--out", type=Path, help="manifest path (default: next to the folder)")
    args = ap.parse_args()
    folder = args.folder.resolve()
    rows = []
    for p in sorted(q for q in folder.rglob(args.glob) if q.is_file() and q.name != "LICENSE"):
        data = p.read_bytes()
        rows.append({"id": f"{args.set_name}/{p.relative_to(folder).as_posix()}", "set": args.set_name,
                     "path": p.relative_to(REPO).as_posix(), "sha256": hashlib.sha256(data).hexdigest(),
                     "bytes": len(data), "expected": "", "namespaces": "off",
                     "entity_root": p.parent.relative_to(REPO).as_posix(), "source": args.source, "finding": ""})
    target = args.out.resolve() if args.out else folder.parent / "manifest.tsv"
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, list(rows[0]), delimiter="\t")
        w.writeheader()
        w.writerows(rows)
    print(len(rows), "fixtures in", target.relative_to(REPO).as_posix())


if __name__ == "__main__":
    main()
