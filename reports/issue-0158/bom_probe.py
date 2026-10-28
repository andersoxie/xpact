"""Byte-order marks: xpact against Expat, whole and in small chunks.

Usage: python -I reports/issue-0158/bom_probe.py [path to xpact.dll]
A leading BOM is removed; a second U+FEFF is character data (XML 1.0 4.3.3, W3C invalid-bo-4..6).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "issue-0154" / "tools" / "harness"))
import engines  # noqa: E402

BOM = "﻿"
CASES = {
    "utf-8, no BOM": "<d>x</d>".encode("utf-8"),
    "utf-8, BOM": (BOM + "<d>x</d>").encode("utf-8"),
    "utf-8, two BOMs (2nd before the root: error)": (BOM + BOM + "<d>x</d>").encode("utf-8"),
    "utf-8, BOM + U+FEFF in text": (BOM + "<d>" + BOM + "x</d>").encode("utf-8"),
    "utf-16le, BOM": (BOM + "<d>x</d>").encode("utf-16-le"),
    "utf-16be, BOM": (BOM + "<d>x</d>").encode("utf-16-be"),
    "utf-16le, two BOMs (2nd before the root: error)": (BOM + BOM + "<d>x</d>").encode("utf-16-le"),
    "utf-16be, two BOMs (2nd before the root: error)": (BOM + BOM + "<d>x</d>").encode("utf-16-be"),
    "utf-16le, BOM + U+FEFF in text": (BOM + "<d>" + BOM + "x</d>").encode("utf-16-le"),
    "utf-16be, BOM + decl": (BOM + '<?xml version="1.0" encoding="UTF-16"?><d>x</d>').encode("utf-16-be"),
}


def summary(r):
    text = "".join(e[1] for e in r["events"] if e[0] == "chars")
    return f"{r['verdict']:6} text={text!r}"


dll = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else None
bad = 0
for name, data in CASES.items():
    rows = []
    for split in (None, 1, 2, 3):
        kw = {"split": split} if split else {}
        e = summary(engines.parse("expat", data, **kw))
        x = summary(engines.parse("xpact", data, dll=dll, **kw) if dll else engines.parse("xpact", data, **kw))
        rows.append((split, e, x))
    same = all(e == x for _, e, x in rows)
    bad += not same
    print(("OK  " if same else "DIFF") + f" {name}: expat {rows[0][1]} | xpact {rows[0][2]}")
    for split, e, x in rows[1:]:
        if e != x:
            print(f"       split {split}: expat {e} | xpact {x}")
print(f"{len(CASES) - bad} of {len(CASES)} cases like Expat (whole and split at 1, 2, 3 bytes)")
