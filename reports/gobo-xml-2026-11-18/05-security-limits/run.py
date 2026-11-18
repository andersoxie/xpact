"""Test 5: known XML attacks and extreme inputs, xpact.dll vs Expat.

Each case runs in a fresh child process (time, peak memory, crash, 60 s timeout).
"Expected" is what a safe Expat-compatible parser does; Expat's own result is shown next to it.
Generated inputs go to inputs/ (large, not for git).
Usage: python run.py [--dll path] [--tag name]
"""
import argparse
import csv
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "harness"))
from pool import Pool  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("--dll")
ap.add_argument("--tag", default="xpact")
args = ap.parse_args()
inputs = HERE / "inputs"
inputs.mkdir(exist_ok=True)
MB = 2**20


def laughs(levels=10, width=10, in_attr=False):
    d = ['<!DOCTYPE d [<!ENTITY e0 "lol">']
    for i in range(1, levels):
        d.append(f'<!ENTITY e{i} "' + f"&e{i - 1};" * width + '">')
    use = f"&e{levels - 1};"
    return "".join(d) + "]>" + (f'<d a="{use}"/>' if in_attr else f"<d>{use}</d>")


def pe_laughs(levels=10, width=10):
    d = ['<!DOCTYPE d [<!ENTITY % p0 "lol">']
    for i in range(1, levels):
        d.append(f'<!ENTITY % p{i} "' + f"%p{i - 1};" * width + '">')
    return "".join(d) + f'<!ENTITY g "%p{levels - 1};">]><d>&g;</d>'


def chain(depth):
    d = ['<!DOCTYPE d [<!ENTITY e0 "x">'] + [f'<!ENTITY e{i} "&e{i - 1};">' for i in range(1, depth)]
    return "".join(d) + f"]><d>&e{depth - 1};</d>"


CASES = [
    # id, input (str or bytes), expected, note, extra job options
    ("billion-laughs", laughs(), "REJECT", "10^9 x 'lol' in content: amplification limit", {}),
    ("billion-laughs-attr", laughs(in_attr=True), "REJECT", "same, in an attribute value", {}),
    ("billion-laughs-pe", pe_laughs(), "REJECT", "same with parameter entities in the DTD", {}),
    ("quadratic-blowup", '<!DOCTYPE d [<!ENTITY a "' + "x" * 50000 + '">]><d>' + "&a;" * 4000 + "</d>",
     "REJECT", "one 50 KB entity used 4,000 times (200 MB of text)", {}),
    ("small-amplification-ok", laughs(levels=3), "ACCEPT", "100 x 'lol': must stay allowed", {}),
    ("recursive-direct", '<!DOCTYPE d [<!ENTITY a "&a;">]><d>&a;</d>', "REJECT", "entity refers to itself", {}),
    ("recursive-indirect", '<!DOCTYPE d [<!ENTITY a "&b;"><!ENTITY b "&a;">]><d>&a;</d>', "REJECT",
     "a -> b -> a", {}),
    ("recursive-pe", '<!DOCTYPE d [<!ENTITY % a "%a;"> %a;]><d/>', "REJECT", "parameter entity refers to itself", {}),
    ("entity-chain-10k", chain(10000), "ACCEPT", "CVE-2024-8176: 10,000 nested entity references (stack depth)", {}),
    ("entity-chain-100k", chain(100000), "ACCEPT", "CVE-2024-8176: 100,000 nested entity references", {}),
    ("deep-nesting-100k", "<a>" * 100000 + "</a>" * 100000, "ACCEPT", "100,000 nested elements", {}),
    ("deep-nesting-1m", "<a>" * 1000000 + "</a>" * 1000000, "ACCEPT", "1,000,000 nested elements", {}),
    ("huge-name-10mb", "<" + "n" * (10 * MB) + "/>", "ACCEPT", "a 10 MB element name", {}),
    ("huge-attribute-50mb", '<d a="' + "v" * (50 * MB) + '"/>', "ACCEPT", "a 50 MB attribute value", {}),
    ("huge-text-100mb", "<d>" + "t" * (100 * MB) + "</d>", "ACCEPT", "100 MB of text", {}),
    ("huge-comment-50mb", "<d><!--" + "c" * (50 * MB) + "--></d>", "ACCEPT", "a 50 MB comment", {}),
    ("many-attributes-100k", "<d " + " ".join(f'a{i}="v"' for i in range(100000)) + "/>", "ACCEPT",
     "100,000 different attributes on one element", {}),
    ("duplicate-attribute-late", "<d " + " ".join(f'a{i}="v"' for i in range(1000)) + ' a0="x"/>', "REJECT",
     "1,000 attributes (under the limit), the first repeated at the end", {}),
    ("many-namespaces-50k", "<d " + " ".join(f'xmlns:p{i}="u{i}"' for i in range(50000)) + "/>", "ACCEPT",
     "50,000 namespace declarations (namespace parser)", {"namespaces": True}),
    ("big-token-small-chunks", '<d a="' + "v" * (4 * MB) + '"/>', "ACCEPT",
     "CVE-2023-52425: one 4 MB start tag fed in 4 KB chunks (must not be quadratic)", {"split": "every:4096"}),
    ("big-text-byte-chunks", "<d>" + "t" * 200000 + "</d>", "ACCEPT", "200 KB text fed byte by byte",
     {"split": "byte"}),
    ("xxe-general-no-handler", '<!DOCTYPE d [<!ENTITY x SYSTEM "file:///C:/Windows/win.ini">]><d>&x;</d>', "ACCEPT",
     "external entity without a handler: must not be read", {"external": False}),
    ("xxe-parameter-no-handler", '<!DOCTYPE d [<!ENTITY % x SYSTEM "file:///C:/Windows/win.ini"> %x;]><d/>', "ACCEPT",
     "external parameter entity without a handler: must not be read", {"external": False}),
    ("xxe-dtd-no-handler", '<!DOCTYPE d SYSTEM "file:///C:/Windows/win.ini"><d/>', "ACCEPT",
     "external DTD without a handler: must not be read", {"external": False}),
    ("ns-separator-in-uri", '<d xmlns:a="http://x|y"><a:e/></d>', "REJECT",
     "CVE-2022-25236: namespace URI contains the separator '|'", {"namespaces": True}),
    ("bad-utf8-in-name-2byte", b"<a\xc3\x28/>", "REJECT", "CVE-2022-25235: invalid 2-byte UTF-8 in a name", {}),
    ("bad-utf8-in-name-3byte", b"<a\xe2\x28\xa1/>", "REJECT", "CVE-2022-25235: invalid 3-byte UTF-8 in a name", {}),
    ("bad-utf8-in-attr", b'<a b="\xf0\x28\x8c\x28"/>', "REJECT", "invalid 4-byte UTF-8 in an attribute value", {}),
    ("nul-byte", b"<a>\x00</a>", "REJECT", "a NUL byte in text", {}),
]

rows = []
for case_id, text, expected, note, extra in CASES:
    data = text if isinstance(text, bytes) else text.encode("utf-8")
    path = inputs / f"{case_id}.xml"
    if not path.exists() or path.stat().st_size != len(data):
        path.write_bytes(data)
    row = {"id": case_id, "expected": expected, "size_mb": round(len(data) / MB, 2), "note": note}
    for engine in ("xpact", "expat"):
        with Pool(engine, timeout=60, dll=args.dll) as pool:
            r = pool.run({"file": str(path), "keep_events": False, **extra})
        row[engine] = r["verdict"]
        row[engine + "_s"] = r.get("seconds", "")
        row[engine + "_mb"] = r.get("peak_mb", "")
        row[engine + "_message"] = r.get("message") or r.get("exit_hex", "")
        if engine == "xpact" and r["verdict"] == "ACCEPT" and case_id.startswith("xxe"):
            row["xpact_events"] = r.get("event_count")
    row["status"] = ("pass" if row["xpact"] == expected else
                     "FAIL (crash/timeout)" if row["xpact"] in ("CRASH", "TIMEOUT") else "FAIL")
    rows.append(row)
    print(f"{case_id:28} expected {expected:6} xpact {row['xpact']:7} {row['xpact_s']!s:>8}s {row['xpact_mb']!s:>7}MB"
          f" | expat {row['expat']:7} {row['expat_s']!s:>8}s {row['expat_mb']!s:>7}MB | {row['status']}"
          f" {row['xpact_message']}", flush=True)

out = HERE / "logs"
out.mkdir(exist_ok=True)
fields = ["id", "status", "expected", "xpact", "xpact_s", "xpact_mb", "xpact_message", "expat", "expat_s", "expat_mb",
          "expat_message", "size_mb", "note"]
with open(out / f"security-{args.tag}.tsv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fields, delimiter="\t", extrasaction="ignore")
    w.writeheader()
    w.writerows(rows)
print(json.dumps({s: sum(r["status"] == s for r in rows) for s in {r["status"] for r in rows}}))
