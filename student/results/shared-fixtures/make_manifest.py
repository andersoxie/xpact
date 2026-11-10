"""Write manifest.tsv: every shared fixture set with its source, path, SHA-256 and expectation (mass-xpact #81).

Sets:
  G01-w3c               the 93 G01 cases (student/results/G01-corpus/manifest.tsv), in xmlconf/
  C03-chunks, C10-utf8  the byte-exact fixtures of the C# DLL comparison (#121)
  ext-entities-64       the 20 W3C files that failed with code 21 without a handler (#64)
  positions-68          eduni/errata-2e/E36.xml, the #68 example
  billion-laughs-60     laughs-3..8 (andersoxie#211) and the #60 threshold documents
  skipped-entity-69     the 3 documents of the #69 skipped-entity check
  fuzz-crash-72         the 7 fuzzed documents that ended the assertions DLL, and their shrunk forms
  fuzz-piece-dependent-74  the 63 fuzzed documents whose error code depended on the pieces
Usage, from the repository root: python -I student/results/shared-fixtures/make_manifest.py
"""
import csv
import hashlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
XMLCONF = REPO / "xmlconf"
EXT_64 = """eduni/errata-2e/E18.xml eduni/errata-2e/E60.xml eduni/xml-1.1/002.xml ibm/invalid/P68/ibm68i03.xml
ibm/invalid/P68/ibm68i04.xml ibm/invalid/P69/ibm69i03.xml ibm/invalid/P69/ibm69i04.xml ibm/not-wf/P77/ibm77n03.xml
ibm/not-wf/P77/ibm77n04.xml ibm/not-wf/P79/ibm79n01.xml ibm/not-wf/P79/ibm79n02.xml ibm/valid/P68/ibm68v02.xml
ibm/valid/P69/ibm69v02.xml ibm/valid/P70/ibm70v01.xml ibm/valid/P79/ibm79v01.xml sun/not-wf/decl01.xml
xmltest/valid/not-sa/011.xml xmltest/valid/not-sa/012.xml xmltest/valid/not-sa/026.xml xmltest/valid/sa/097.xml""".split()
LAUGHS_EXPECTED = {"laughs-3": "ACCEPT", "laughs-4": "ACCEPT", "laughs-5": "ACCEPT", "laughs-6": "REJECT",
                   "laughs-8": "REJECT", "big-low-factor": "ACCEPT", "under-threshold": "ACCEPT",
                   "over-threshold": "REJECT"}


def row(set_name, ident, path, source, finding, expected="", namespaces="off", entity_root=None):
    data = path.read_bytes()
    root = entity_root or path.parent
    return {"id": f"{set_name}/{ident}", "set": set_name, "path": path.relative_to(REPO).as_posix(),
            "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data), "expected": expected,
            "namespaces": namespaces, "entity_root": root.relative_to(REPO).as_posix(), "source": source,
            "finding": finding}


def main():
    rows = []
    with (REPO / "student/results/G01-corpus/manifest.tsv").open(encoding="utf-8") as f:
        for g in csv.DictReader(f, delimiter="\t"):
            rows.append(row("G01-w3c", g["id"], XMLCONF / g["path"], "W3C suite 2013-09-23 (G01, andersoxie#118)",
                            "", g["expected"] if g["counted"] == "yes" else "",
                            "on" if g["namespace"] == "yes" else "off", XMLCONF))
    for set_name, folder, finding in (("C03-chunks", "C03-chunks", "andersoxie#124, #126"),
                                      ("C10-utf8", "C10-utf8", "andersoxie#122, #123")):
        for p in sorted((REPO / "student/results" / folder / "fixtures").glob("*.xml")):
            rows.append(row(set_name, p.stem, p, f"student/results/{folder} (andersoxie#121)", finding))
    for rel in EXT_64:
        rows.append(row("ext-entities-64", rel, XMLCONF / rel, "W3C suite 2013-09-23", "mass-xpact#64",
                        entity_root=XMLCONF))
    rows.append(row("positions-68", "E36", XMLCONF / "eduni/errata-2e/E36.xml", "W3C suite 2013-09-23",
                    "mass-xpact#68", entity_root=XMLCONF))
    for set_name, finding, source in (("billion-laughs-60", "mass-xpact#60", "reports/issue-0211, reports/mass-xpact-issue-0060"),
                                      ("skipped-entity-69", "mass-xpact#69", "reports/mass-xpact-issue-0069"),
                                      ("fuzz-crash-72", "mass-xpact#72", "fuzzgen.py seed 67; shrink.py"),
                                      ("fuzz-piece-dependent-74", "mass-xpact#74", "fuzzgen.py seed 67")):
        for p in sorted((HERE / "fixtures" / set_name).glob("*.xml")):
            rows.append(row(set_name, p.stem, p, source, finding, LAUGHS_EXPECTED.get(p.stem, "")))
    with (HERE / "manifest.tsv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, list(rows[0]), delimiter="\t")
        w.writeheader()
        w.writerows(rows)
    counts = {}
    for r in rows:
        counts[r["set"]] = counts.get(r["set"], 0) + 1
    print(len(rows), "fixtures:", ", ".join(f"{k} {v}" for k, v in counts.items()))


if __name__ == "__main__":
    main()
