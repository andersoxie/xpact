"""G03: the G01 cases through xpact.dll and Expat 2.8.1 (libexpat.dll), whole and in chunks.

Both DLLs are driven by the same code (reports/issue-0154/tools/harness, Expat C API
through ctypes, each in its own child process), with the same configuration:
namespaces as in the W3C catalog, external entities loaded from the suite folder only,
parameter entity parsing always on.

Every case is parsed with XML_Parse and with XML_GetBuffer + XML_ParseBuffer, whole and
in chunks of 1, 2, 3, 7, 64 and 1024 bytes (14 configurations per engine). A configuration
matches when both engines give the same verdict, error code and events.

Usage:
  python -I compare.py --tag <name> [--xpact-dll path] [--expat-dll path]
Output: runs/<tag>/results.tsv, summary.json, differences/<id>.json
Exit status: 0 when every row is present and every total reconciles (differences are data,
not a failure); 2 when a manifest row, a file or a result is missing.
"""
from __future__ import annotations

import argparse
import csv
import ctypes
import hashlib
import json
import platform
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(REPO / "reports" / "issue-0154" / "tools" / "harness"))
from pool import Pool  # noqa: E402
import w3c  # noqa: E402

MANIFEST = REPO / "student" / "results" / "G01-corpus" / "manifest.tsv"
DEFAULT_XPACT = REPO / "build" / "native-eiffel" / "xpact_assertions.dll"
DEFAULT_EXPAT = REPO.parent / "xpactGit" / "build" / "libexpat-R_2_8_1" / "build" / "libexpat.dll"
APIS = ("parse", "buffer")
MODES = ("whole", "1", "2", "3", "7", "64", "1024")
CONFIGS = [(api, mode) for api in APIS for mode in MODES]
ENGINES = ("xpact", "expat")


def config_name(api, mode):
    return f"{'XML_Parse' if api == 'parse' else 'XML_ParseBuffer'} {mode}"


def describe(dll: Path):
    lib = ctypes.CDLL(str(dll))
    lib.XML_ExpatVersion.restype = ctypes.c_char_p
    data = dll.read_bytes()
    return {"path": str(dll), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "XML_ExpatVersion": lib.XML_ExpatVersion().decode()}


def key(r):
    return r["verdict"], r.get("error"), r.get("events")


def first_difference(a, b):
    ea, eb = a.get("events") or [], b.get("events") or []
    i = next((k for k, (x, y) in enumerate(zip(ea, eb)) if x != y), min(len(ea), len(eb)))
    return {"index": i, "events_a": ea[max(0, i - 2):i + 3], "events_b": eb[max(0, i - 2):i + 3],
            "count_a": len(ea), "count_b": len(eb)}


def brief(r):
    return {k: r.get(k) for k in ("verdict", "error", "message", "line", "column", "exit_hex")}


def classify(res):
    """Case status, worst first, and the configurations that differ."""
    if any(res[e][c]["verdict"] in ("CRASH", "TIMEOUT") for e in ENGINES for c in CONFIGS):
        return "crash or timeout", [config_name(*c) for c in CONFIGS
                                    if {res[e][c]["verdict"] for e in ENGINES} & {"CRASH", "TIMEOUT"}]
    for status, test in (("verdict differs", lambda a, b: a["verdict"] != b["verdict"]),
                         ("error code differs", lambda a, b: a["error"] != b["error"]),
                         ("events differ", lambda a, b: a["events"] != b["events"]),
                         ("error position differs", lambda a, b: a["verdict"] == "REJECT"
                          and (a["line"], a["column"]) != (b["line"], b["column"]))):
        bad = [config_name(*c) for c in CONFIGS if test(res["xpact"][c], res["expat"][c])]
        if bad:
            return status, bad
    return "match", []


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tag", required=True)
    ap.add_argument("--xpact-dll", type=Path, default=DEFAULT_XPACT)
    ap.add_argument("--expat-dll", type=Path, default=DEFAULT_EXPAT)
    args = ap.parse_args()
    dlls = {"xpact": args.xpact_dll.resolve(), "expat": args.expat_dll.resolve()}
    out = HERE / "runs" / args.tag
    (out / "differences").mkdir(parents=True, exist_ok=True)
    problems = []

    with MANIFEST.open(encoding="utf-8") as f:
        manifest = list(csv.DictReader(f, delimiter="\t"))
    catalog = {case.id: case for case, _ in w3c.cases()}
    for row in manifest:
        case = catalog.get(row["id"])
        if case is None:
            problems.append(f"{row['id']}: not in the W3C catalog")
        elif hashlib.sha256(case.path.read_bytes()).hexdigest() != row["sha256"]:
            problems.append(f"{row['id']}: file hash differs from the G01 manifest")
    if problems:
        print("\n".join(problems))
        return 2

    rows = []
    pools = {e: Pool("xpact", timeout=120, dll=dlls[e]) for e in ENGINES}
    try:
        for n, row in enumerate(manifest, 1):
            case = catalog[row["id"]]
            res = {e: {} for e in ENGINES}
            for e in ENGINES:
                for api, mode in CONFIGS:
                    job = {"file": str(case.path), "entity_root": str(w3c.SUITE), "namespaces": case.namespaces,
                           "split": None if mode == "whole" else f"every:{mode}", "api": api}
                    r = pools[e].run(job)
                    if "verdict" not in r:
                        problems.append(f"{row['id']} {e} {config_name(api, mode)}: no result")
                    res[e][(api, mode)] = r
            status, bad = classify(res)
            whole = {e: res[e][("parse", "whole")] for e in ENGINES}
            expected = row["expected"]
            counted = row["counted"] == "yes"

            def against(r):
                return ("pass" if r["verdict"] == expected else "FAIL") if counted else "not counted"

            stable = {e: all(key(res[e][c]) == key(whole[e]) for c in CONFIGS) for e in ENGINES}
            rows.append({"id": row["id"], "type": row["type"], "expected": expected,
                         "counted": "yes" if counted else "no", "namespaces": "on" if case.namespaces else "off",
                         "status": status, "xpact": whole["xpact"]["verdict"], "expat": whole["expat"]["verdict"],
                         "xpact_vs_expected": against(whole["xpact"]), "expat_vs_expected": against(whole["expat"]),
                         "xpact_error": whole["xpact"].get("error"), "expat_error": whole["expat"].get("error"),
                         "xpact_same_in_all_chunkings": "yes" if stable["xpact"] else "NO",
                         "expat_same_in_all_chunkings": "yes" if stable["expat"] else "NO",
                         "configs_differing": len(bad), "first_configs": "; ".join(bad[:3]),
                         "_res": res})
            if status != "match" or not all(stable.values()) or "FAIL" in (rows[-1]["xpact_vs_expected"],
                                                                         rows[-1]["expat_vs_expected"]):
                trace = {"id": row["id"], "path": str(case.path.relative_to(w3c.SUITE)), "expected": expected,
                         "counted": counted, "namespaces": case.namespaces, "status": status,
                         "whole": {e: whole[e] for e in ENGINES}, "configs": {}}
                for c in CONFIGS:
                    a, b = res["xpact"][c], res["expat"][c]
                    if key(a) != key(b) or (a["verdict"] == "REJECT" and (a.get("line"), a.get("column"))
                                            != (b.get("line"), b.get("column"))):
                        trace["configs"][config_name(*c)] = {"xpact": brief(a), "expat": brief(b),
                                                             "first_event_difference": first_difference(a, b)}
                for e in ENGINES:
                    trace[f"{e}_chunkings_unlike_whole"] = {
                        config_name(*c): brief(res[e][c]) | {"vs_whole": first_difference(whole[e], res[e][c])}
                        for c in CONFIGS if key(res[e][c]) != key(whole[e])}
                (out / "differences" / f"{row['id']}.json").write_text(json.dumps(trace, indent=1),
                                                                        encoding="utf-8")
            print(f"{n:3}/{len(manifest)} {row['id']}: {status}", flush=True)
    finally:
        for p in pools.values():
            p.close()

    # Totals, each checked against the number of cases.
    total = len(rows)
    by_config = {e: {config_name(*c): {} for c in CONFIGS} for e in ENGINES}
    for r in rows:
        for e in ENGINES:
            for c in CONFIGS:
                v = r["_res"][e][c]["verdict"]
                d = by_config[e][config_name(*c)]
                d[v] = d.get(v, 0) + 1
    for e in ENGINES:
        for name, d in by_config[e].items():
            if sum(d.values()) != total:
                problems.append(f"{e} {name}: {sum(d.values())} results for {total} cases")
    pair_same = sum(key(r["_res"]["xpact"][c]) == key(r["_res"]["expat"][c]) for r in rows for c in CONFIGS)
    status_counts = {}
    for r in rows:
        k = (r["status"], r["counted"])
        status_counts[k] = status_counts.get(k, 0) + 1
    vs_expected = {}
    for e in ENGINES:
        for r in rows:
            k = (e, r["expected"], r[f"{e}_vs_expected"])
            vs_expected[k] = vs_expected.get(k, 0) + 1
    if sum(status_counts.values()) != total:
        problems.append("status counts do not add up")
    commit = subprocess.run(["git", "-C", str(REPO), "rev-parse", "--short", "HEAD"], capture_output=True,
                            text=True).stdout.strip()
    summary = {"tag": args.tag, "commit": commit, "python": platform.python_version(),
               "engines": {e: describe(dlls[e]) for e in ENGINES}, "cases": total,
               "counted": sum(r["counted"] == "yes" for r in rows),
               "configurations_per_engine": len(CONFIGS), "parses": total * len(CONFIGS) * len(ENGINES),
               "config_pairs": total * len(CONFIGS), "config_pairs_same": pair_same,
               "status": {f"{s} / counted={c}": n for (s, c), n in sorted(status_counts.items())},
               "vs_expected_whole": {f"{e} expected={x} {o}": n for (e, x, o), n in sorted(vs_expected.items())},
               "verdicts_by_config": by_config,
               "same_in_all_chunkings": {e: sum(r[f"{e}_same_in_all_chunkings"] == "yes" for r in rows)
                                         for e in ENGINES},
               "problems": problems}
    fields = [k for k in rows[0] if not k.startswith("_")]
    with (out / "results.tsv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fields, delimiter="\t", extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)
    (out / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps({k: summary[k] for k in ("cases", "counted", "parses", "config_pairs", "config_pairs_same",
                                               "status", "vs_expected_whole", "same_in_all_chunkings",
                                               "problems")}, indent=2))
    return 2 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
