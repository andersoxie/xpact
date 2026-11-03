import sys
from pathlib import Path
out = Path(sys.argv[1])
items = int(sys.argv[2])
rich = []
rich.append('<?xml version="1.0" encoding="UTF-8"?>\r\n<!DOCTYPE catalog [\r\n  <!ENTITY co "Example Company &#169;">\r\n  <!ATTLIST item status CDATA "new">\r\n]>\r\n<catalog>\r\n')
for i in range(items):
    rich.append(f'  <item id="i{i}" price="{i % 97}.50" kind="t&amp;s">\r\n'
                f'    <name>Caf\u00e9 item {i} &lt;special&gt; &#x263A;</name>\r\n'
                f'    <maker>&co;</maker>\r\n'
                f'    <!-- comment {i} -->\r\n'
                f'    <desc><![CDATA[raw <text> {i}]]> and some longer descriptive text for item number {i}, '
                f'to make the text runs a little longer than one or two words.</desc>\r\n'
                f'  </item>\r\n')
rich.append('</catalog>\r\n')
out.with_name(out.stem + "-rich.xml").write_bytes("".join(rich).encode("utf-8"))
plain = ['<catalog>\n']
for i in range(items):
    plain.append(f'  <item id="i{i}" price="{i % 97}.50"><name>item {i}</name><desc>some descriptive text for item {i}</desc></item>\n')
plain.append('</catalog>\n')
out.with_name(out.stem + "-plain.xml").write_bytes("".join(plain).encode("utf-8"))
