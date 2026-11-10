"""Test 8: encodings and byte sequences, xpact.dll vs Expat (verdict, error code, events), whole and byte by byte.

Expected = Expat's result, except where the XML spec is explicit (column "spec").
"""
import csv
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "harness"))
from pool import Pool  # noqa: E402

DOC = '<?xml version="1.0" encoding="{enc}"?><d a="{t}">{t}<!--{t}--><?p {t}?><![CDATA[{t}]]></d>'
TEXT = "Aé€𝄞"  # 1-, 2-, 3- and 4-byte UTF-8


def utf16(enc, bom, decl="UTF-16"):
    body = DOC.format(enc=decl, t=TEXT).encode(enc)
    return (("﻿".encode(enc)) if bom else b"") + body


CASES = [
    # id, bytes, ParserCreate encoding, spec expectation ("" = follow Expat)
    ("utf8", DOC.format(enc="UTF-8", t=TEXT).encode(), None, "ACCEPT"),
    ("utf8-bom", b"\xef\xbb\xbf" + DOC.format(enc="UTF-8", t=TEXT).encode(), None, "ACCEPT"),
    ("utf8-no-decl", f'<d a="{TEXT}">{TEXT}</d>'.encode(), None, "ACCEPT"),
    ("utf16le-bom", utf16("utf-16-le", True), None, "ACCEPT"),
    ("utf16be-bom", utf16("utf-16-be", True), None, "ACCEPT"),
    ("utf16le-no-bom", utf16("utf-16-le", False), None, ""),
    ("utf16be-no-bom", utf16("utf-16-be", False), None, ""),
    ("utf16le-decl-utf16le", utf16("utf-16-le", False, "UTF-16LE"), None, ""),
    ("utf16-unpaired-high-surrogate", b"\xff\xfe" + "<d>".encode("utf-16-le") + b"\x00\xd8" + "</d>".encode("utf-16-le"), None, "REJECT"),
    ("utf16-unpaired-low-surrogate", b"\xff\xfe" + "<d>".encode("utf-16-le") + b"\x00\xdc" + "</d>".encode("utf-16-le"), None, "REJECT"),
    ("utf16-odd-length", utf16("utf-16-le", True)[:-1], None, "REJECT"),
    ("latin1", DOC.format(enc="ISO-8859-1", t="Aé\xff").encode("latin-1"), None, "ACCEPT"),
    ("us-ascii", DOC.format(enc="US-ASCII", t="Abc").encode(), None, "ACCEPT"),
    ("us-ascii-high-byte", DOC.format(enc="US-ASCII", t="Ab\xe9").encode("latin-1"), None, ""),
    # pyexpat installs a Python-codec unknown-encoding handler, so it is not plain Expat here: C Expat
    # without a handler gives XML_ERROR_UNKNOWN_ENCODING (18)
    ("windows-1252-no-handler", DOC.format(enc="windows-1252", t="Ab").encode(), None, "REJECT"),
    ("unknown-encoding", DOC.format(enc="x-nonsense", t="Ab").encode(), None, "REJECT"),
    ("create-latin1-overrides-utf8", DOC.format(enc="UTF-8", t="Aé").encode(), "ISO-8859-1", ""),
    ("create-utf8-overrides-latin1", DOC.format(enc="ISO-8859-1", t="Aé").encode("latin-1"), "UTF-8", "REJECT"),
    ("create-utf16-on-utf8", DOC.format(enc="UTF-8", t="A").encode(), "UTF-16", ""),
    ("bom-utf8-decl-utf16", b"\xef\xbb\xbf" + DOC.format(enc="UTF-16", t="A").encode(), None, ""),
]
# broken UTF-8, in each place a character can appear
BAD = {"overlong-2": b"\xc0\xaf", "overlong-3": b"\xe0\x80\xaf", "overlong-4": b"\xf0\x80\x80\xaf",
       "surrogate": b"\xed\xa0\x80", "above-10ffff": b"\xf4\x90\x80\x80", "byte-f5": b"\xf5\x80\x80\x80",
       "byte-ff": b"\xff", "lone-continuation": b"\x80", "truncated-2": b"\xc3", "truncated-3": b"\xe2\x82",
       "truncated-4": b"\xf0\x9d\x84", "fffe": "￾".encode(), "ffff": "￿".encode(),
       "c1-control-0x85": "\x85".encode(), "control-0x01": b"\x01"}
PLACES = {"text": b"<d>A%sB</d>", "attribute": b'<d a="A%sB"/>', "comment": b"<d><!--A%sB--></d>",
          "pi": b"<d><?p A%sB?></d>", "cdata": b"<d><![CDATA[A%sB]]></d>", "name": b"<dA%sB/>"}
for bad, seq in BAD.items():
    for place, frame in PLACES.items():
        spec = "ACCEPT" if bad == "c1-control-0x85" and place != "name" else "REJECT"
        CASES.append((f"utf8-{bad}-in-{place}", frame.replace(b"%s", seq), None, spec))
# boundary code points that are legal in text
for cp in (0x7F, 0x80, 0x7FF, 0x800, 0xD7FF, 0xE000, 0xFFFD, 0x10000, 0x10FFFF):
    for place in ("text", "attribute", "cdata"):
        CASES.append((f"utf8-U+{cp:04X}-in-{place}", PLACES[place].replace(b"%s", chr(cp).encode()), None, "ACCEPT"))
# character references at the edges
for ref, spec in (("&#x0;", "REJECT"), ("&#x9;", "ACCEPT"), ("&#xD7FF;", "ACCEPT"), ("&#xD800;", "REJECT"),
                  ("&#xFFFE;", "REJECT"), ("&#x10FFFF;", "ACCEPT"), ("&#x110000;", "REJECT"),
                  ("&#99999999999;", "REJECT"), ("&#x85;", "ACCEPT")):
    CASES.append((f"charref-{ref.strip('&#;')}", f"<d>{ref}</d>".encode(), None, spec))


def key(r):
    return r["verdict"], r.get("error"), r.get("events")


rows, summary = [], {}
DLL = sys.argv[1] if len(sys.argv) > 1 else None
TAG = sys.argv[2] if len(sys.argv) > 2 else "xpact"
with Pool("xpact", dll=DLL) as xp, Pool("expat") as ex:
    for cid, data, enc, spec in CASES:
        job = {"data": data.decode("latin-1"), "encoding": enc}
        xw, xb = xp.run(job), xp.run({**job, "split": "byte"})
        ew, eb = ex.run(job), ex.run({**job, "split": "byte"})
        expected = spec or ew["verdict"]
        problems = []
        if xw["verdict"] != expected:
            problems.append(f"verdict {xw['verdict']} (expected {expected})")
        if xw["verdict"] == ew["verdict"] == "REJECT" and xw["error"] != ew["error"] and not cid.startswith(("windows", "unknown")):
            problems.append(f"error {xw['error']} vs Expat {ew['error']}")
        if xw["verdict"] == ew["verdict"] == "ACCEPT" and xw["events"] != ew["events"]:
            problems.append("events differ from Expat")
        # rejected documents: events before the error depend on chunking (test 2, F02-2), compare verdict + code
        k = key if xw["verdict"] == "ACCEPT" else (lambda r: (r["verdict"], r.get("error")))
        if k(xb) != k(xw) and k(eb) == k(ew):
            problems.append(f"byte-by-byte differs ({xb['verdict']} {xb.get('message', '')})")
        status = "pass" if not problems else "FAIL"
        summary[status] = summary.get(status, 0) + 1
        rows.append({"id": cid, "status": status, "expected": expected, "spec": spec or "(Expat)",
                     "xpact": xw["verdict"], "xpact_message": xw.get("message", ""), "expat": ew["verdict"],
                     "expat_message": ew.get("message", ""), "problems": "; ".join(problems)})
        if problems:
            print(f"{cid:40} {'; '.join(problems)}  [xpact: {xw.get('message','')} | expat: {ew.get('message','')}]")
out = HERE / "logs"
out.mkdir(exist_ok=True)
with open(out / f"encodings-{TAG}.tsv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, list(rows[0]), delimiter="\t")
    w.writeheader()
    w.writerows(rows)
summary["total"] = len(rows)
print(json.dumps(summary))
