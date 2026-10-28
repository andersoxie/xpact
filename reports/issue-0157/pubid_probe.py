"""Public-ID events from xpact and Expat for one document with public IDs in every place.

Usage: python -I reports/issue-0157/pubid_probe.py [path to xpact.dll]
The document refers to d.dtd, which does not exist, so both parsers stop there;
the declaration events before that point are what is compared.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "issue-0154" / "tools" / "harness"))
import engines  # noqa: E402

doc = (b'<!DOCTYPE d PUBLIC "  -//A\r\n   B//EN " "d.dtd" ['
       b'<!NOTATION n PUBLIC " a \n  b ">'
       b'<!ENTITY e PUBLIC "  x \n y " "e.xml">'
       b'<!ENTITY u PUBLIC " p  q " "u.bin" NDATA n>]><d/>')
dll = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else None
for engine in ("expat", "xpact"):
    kw = {"dll": dll} if engine == "xpact" and dll else {}
    r = engines.parse(engine, doc, **kw)
    print(engine, r["verdict"], r.get("message", ""))
    for e in r["events"]:
        if e[0] in ("startdoctype", "notationdecl", "entitydecl", "unparseddecl", "unparsedentitydecl"):
            print("  ", e)
