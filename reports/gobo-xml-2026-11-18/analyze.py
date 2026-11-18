"""Collect every area's logs into results.json + results.md (xpact vs Gobo, Expat as reference).
Scores verdicts only where Gobo has no equivalent (Expat error codes, Expat-only event kinds)."""
import csv
import json
from collections import Counter
from pathlib import Path

H = Path(__file__).resolve().parent
OUT = {}
md = []


def tsv(p):
    p = H / p
    return list(csv.DictReader(open(p, encoding="utf-8"), delimiter="\t")) if p.is_file() else []


def js(p):
    p = H / p
    return json.loads(p.read_text(encoding="utf-8")) if p.is_file() else None


def table(title, header, rows):
    md.append(f"\n### {title}\n")
    md.append("| " + " | ".join(header) + " |")
    md.append("|" + "---|" * len(header))
    md.extend("| " + " | ".join(str(c) for c in r) + " |" for r in rows)


# 01 W3C verdicts through the harness (DLL / Gobo / pyexpat, entity root = suite)
v = {e: {r["id"]: r for r in tsv(f"01-w3c-output-comparison/logs/verdicts-{e}.tsv")} for e in ("xpact", "gobo")}
if v["xpact"] and v["gobo"]:
    rows, area = [], {}
    for e in ("xpact", "gobo"):
        c = Counter((r["lane"], r["status"]) for r in v[e].values())
        same_expat = sum(r["xpact"] == r["expat"] for r in v[e].values() if r["lane"] == "core")
        crash = sum(r["xpact"] in ("CRASH", "TIMEOUT", "EXCEPTION") for r in v[e].values())
        area[e] = {"core_pass": c[("core", "pass")], "core_fail": c[("core", "fail")], "same_as_expat_core": same_expat,
                   "crash_timeout_exception": crash}
        rows.append([e, c[("core", "pass")], c[("core", "fail")], same_expat, crash])
    groups = Counter()
    for k, x in v["xpact"].items():
        g = v["gobo"][k]
        if x["lane"] == "core" and x["xpact"] != g["xpact"]:
            groups[f"{x['type']} expected {x['expected']}: xpact {x['xpact']}, Gobo {g['xpact']}, Expat {x['expat']}"] += 1
    area["differences"] = dict(groups)
    OUT["01_w3c_verdicts"] = area
    table("W3C verdicts, harness lane (1,974 core cases)", ["Engine", "Core pass", "Core fail", "Same verdict as Expat", "Crash/timeout/exception"], rows)
    table("Where xpact and Gobo disagree (core)", ["Case group", "Cases"], [[k, n] for k, n in groups.most_common()])

# 01 W3C canonical output comparison (432 cases with OUTPUT)
o = {e: js(f"01-w3c-output-comparison/logs/{e}/summary.json") for e in ("xpact", "gobo")}
if all(o.values()):
    OUT["01_w3c_output"] = o
    table("W3C output (canonical XML, 432 cases)", ["Engine", "Exact", "Engine only wrong", "Both wrong", "Total"],
          [[e, o[e].get("pass"), o[e].get("xpact-only"), o[e].get("both-differ"), o[e].get("total")] for e in o])

# 08 encodings: verdict vs spec (error codes ignored)
enc = {e: tsv(f"08-encodings/logs/encodings-{e}.tsv") for e in ("xpact", "gobo")}
if all(enc.values()):
    rows, area = [], {}
    for e in enc:
        # create-*: the caller's encoding override (XML_ParserCreate(encoding)); Gobo has no such API
        judged = [r for r in enc[e] if not (e == "gobo" and r["id"].startswith("create-"))]
        ok = sum(r["xpact"] == r["expected"] for r in judged)
        area[e] = {"right": ok, "judged": len(judged), "not_supported": len(enc[e]) - len(judged),
                   "wrong": [r["id"] for r in judged if r["xpact"] != r["expected"]]}
        rows.append([e, ok, len(judged) - ok, len(enc[e]) - len(judged), len(enc[e])])
    OUT["08_encodings"] = area
    table("Encodings (146 cases; expected = Expat, or the XML spec where explicit)",
          ["Engine", "Right", "Wrong", "Not supported (encoding override API)", "Total"], rows)
    gw = set(area["gobo"]["wrong"]) - set(area["xpact"]["wrong"])
    xw = set(area["xpact"]["wrong"]) - set(area["gobo"]["wrong"])
    md.append(f"\nGobo wrong, xpact right ({len(gw)}): {', '.join(sorted(gw))}\n")
    md.append(f"\nxpact wrong, Gobo right ({len(xw)}): {', '.join(sorted(xw)) or 'none'}\n")

# 07 libxml2 corpus: same verdict as Expat
lx = {e: tsv(f"07-libxml2-corpus/logs/libxml2-{e}.tsv") for e in ("xpact", "gobo")}
if all(lx.values()):
    rows, area = [], {}
    for e in lx:
        c = Counter(r["xpact"] for r in lx[e])
        same = sum(r["xpact"] == r["expat"] for r in lx[e])
        events_same = sum(r["signature"] == "same" for r in lx[e])
        area[e] = {"files": len(lx[e]), "same_verdict_as_expat": same, "same_verdict_and_events": events_same, "verdicts": dict(c),
                   "crash_timeout": [r["file"] for r in lx[e] if r["xpact"] in ("CRASH", "TIMEOUT", "EXCEPTION")]}
        rows.append([e, len(lx[e]), same, events_same, c["TIMEOUT"], c["CRASH"], c["EXCEPTION"]])
    OUT["07_libxml2"] = area
    table("libxml2 corpus (Expat = reference)", ["Engine", "Files", "Same verdict", "Same verdict + events", "Timeout", "Crash", "Exception"], rows)

# Project W3C runner (all 2,585 cases, XML 1.0 5th edition profile + lanes)
for folder, label in (("w3c", "strict Gobo (Unicode filter on)"), ("w3c-nouf", "Gobo without Unicode filter")):
    rr = tsv(f"{folder}/results.tsv")
    if rr:
        c = Counter((r["engine"], r["lane"], r["status"]) for r in rr)
        engines = list(dict.fromkeys(r["engine"] for r in rr))
        lanes = list(dict.fromkeys(r["lane"] for r in rr))
        OUT[f"w3c_runner_{folder}"] = {f"{e}/{ln}/{s}": n for (e, ln, s), n in c.items()}
        table(f"Project W3C runner, {label}", ["Engine"] + [f"{ln} pass/fail" for ln in lanes],
              [[e] + [f"{c[(e, ln, 'passed')]}/{c[(e, ln, 'failed')] + c[(e, ln, 'error')]}" for ln in lanes] for e in engines])


def time_boxed(kind, key):
    rows, area = [], {}
    for e in ("xpact", "gobo"):
        j = js(f"{kind}/logs/{key}-{e}-seed1.json")
        if not j:
            continue
        s = Counter(j["stats"])
        n = s.get("inputs") or s.get("documents") or 0
        vs = j.get("verdicts") or {k: v for k, v in s.items() if " / expat " in k}
        agree = sum(v for k, v in vs.items() if k.split(" / ")[0].split()[-1] == k.split()[-1])
        bad = {k: v for k, v in s.items() if any(w in k for w in ("CRASH", "TIMEOUT", "EXCEPTION"))}
        bad.update({k: v for k, v in vs.items() if "EXCEPTION" in k or "CRASH" in k or "TIMEOUT" in k})
        ev = sum(g["count"] for g in j.get("groups", []) if g["signature"].startswith("events"))
        area[e] = {"inputs": n, "seconds": j.get("seconds"), "same_verdict_as_expat": agree, "crash_timeout_exception": bad,
                   "both_accept_events_differ": ev, "verdicts": vs}
        rows.append([e, f"{n:,}", f"{100 * agree / max(1, sum(vs.values())):.3f} %", sum(bad.values()) or 0,
                     ev if kind.startswith("04") else "-"])
    return rows, area


for kind, key, title in (("03-fuzzing", "fuzz", "Fuzzing (mutated W3C documents, seed 1)"),
                         ("04-differential-vs-expat", "diff", "Differential vs Expat (generated documents, seed 1)")):
    rows, area = time_boxed(kind, key)
    if rows:
        OUT[kind] = area
        table(title, ["Engine", "Inputs", "Same verdict as Expat", "Crash/timeout/exception", "Both accept, events differ"], rows)

# 05 security and limits (29 cases, fresh process each, 60 s timeout)
sx, sg = tsv("05-security-limits/logs/security-xpact.tsv"), tsv("05-security-limits/logs/security-gobo.tsv")
if sx and sg:
    rows, area = [], {}
    for a, b in zip(sx, sg):
        ok = lambda r: "✅" if r["xpact"] == r["expected"] else "❌"  # noqa: E731
        rows.append([a["id"], a["expected"], f"{ok(a)} {a['xpact']} {a['xpact_s']} s {a['xpact_mb']} MB",
                     f"{ok(b)} {b['xpact']} {b['xpact_s']} s {b['xpact_mb']} MB"])
    for e, rr in (("xpact", sx), ("gobo", sg)):
        area[e] = {"pass": sum(r["xpact"] == r["expected"] for r in rr), "total": len(rr),
                   "timeout_crash_exception": [r["id"] for r in rr if r["xpact"] in ("TIMEOUT", "CRASH", "EXCEPTION")]}
    OUT["05_security_limits"] = area
    md.append(f"\nSecurity and limits: xpact {area['xpact']['pass']}/{area['xpact']['total']} as expected, "
              f"Gobo {area['gobo']['pass']}/{area['gobo']['total']}; Gobo timeout/crash/exception: "
              f"{', '.join(area['gobo']['timeout_crash_exception']) or 'none'}\n")
    table("Security and limits (expected = what a safe Expat-compatible parser does)", ["Case", "Expected", "xpact", "Gobo"], rows)

# 11 large files (whole and 64 KB pieces; Gobo always whole: it cannot take pieces)
lx_, lg_ = tsv("11-large-real-files/logs/large-xpact.tsv"), tsv("11-large-real-files/logs/large-gobo.tsv")
if lx_ and lg_:
    rows = []
    for a, b in zip(lx_, lg_):
        if a["mode"] == "whole":
            rows.append([a["file"], a["handlers"], f"{a['xpact']} {a['xpact_s']} s", f"{b['xpact']} {b['xpact_s']} s",
                         f"{float(b['xpact_s']) / float(a['xpact_s']):.1f}x" if a["xpact"] == "ACCEPT" == b["xpact"] else "-"])
    OUT["11_large_files"] = {"rows": rows}
    table("Large files, whole document (seconds incl. harness)", ["File", "Handlers", "xpact", "Gobo", "Gobo / xpact time"], rows)

# Speed (speed.py: Eiffel process timings, median of 3)
sp = js("speed.json")
if sp:
    OUT["speed"] = sp
    table("Speed per document (ms; Eiffel processes, start-up removed, median of 3)",
          ["File", "xpact ms", "Gobo ms", "Expat (pyexpat) ms", "Gobo / xpact", "Gobo verdict"],
          [[r["file"], r["xpact_ms"], r["gobo_ms"], r["expat_ms"], f"{r['gobo_over_xpact']}x", r["gobo_verdict"]] for r in sp])

(H / "results.json").write_text(json.dumps(OUT, indent=1), encoding="utf-8")
(H / "results.md").write_text("\n".join(md) + "\n", encoding="utf-8")
print("\n".join(md))
