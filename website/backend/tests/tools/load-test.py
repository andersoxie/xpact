"""Load test for the XPact website API (POST /api/validate). Standard library only.

    python load-test.py --url http://localhost:5199 --levels 1,4,8,16,32 --requests 64

Start the API with a high rate limit first (Xpact__RequestsPerMinute=100000), or every
request after the 30th per minute gets 429.
"""
import argparse, json, statistics, time, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor

def doc(kind):
    if kind == "small":
        return "<a/>"
    # about 100 KB: 5,000 elements with an attribute and text
    return "<root>" + "".join(f'<item id="{i}">text {i}</item>' for i in range(5000)) + "</root>"

def one(url, body):
    req = urllib.request.Request(url + "/api/validate", data=body, headers={"Content-Type": "application/json"})
    t = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            verdict = json.loads(r.read()).get("verdict", "?")
            code = r.status
    except urllib.error.HTTPError as e:
        code, verdict = e.code, "http-error"
    except Exception as e:
        code, verdict = 0, type(e).__name__
    return (time.perf_counter() - t) * 1000, code, verdict

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default="http://localhost:5199")
    ap.add_argument("--levels", default="1,4,8,16,32")
    ap.add_argument("--requests", type=int, default=64)
    ap.add_argument("--doc", choices=["small", "100kb"], default="100kb")
    a = ap.parse_args()
    body = json.dumps({"xml": doc(a.doc)}).encode()
    print(f"doc={a.doc} ({len(body)} bytes JSON), {a.requests} requests per level")
    print("| Visitors at once | Requests/s | Median ms | 95th pct ms | Max ms | Not accepted |")
    print("|---:|---:|---:|---:|---:|---:|")
    for level in [int(x) for x in a.levels.split(",")]:
        t0 = time.perf_counter()
        with ThreadPoolExecutor(level) as ex:
            res = list(ex.map(lambda _: one(a.url, body), range(a.requests)))
        wall = time.perf_counter() - t0
        ms = sorted(r[0] for r in res)
        bad = sum(1 for r in res if r[1] != 200 or r[2] != "accepted")
        p95 = ms[min(len(ms) - 1, int(len(ms) * 0.95))]
        print(f"| {level} | {len(res)/wall:.1f} | {statistics.median(ms):.0f} | {p95:.0f} | {ms[-1]:.0f} | {bad} |")

if __name__ == "__main__":
    main()
