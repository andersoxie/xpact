"""List the not-well-formed W3C cases that expat accepts, grouped by the XML spec section the catalog names.
  python expat_lenient_cases.py DUAL_RUN_DIR EXPAT_RESULTS.tsv OUT.md"""
import csv, sys, xml.parsers.expat as expat
from collections import defaultdict
from pathlib import Path
dual, res, out = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
info = {}   # TEST ID -> (sections, description) from every catalog file of the suite
for cat in (dual / "suite" / "xmlconf").rglob("*.xml"):
    cur = {}
    def start(name, attrs):
        if name == "TEST": cur.update(id=attrs.get("ID", ""), sec=attrs.get("SECTIONS", "?"), text=[])
    def data(t):
        if cur.get("text") is not None: cur["text"].append(t)
    def end(name):
        if name == "TEST" and cur: info[cur["id"]] = (cur["sec"], " ".join("".join(cur["text"]).split())); cur.clear()
    p = expat.ParserCreate(); p.StartElementHandler, p.CharacterDataHandler, p.EndElementHandler = start, data, end
    try: p.Parse(cat.read_bytes(), True)
    except (expat.ExpatError, ValueError): pass   # test inputs in odd encodings are not catalogs
groups = defaultdict(list)
with res.open(encoding="utf-8") as f:
    for row in csv.DictReader(f, delimiter="\t"):
        st = next(v for k, v in row.items() if k.endswith("_status"))
        if st == "failed" and row["expected"] == "REJECT":
            sec, desc = info.get(row["case_id"], ("?", ""))
            groups[sec.split()[0] if sec else "?"].append((row["case_id"], desc))
lines = ["# Not-well-formed cases that expat accepts", "",
         f"{sum(map(len, groups.values()))} cases, grouped by the first XML 1.0 section the W3C catalog gives.", "",
         "| Section | Cases | Examples (catalog description) |", "|---|---:|---|"]
for sec, cases in sorted(groups.items(), key=lambda g: -len(g[1])):
    ex = "; ".join(f"`{c}`: {d[:90]}" for c, d in cases[:2])
    lines.append(f"| {sec} | {len(cases)} | {ex} |")
out.write_text("\n".join(lines) + "\n", encoding="utf-8"); print(out)