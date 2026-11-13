import http.client, json, sys, threading, time
port, n = int(sys.argv[1]), int(sys.argv[2])
body = json.dumps({"xml": "<r>" + '"' * (10 * 1024 * 1024 - 8) + "</r>"}).encode()  # every quote doubles in JSON
codes = []
def go():
    try:
        c = http.client.HTTPConnection("127.0.0.1", port, timeout=120); c.request("POST", "/api/validate", body, {"Content-Type": "application/json", **({"X-Forwarded-For": f"10.0.{threading.get_ident() % 251}.1"} if len(sys.argv) > 3 else {})}); r = c.getresponse(); r.read(); codes.append(r.status)
    except Exception as e:
        codes.append(type(e).__name__)
t0 = time.time(); ts = [threading.Thread(target=go) for _ in range(n)]
[t.start() for t in ts]; [t.join() for t in ts]
print(f"{n} x {len(body)/1e6:.1f} MB JSON: codes {sorted(set(map(str, codes)))} {dict((str(c), codes.count(c)) for c in set(codes))}, {time.time()-t0:.1f}s")
