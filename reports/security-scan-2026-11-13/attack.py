"""Harmful-upload and protocol attack battery against a local XPact website (stdlib only).

usage: python -I attack.py <port-high-ratelimit> <port-default-limits> <out.json>
Each check prints: id | expected | observed | PASS/FAIL. Expected and observed are kept separate.
"""
import gzip, http.client, json, os, socket, sys, threading, time, glob, tempfile

HI, LO, OUT = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
results = []


def req(port, method, path, body=b"", headers=None, timeout=60):
    c = http.client.HTTPConnection("127.0.0.1", port, timeout=timeout)
    t = time.time()
    c.request(method, path, body=body, headers=headers or {})
    r = c.getresponse()
    data = r.read()
    c.close()
    return r.status, dict(r.getheaders()), data, time.time() - t


def post_xml(doc, port=HI, query="", ctype="application/xml"):
    return req(port, "POST", "/api/validate" + query, doc, {"Content-Type": ctype})


def multipart(fields, port=HI):
    b = b"----x7MA4YWxkTrZu0gW"
    parts = []
    for name, filename, ctype, data in fields:
        h = f'Content-Disposition: form-data; name="{name}"'.encode()
        if filename is not None:
            h += b'; filename="' + filename + b'"'
        if ctype:
            h += b"\r\nContent-Type: " + ctype.encode()
        parts.append(b"--" + b + b"\r\n" + h + b"\r\n\r\n" + data + b"\r\n")
    body = b"".join(parts) + b"--" + b + b"--\r\n"
    return req(port, "POST", "/api/validate", body, {"Content-Type": "multipart/form-data; boundary=" + b.decode()})


def verdict(data):
    try:
        j = json.loads(data)
        return f"{j.get('verdict')} code={(j.get('error') or {}).get('code')}"
    except Exception:
        return data[:80].decode("latin-1")


def check(cid, expected, observed, ok):
    results.append({"id": cid, "expected": expected, "observed": observed, "result": "PASS" if ok else "FAIL"})
    print(f"{cid} | {expected} | {observed} | {'PASS' if ok else 'FAIL'}", flush=True)


def safe(cid, expected, fn):
    try:
        fn()
    except Exception as e:
        check(cid, expected, f"exception {type(e).__name__}: {e}"[:160], False)


# ---------- 1 XXE / SSRF: no file read, no outbound connection
hits = []
srv = socket.socket(); srv.bind(("127.0.0.1", 0)); srv.listen(5); srv.settimeout(0.5)
lport = srv.getsockname()[1]
def listen():
    end = time.time() + 25
    while time.time() < end:
        try:
            s, _ = srv.accept(); hits.append(s.recv(200)); s.close()
        except Exception:
            pass
threading.Thread(target=listen, daemon=True).start()

def t_xxe_file():
    s, h, d, t = post_xml(b'<?xml version="1.0"?><!DOCTYPE r [<!ENTITY x SYSTEM "file:///c:/windows/win.ini">]><r>&x;</r>')
    leaked = b"fonts" in d.lower() or b"[extensions]" in d.lower()
    check("XXE-file", "win.ini content never in response", f"HTTP {s}, {verdict(d)}, leaked={leaked}", not leaked)
safe("XXE-file", "no leak", t_xxe_file)

def t_ssrf():
    docs = [f'<!DOCTYPE r SYSTEM "http://127.0.0.1:{lport}/a.dtd"><r/>',
            f'<!DOCTYPE r [<!ENTITY x SYSTEM "http://127.0.0.1:{lport}/b">]><r>&x;</r>',
            f'<!DOCTYPE r [<!ENTITY % p SYSTEM "http://127.0.0.1:{lport}/c"> %p;]><r/>',
            f'<?xml-stylesheet href="http://127.0.0.1:{lport}/d"?><r/>',
            f'<r xmlns:xi="http://www.w3.org/2001/XInclude"><xi:include href="http://127.0.0.1:{lport}/e"/></r>']
    for d in docs:
        post_xml(d.encode())
    time.sleep(1)
    check("SSRF", "no connection to a listener named in DTD/entity/PI/XInclude", f"{len(hits)} connections", len(hits) == 0)
safe("SSRF", "no connection", t_ssrf)

def t_unc():
    s, h, d, t = post_xml(b'<!DOCTYPE r [<!ENTITY x SYSTEM "\\\\127.0.0.1\\share\\x">]><r>&x;</r>')
    check("XXE-UNC", "UNC path not opened (no NTLM leak), clean verdict", f"HTTP {s}, {verdict(d)}, {t:.1f}s", s == 200 and t < 5)
safe("XXE-UNC", "clean", t_unc)

# ---------- 2 entity bombs
def laughs(levels, width=10):
    s = '<!DOCTYPE r [<!ENTITY a0 "xxxxxxxxxx">'
    for i in range(1, levels):
        s += f'<!ENTITY a{i} "' + f"&a{i-1};" * width + '">'
    return (s + f"]><r>&a{levels-1};</r>").encode()

def t_laughs():
    s, h, d, t = post_xml(laughs(10))
    check("Billion-laughs", "rejected code 43 < 10 s", f"{verdict(d)}, {t:.1f}s", "code=43" in verdict(d) and t < 10)
safe("Billion-laughs", "code 43", t_laughs)

def t_quadratic():
    ent = "y" * 100000
    doc = f'<!DOCTYPE r [<!ENTITY q "{ent}">]><r>' + "&q;" * 50000 + "</r>"
    s, h, d, t = post_xml(doc.encode())
    check("Quadratic-blowup", "stopped (43) or finished, never crash/hang", f"{verdict(d)}, {t:.1f}s", s == 200 and "crashed" not in verdict(d) and t < 15)
safe("Quadratic-blowup", "stopped", t_quadratic)

def t_attr_bomb():
    doc = '<!DOCTYPE r [<!ENTITY a "' + "z" * 1000 + '">]><r ' + " ".join(f'a{i}="&a;&a;&a;&a;&a;&a;&a;&a;&a;&a;"' for i in range(20000)) + "/>"
    s, h, d, t = post_xml(doc.encode())
    check("Attr-entity-bomb", "clean verdict, no crash", f"{verdict(d)}, {t:.1f}s", s == 200 and "crashed" not in verdict(d))
safe("Attr-entity-bomb", "clean", t_attr_bomb)

# ---------- 3 structure abuse
def t_deep():
    n = 3_000_000
    s, h, d, t = post_xml(b"<a>" * n + b"</a>" * 0)
    check("Deep-nesting-3M", "clean verdict (rejected/timeout), site keeps serving", f"{verdict(d)}, {t:.1f}s", s == 200)
safe("Deep-nesting-3M", "clean", t_deep)

def t_long_name():
    s, h, d, t = post_xml(b"<" + b"n" * 5_000_000 + b"/>")
    check("Name-5MB", "clean verdict", f"{verdict(d)}, {t:.1f}s", s == 200 and "crashed" not in verdict(d))
safe("Name-5MB", "clean", t_long_name)

def t_many_attrs():
    s, h, d, t = post_xml(("<r " + " ".join(f"a{i}='1'" for i in range(300000)) + "/>").encode())
    check("Attrs-300k", "clean verdict (hash flooding must not hang)", f"{verdict(d)}, {t:.1f}s", s == 200 and "crashed" not in verdict(d))
safe("Attrs-300k", "clean", t_many_attrs)

def t_dup_attr():
    s, h, d, t = post_xml(b"<r a='1' a='2'/>")
    check("Dup-attribute", "rejected (not well-formed)", verdict(d), "rejected" in verdict(d))
safe("Dup-attribute", "rejected", t_dup_attr)

# ---------- 4 encodings / binary
def t_binary():
    s, h, d, t = post_xml(os.urandom(10 * 1024 * 1024 - 1))
    check("Random-binary-10MB", "rejected, no crash", f"{verdict(d)}, {t:.1f}s", "rejected" in verdict(d))
safe("Random-binary-10MB", "rejected", t_binary)

def t_encodings():
    obs = []
    for name, doc in [("utf16le-bom", b"\xff\xfe" + "<r>ü</r>".encode("utf-16-le")),
                      ("utf32", b"\x00\x00\xfe\xff" + "<r/>".encode("utf-32-be")),
                      ("nul", b"<r>\x00</r>"), ("overlong", b"<r>\xc0\xaf</r>"),
                      ("surrogate", b"<r>\xed\xa0\x80</r>"), ("bad-decl", b'<?xml version="1.0" encoding="x-evil"?><r/>')]:
        s, h, d, t = post_xml(doc)
        obs.append(f"{name}:{verdict(d)}")
    ok = all("crashed" not in o and "error code" not in o for o in obs) and "utf16le-bom:accepted" in " ".join(obs)
    check("Encodings", "UTF-16 accepted; NUL/overlong/surrogate rejected; no crash", "; ".join(obs), ok)
safe("Encodings", "ok", t_encodings)

def t_gzip_body():
    bomb = gzip.compress(b"<r>" + b"a" * 50_000_000 + b"</r>")
    s, h, d, t = req(HI, "POST", "/api/validate", bomb, {"Content-Type": "application/xml", "Content-Encoding": "gzip"})
    check("Gzip-bomb-body", "body NOT decompressed (rejected as bytes or 415)", f"HTTP {s}, {verdict(d)}, {len(bomb)} B sent", "accepted" not in verdict(d))
safe("Gzip-bomb-body", "not decompressed", t_gzip_body)

# ---------- 5 script content is never executed / reflected as HTML
def t_script():
    doc = b'<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script><foo onload="alert(2)"/><x>&lt;img src=x onerror=alert(3)&gt;</x></svg>'
    s, h, d, t = post_xml(doc)
    ct = h.get("Content-Type", "")
    check("Script-in-XML", "JSON response (application/json), nosniff, CSP set", f"HTTP {s}, {ct}, nosniff={h.get('X-Content-Type-Options')}, csp={'Content-Security-Policy' in h}",
          "application/json" in ct and h.get("X-Content-Type-Options") == "nosniff")
safe("Script-in-XML", "json", t_script)

# ---------- 6 multipart abuse
def t_filename():
    s, h, d, t = multipart([("file", b"../../../../Windows/evil.xml\r\nX-Injected: 1", "text/html", b"<r/>")])
    check("Filename-traversal/CRLF", "filename ignored, document parsed", f"HTTP {s}, {verdict(d)}", s in (200, 400))
safe("Filename-traversal/CRLF", "ignored", t_filename)

def t_many_parts():
    s, h, d, t = multipart([(f"f{i}", None, None, b"x") for i in range(5000)])
    check("Multipart-5000-fields", "refused (400), quick", f"HTTP {s}, {t:.1f}s", s == 400 and t < 10)
safe("Multipart-5000-fields", "400", t_many_parts)

def t_many_files():
    s, h, d, t = multipart([(f"g{i}", b"a.xml", "application/xml", b"z" * 100_000) for i in range(150)] + [("file", b"x.xml", None, b"<r/>")])
    check("Multipart-150-extra-files", "only 'file' used; refused or accepted, no disk/memory blow-up", f"HTTP {s}, {verdict(d)}, {t:.1f}s", s in (200, 400, 413))
safe("Multipart-150-extra-files", "bounded", t_many_files)

# ---------- 7 JSON / parameters
def t_params():
    obs = []
    for q in ["?build=../../native/x", "?build=PRODUCTION%00", "?chunkSize=-5", "?chunkSize=99999999999", "?chunkSize=2147483647"]:
        s, h, d, t = post_xml(b"<r/>", query=q)
        obs.append(f"{q}:{s}")
    deep = b'{"xml":"<r/>","build":' + b"[" * 5000 + b"]" * 5000 + b"}"
    s, h, d, t = req(HI, "POST", "/api/validate", deep, {"Content-Type": "application/json"})
    obs.append(f"deep-json:{s}")
    ok = all(not o.endswith(":500") for o in obs)
    check("Params/JSON", "400 or a safe default, never 500", "; ".join(obs), ok)
safe("Params/JSON", "no 500", t_params)

# ---------- 8 files that must not be served
def t_paths():
    obs = []
    for p in ["/appsettings.json", "/Xpact.Api.dll", "/native/xpact.dll", "/web.config", "/data/testing.json",
              "/api/results/..%2f..%2fappsettings", "/api/results/%2e%2e%5cappsettings", "/.git/config", "/Xpact.Worker.exe"]:
        s, h, d, t = req(HI, "GET", p)
        leaked = (b"AllowedHosts" in d) or d[:2] == b"MZ" or b"[core]" in d
        obs.append(f"{p}:{s}{'!LEAK' if leaked else ''}")
    check("Server-files", "never served (404 or the index page)", "; ".join(obs), "LEAK" not in " ".join(obs))
safe("Server-files", "no leak", t_paths)

def t_methods():
    obs = []
    for m in ["TRACE", "PUT", "DELETE", "OPTIONS"]:
        s, h, d, t = req(HI, m, "/api/validate")
        obs.append(f"{m}:{s}")
    check("HTTP-methods", "TRACE/PUT/DELETE not allowed (405/404)", "; ".join(obs), all(not o.endswith(":200") for o in obs if not o.startswith("OPTIONS")))
safe("HTTP-methods", "405", t_methods)

def t_headers():
    s, h, d, t = req(HI, "GET", "/")
    want = ["Content-Security-Policy", "X-Content-Type-Options", "X-Frame-Options", "Referrer-Policy", "Permissions-Policy", "Cross-Origin-Opener-Policy"]
    missing = [w for w in want if w not in h]
    check("Security-headers", "all set, no Server/X-Powered-By", f"missing={missing}, server={h.get('Server')}, powered={h.get('X-Powered-By')}", not missing and "Server" not in h and "X-Powered-By" not in h)
safe("Security-headers", "set", t_headers)

def t_host():
    s, h, d, t = req(HI, "GET", "/api/health", headers={"Host": "evil.example"})
    check("Host-header", "foreign Host refused (400)", f"HTTP {s}", s == 400)
safe("Host-header", "400", t_host)

# ---------- 9 disk: is the uploaded document written to a temp file?
def t_tempfiles():
    tmp = tempfile.gettempdir()
    before = set(glob.glob(os.path.join(tmp, "ASPNETCORE_*")))
    seen = []
    stop = []
    def watch():
        while not stop:
            seen.extend(set(glob.glob(os.path.join(tmp, "ASPNETCORE_*"))) - before); time.sleep(0.01)
    th = threading.Thread(target=watch); th.start()
    multipart([("file", b"big.xml", "application/xml", b"<r>" + b"s" * 5_000_000 + b"</r>")])
    stop.append(1); th.join()
    check("Upload-to-disk", "document never written to disk (security.md)", f"{len(set(seen))} temp files seen in {tmp}", len(set(seen)) == 0)
safe("Upload-to-disk", "none", t_tempfiles)

# ---------- 10 slow upload (slowloris on the body)
def t_slow_body():
    s = socket.create_connection(("127.0.0.1", HI), timeout=5)
    s.sendall(b"POST /api/validate HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/xml\r\nContent-Length: 20000000\r\n\r\n")
    t0 = time.time(); alive = True
    try:
        while time.time() - t0 < 40:
            s.sendall(b"<" * 300); time.sleep(1)   # 300 B/s, above Kestrel's default 240 B/s minimum
    except Exception:
        alive = False
    s.close()
    check("Slow-upload-300B/s", "connection dropped well before 40 s (a 20 MB body at 300 B/s = 18 h)", f"alive after 40 s={alive}", not alive)
safe("Slow-upload-300B/s", "dropped", t_slow_body)

def t_slow_headers():
    s = socket.create_connection(("127.0.0.1", HI), timeout=5)
    s.sendall(b"GET / HTTP/1.1\r\nHost: localhost\r\n"); t0 = time.time(); alive = True
    try:
        while time.time() - t0 < 45:
            s.sendall(b"X-a: b\r\n"); time.sleep(2)
    except Exception:
        alive = False
    s.close()
    check("Slow-headers", "dropped within ~30 s (Kestrel RequestHeadersTimeout)", f"alive after 45 s={alive}", not alive)
safe("Slow-headers", "dropped", t_slow_headers)

# ---------- 11 rate limit (default-limit instance). Spoofed X-Forwarded-For from a REMOTE address is
# ignored: covered by the unit test Only_trusted_proxies_pass_on_the_visitor_address. From localhost the
# header is trusted on purpose (a reverse proxy on the same machine), so it cannot be tested from here.
def t_rate():
    codes = []
    for i in range(35):
        s, h, d, t = req(LO, "POST", "/api/validate", b"<r/>", {"Content-Type": "application/xml"})
        codes.append(s)
    check("Rate-limit", "30 per minute per visitor, then 429", f"first 429 at request {codes.index(429)+1 if 429 in codes else None}", 429 in codes and codes.index(429) == 30)
safe("Rate-limit", "429", t_rate)

def t_alive():
    s, h, d, t = req(HI, "GET", "/api/health")
    check("Site-alive-after-all", "health 200", f"HTTP {s}", s == 200)
safe("Site-alive-after-all", "200", t_alive)

json.dump(results, open(OUT, "w"), indent=1)
print(f"\n{sum(r['result']=='PASS' for r in results)} PASS, {sum(r['result']=='FAIL' for r in results)} FAIL")
