"""Test 11: large realistic files, xpact.dll vs Expat.

Four shapes like real data, each at 1, 5, 9 and 20 MB (generated into inputs/, not for git):
  records    OpenStreetMap-like: many small elements with many attributes
  text       Wikipedia-like: long mixed text with markup, entities and CDATA
  ns         Atom/SOAP-like: namespaces on every element
  nested     configuration-like: deeper nesting (up to 40 levels), short text
Per file: whole document and 64 KB chunks (the usual streaming); with handlers (event hash
compared with Expat) and bare (no handlers: the parser alone). Each run in a fresh process.
Usage: python run.py [--dll path] [--tag xpact] [--sizes 1,5,9,20]
"""
import argparse
import csv
import random
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "harness"))
from pool import Pool  # noqa: E402

MB = 2**20


def records(r, n):
    out = ['<?xml version="1.0" encoding="UTF-8"?>\n<osm version="0.6" generator="test">\n']
    size, i = 0, 0
    while size < n:
        tags = "".join(f'<tag k="{k}" v="{r.choice(["yes", "Café Ünïcode", "a&amp;b", "residential"])}"/>'
                       for k in r.sample(["name", "highway", "amenity", "building", "surface", "lit"], r.randint(0, 3)))
        s = (f'  <node id="{i}" lat="{r.uniform(-90, 90):.7f}" lon="{r.uniform(-180, 180):.7f}" version="{r.randint(1, 9)}"'
             f' timestamp="2026-10-28T12:00:00Z" user="u{r.randint(1, 999)}" uid="{r.randint(1, 99999)}">{tags}</node>\n')
        out.append(s)
        size += len(s)
        i += 1
    out.append("</osm>\n")
    return "".join(out)


def text(r, n):
    words = ["the", "parser", "reads", "XML", "Ünïcode", "€", "&amp;", "&lt;tag&gt;", "data", "&#169;", "streams", "名前"]
    out = ['<?xml version="1.0"?>\n<!DOCTYPE wiki [<!ENTITY site "Example Wiki">]>\n<wiki>\n']
    size, i = 0, 0
    while size < n:
        para = " ".join(r.choice(words) for _ in range(r.randint(40, 200)))
        s = (f'<page id="{i}"><title>Page {i} on &site;</title><text xml:space="preserve">{para} <b>bold</b> '
             f"<i>{' '.join(para.split()[:8])}</i>\n<![CDATA[raw <code> & stuff]]>\n</text><!-- rev {i} --></page>\n")
        out.append(s)
        size += len(s)
        i += 1
    out.append("</wiki>\n")
    return "".join(out)


def ns(r, n):
    out = ['<?xml version="1.0"?>\n<feed xmlns="http://www.w3.org/2005/Atom" xmlns:dc="http://purl.org/dc/elements/1.1/"'
           ' xmlns:x="urn:x">\n']
    size, i = 0, 0
    while size < n:
        s = (f'<entry x:n="{i}"><id>urn:uuid:{i:08x}</id><title type="text">Entry {i}</title><dc:creator>A{i % 97}'
             f'</dc:creator><x:ext xmlns:y="urn:y{i % 5}"><y:v y:a="{i}">{i}</y:v></x:ext></entry>\n')
        out.append(s)
        size += len(s)
        i += 1
    out.append("</feed>\n")
    return "".join(out)


def nested(r, n):
    out = ["<config>"]
    size, i = 0, 0
    while size < n:
        depth = r.randint(5, 40)
        s = "".join(f'<level{d} n="{d}">' for d in range(depth)) + f"value {i}" + \
            "".join(f"</level{d}>" for d in reversed(range(depth))) + "\n"
        out.append(s)
        size += len(s)
        i += 1
    out.append("</config>")
    return "".join(out)


SHAPES = {"records": records, "text": text, "ns": ns, "nested": nested}
ap = argparse.ArgumentParser()
ap.add_argument("--dll")
ap.add_argument("--tag", default="xpact")
ap.add_argument("--sizes", default="1,5,9,20")
ap.add_argument("--shapes", default="records,text,ns,nested")
ap.add_argument("--whole-only", action="store_true", help="skip the 64 KB chunk runs")
args = ap.parse_args()
inputs = HERE / "inputs"
inputs.mkdir(exist_ok=True)
rows = []
print(f"{'file':16} {'mode':7} {'handlers':8} | {'xpact':>24} | {'expat':>24} | events")
for shape in args.shapes.split(","):
    make = SHAPES[shape]
    for mb in map(int, args.sizes.split(",")):
        path = inputs / f"{shape}-{mb}mb.xml"
        if not path.exists():
            path.write_text(make(random.Random(mb), mb * MB), encoding="utf-8")
        for mode in (None,) if args.whole_only else (None, "every:65536"):
            for bare in (True, False):
                row = {"file": path.name, "size_mb": round(path.stat().st_size / MB, 1), "mode": mode or "whole",
                       "handlers": "none" if bare else "all"}
                for engine in ("xpact", "expat"):
                    job = {"file": str(path), "split": mode, "namespaces": shape == "ns", "bare": bare,
                           "hash_events": not bare}
                    with Pool(engine, timeout=300, dll=args.dll) as pool:
                        r = pool.run(job)
                    row[engine] = r["verdict"]
                    row[engine + "_s"] = r.get("seconds", "")
                    row[engine + "_mb"] = r.get("peak_mb", "")
                    row[engine + "_message"] = r.get("message") or r.get("exit_hex", "")
                    row[engine + "_hash"] = r.get("events_hash", "")
                    row[engine + "_events"] = r.get("event_count", "")
                same = "" if bare or row["xpact"] != "ACCEPT" else (
                    "same" if row["xpact_hash"] == row["expat_hash"] else "DIFFERENT")
                row["events"] = same
                rows.append(row)
                print(f"{path.name:16} {row['mode']:7} {row['handlers']:8} | {row['xpact']:7} {row['xpact_s']!s:>7}s "
                      f"{row['xpact_mb']!s:>6}MB | {row['expat']:7} {row['expat_s']!s:>7}s {row['expat_mb']!s:>6}MB | "
                      f"{same} {row['xpact_message']}", flush=True)
(HERE / "logs").mkdir(exist_ok=True)
with open(HERE / "logs" / f"large-{args.tag}.tsv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, list(rows[0]), delimiter="\t")
    w.writeheader()
    w.writerows(rows)
