"""Turn Markus Kuhn's "UTF-8 decoder capability and stress test" into XML fixtures (mass-xpact #83).

Every non-empty line of UTF-8-test.txt becomes two documents: the line as element text (<r>LINE</r>) and as an
attribute value (<r a="LINE"/>, with " and & and < escaped). The line's bytes are kept exactly, including the
malformed sequences the file is made of. Expat 2.8.1 is the reference, so there is no expected column.
The source file is not committed; it is downloaded and checked against the SHA-256 below.

Usage, from the repository root:
  curl -o build/downloads/kuhn/UTF-8-test.txt https://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt
  python -I student/results/kuhn-utf8-2026-11-06/make_fixtures.py build/downloads/kuhn/UTF-8-test.txt
"""
import csv
import hashlib
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
SOURCE_SHA256 = "b51cfe9a8d2689c90b10a13a3624092d546e0837c6ff835b6e5d713c5749c8c6"


def main():
    data = Path(sys.argv[1]).read_bytes()
    if hashlib.sha256(data).hexdigest() != SOURCE_SHA256:
        sys.exit("UTF-8-test.txt differs from the version these results were made from")
    out = HERE / "fixtures"
    out.mkdir(exist_ok=True)
    rows = []
    for n, line in enumerate(data.split(b"\n"), 1):
        line = line.rstrip(b"\r")
        if not line.strip():
            continue
        attr = line.replace(b"&", b"&amp;").replace(b"<", b"&lt;").replace(b'"', b"&quot;")
        for kind, doc in (("text", b"<r>" + line.replace(b"&", b"&amp;").replace(b"<", b"&lt;") + b"</r>"),
                          ("attribute", b'<r a="' + attr + b'"/>')):
            p = out / f"line{n:03d}-{kind}.xml"
            p.write_bytes(doc)
            rows.append({"id": f"kuhn/line{n:03d}-{kind}", "set": f"kuhn-{kind}", "path": p.relative_to(REPO).as_posix(),
                         "sha256": hashlib.sha256(doc).hexdigest(), "bytes": len(doc), "expected": "",
                         "namespaces": "off", "entity_root": out.relative_to(REPO).as_posix(),
                         "source": "UTF-8-test.txt (Markus Kuhn), line %d" % n, "finding": ""})
    with (HERE / "manifest.tsv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, list(rows[0]), delimiter="\t")
        w.writeheader()
        w.writerows(rows)
    print(len(rows), "fixtures")


if __name__ == "__main__":
    main()
