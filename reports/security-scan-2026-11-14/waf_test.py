"""Send normal and harmful XML to the site directly (5098) and through the WAF (5097), three ways each."""
import http.client, json, sys, base64
L = {  # normal documents a user of an XML validator may upload
 "plain": b'<?xml version="1.0"?><note><to>Ann</to><body>Hi</body></note>',
 "namespaces": b'<r xmlns="urn:a" xmlns:x="http://www.w3.org/1999/xlink"><x:a x:href="http://example.com/"/></r>',
 "internal_dtd": b'<!DOCTYPE d [<!ELEMENT d (#PCDATA)><!ENTITY co "ACME">]><d>&co;</d>',
 "dtd_attlist": b'<!DOCTYPE d [<!ELEMENT d EMPTY><!ATTLIST d id ID #REQUIRED>]><d id="a1"/>',
 "doctype_public": b'<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"><html xmlns="http://www.w3.org/1999/xhtml"><head><title>t</title></head><body/></html>',
 "cdata_sql": b"<q><![CDATA[SELECT * FROM users WHERE id = 1 OR 1=1; DROP TABLE x;--]]></q>",
 "cdata_js": b'<s><![CDATA[<script>alert(document.cookie)</script>]]></s>',
 "svg": b'<svg xmlns="http://www.w3.org/2000/svg" onload="init()"><rect width="10" height="10"/></svg>',
 "soap": b'<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body><GetUser><id>1</id></GetUser></soap:Body></soap:Envelope>',
 "pom": b'<project><modelVersion>4.0.0</modelVersion><build><plugins><plugin><artifactId>exec</artifactId><configuration><executable>/bin/sh</executable><arguments><argument>-c</argument><argument>cat /etc/passwd</argument></arguments></configuration></plugin></plugins></build></project>',
 "xslt": b'<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"><xsl:template match="/"><xsl:value-of select="system-property(\'xsl:vendor\')"/></xsl:template></xsl:stylesheet>',
 "rss": b'<rss version="2.0"><channel><title>News</title><link>https://example.com/?a=1&amp;b=2</link><item><title>Tom &amp; Jerry</title></item></channel></rss>',
 "utf16": '<?xml version="1.0" encoding="UTF-16"?><a>\u00e5\u00e4\u00f6</a>'.encode("utf-16"),
 "unicode_name": '<\u00e9l\u00e8ve nom="\u00c5sa">\u4e2d\u6587</\u00e9l\u00e8ve>'.encode(),
 "invalid_unclosed": b"<a><b></a>",
}
EICAR = base64.b64decode("WDVPIVAlQEFQWzRcUFpYNTQoUF4pN0NDKTd9JEVJQ0FSLVNUQU5EQVJELUFOVElWSVJVUy1URVNULUZJTEUhJEgrSCo=")
H = {
 "xxe_file": b'<!DOCTYPE d [<!ENTITY x SYSTEM "file:///C:/Windows/win.ini">]><d>&x;</d>',
 "xxe_ssrf": b'<!DOCTYPE d [<!ENTITY x SYSTEM "http://169.254.169.254/latest/meta-data/">]><d>&x;</d>',
 "xxe_param": b'<!DOCTYPE d [<!ENTITY % p SYSTEM "http://127.0.0.1:9/evil.dtd"> %p;]><d/>',
 "laughs": b'<!DOCTYPE l [<!ENTITY a "aaaaaaaaaa">' + b"".join(b'<!ENTITY %c "%s">' % (bytes([98+i]), (b"&%c;" % (97+i))*10) for i in range(8)) + b']><l>&i;</l>',
 "deep": b"<a>"*20000 + b"</a>"*20000,
 "eicar_in_xml": b"<a>" + EICAR + b"</a>",
 "eicar_cdata": b"<a><![CDATA[" + EICAR + b"]]></a>",
 "script_inj": b'<a><img src=x onerror="alert(1)"/></a>',
 "php_shell": b'<a><?php system($_GET["c"]); ?></a>',
}
def send(port, mode, doc):
    c = http.client.HTTPConnection("127.0.0.1", port, timeout=60)
    if mode == "raw": body, h = doc, {"Content-Type": "application/xml"}
    elif mode == "json": body, h = json.dumps({"xml": doc.decode("utf-8", "replace"), "build": "production", "chunkSize": 0}).encode(), {"Content-Type": "application/json"}
    else:
        b = b"----b0undaryX"
        body = (b"--"+b+b'\r\nContent-Disposition: form-data; name="file"; filename="doc.xml"\r\nContent-Type: text/xml\r\n\r\n'+doc+b"\r\n--"+b+b'\r\nContent-Disposition: form-data; name="build"\r\n\r\nproduction\r\n--'+b+b"--\r\n")
        h = {"Content-Type": "multipart/form-data; boundary=" + b.decode()}
    try:
        c.request("POST", "/api/validate", body, h); r = c.getresponse(); d = r.read()
        try: v = json.loads(d).get("verdict")
        except Exception: v = "-"
        return f"{r.status}:{v}"
    except Exception as e: return "ERR:" + type(e).__name__
out = []
for kind, docs in (("normal", L), ("harmful", H)):
    for name, doc in docs.items():
        for mode in ("raw", "json", "file"):
            d, w = send(5098, mode, doc), send(5097, mode, doc)
            out.append((kind, name, mode, d, w))
            print(kind, name, mode, "direct", d, "waf", w, flush=True)
json.dump(out, open(sys.argv[1], "w"), indent=1)
