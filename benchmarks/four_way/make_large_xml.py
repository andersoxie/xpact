"""Write a deterministic large catalog XML file (for scripts/run_large_xml_benchmarks.ps1).
  python make_large_xml.py OUT.xml SIZE_MB"""
import sys
from pathlib import Path
out, mb = Path(sys.argv[1]), int(sys.argv[2]); out.parent.mkdir(parents=True, exist_ok=True)
item = ('<item id="{0}" sku="SKU-{0:08d}" available="{1}"><name>Item &amp; part {0}</name>'
        '<price currency="EUR">{2}.{3:02d}</price><tags><tag>alpha</tag><tag>beta-{4}</tag></tags>'
        '<description><![CDATA[Line one for {0}; <not markup> & more]]> plain text &#x263A;</description></item>\n')
target = mb * 1024 * 1024
with out.open("w", encoding="utf-8", newline="\n") as f:
    f.write('<?xml version="1.0" encoding="UTF-8"?>\n<catalog>\n'); i = 0
    while f.tell() < target:
        f.write(item.format(i, "yes" if i % 3 else "no", i % 997, i % 100, i % 17)); i += 1
    f.write("</catalog>\n")
print(f"{out} {out.stat().st_size} bytes, {i} items")