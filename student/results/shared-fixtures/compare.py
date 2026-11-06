"""Every shared fixture (manifest.tsv) through xpact.dll and Expat 2.8.1 (libexpat.dll), whole and in chunks.

Uses the G03 comparison unchanged (student/results/G03-comparison/compare.py): the same harness, the same 14
configurations (XML_Parse and XML_ParseBuffer x whole, 1, 2, 3, 7, 64, 1024 bytes), the same classification.
Only the manifest differs (mass-xpact #81).

Usage, from the repository root:
  python -I student/results/shared-fixtures/compare.py --tag <name> --xpact-dll <xpact.dll> --expat-dll <libexpat.dll>
Output: runs/<tag>/results.tsv, summary.json, differences/<set>/<id>.json. Exit 2 when a file or result is missing.
"""
import argparse
import csv
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(REPO / "student" / "results" / "G03-comparison"))
import compare as g03  # noqa: E402  (also puts the harness on sys.path)
from pool import Pool  # noqa: E402

CONFIGS, ENGINES = g03.CONFIGS, g03.ENGINES


def shorten(value, limit=300):
    """Cut long strings in a difference trace: one billion-laughs text event is hundreds of MB."""
    if isinstance(value, str) and len(value) > limit:
        return value[:limit] + f"... [{len(value):,} characters]"
    if isinstance(value, list):
        return [shorten(v, limit) for v in value]
    if isinstance(value, dict):
        return {k: shorten(v, limit) for k, v in value.items()}
    return value


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tag", required=True)
    ap.add_argument("--xpact-dll", type=Path, required=True)
    ap.add_argument("--expat-dll", type=Path, required=True)
    ap.add_argument("--manifest", type=Path, default=HERE / "manifest.tsv",
                    help="another manifest in the same format; runs/ is written next to it")
    ap.add_argument("--modes", default=",".join(g03.MODES),
                    help="chunk modes, e.g. whole,64,1024 for large files (default: the 7 G03 modes)")
    args = ap.parse_args()
    global CONFIGS
    CONFIGS = g03.CONFIGS = [(api, mode) for api in g03.APIS for mode in args.modes.split(",")]
    dlls = {"xpact": args.xpact_dll.resolve(), "expat": args.expat_dll.resolve()}
    manifest_path = args.manifest.resolve()
    out = manifest_path.parent / "runs" / args.tag
    out.mkdir(parents=True, exist_ok=True)
    with manifest_path.open(encoding="utf-8") as f:
        manifest = list(csv.DictReader(f, delimiter="\t"))
    problems = [f"{m['id']}: hash differs" for m in manifest
                if hashlib.sha256((REPO / m["path"]).read_bytes()).hexdigest() != m["sha256"]]
    if problems:
        print("\n".join(problems))
        return 2
    rows = []
    pools = {e: Pool("xpact", timeout=120, dll=dlls[e]) for e in ENGINES}
    try:
        for m in manifest:
            res = {e: {} for e in ENGINES}
            for e in ENGINES:
                for api, mode in CONFIGS:
                    r = pools[e].run({"file": str(REPO / m["path"]), "entity_root": str(REPO / m["entity_root"]),
                                      "namespaces": m["namespaces"] == "on",
                                      "split": None if mode == "whole" else f"every:{mode}", "api": api})
                    if "verdict" not in r:
                        problems.append(f"{m['id']} {e} {g03.config_name(api, mode)}: no result")
                        r = {"verdict": "MISSING"}
                    res[e][(api, mode)] = r
            status, bad = g03.classify(res)
            whole = {e: res[e][("parse", "whole")] for e in ENGINES}
            stable = {e: all(g03.key(res[e][c]) == g03.key(whole[e]) for c in CONFIGS) for e in ENGINES}
            exp = m["expected"]
            rows.append({"id": m["id"], "set": m["set"], "finding": m["finding"], "expected": exp, "status": status,
                         "xpact": whole["xpact"]["verdict"], "expat": whole["expat"]["verdict"],
                         "xpact_error": whole["xpact"].get("error"), "expat_error": whole["expat"].get("error"),
                         "xpact_vs_expected": "" if not exp else ("pass" if whole["xpact"]["verdict"] == exp else "FAIL"),
                         "xpact_same_in_all_chunkings": "yes" if stable["xpact"] else "NO",
                         "expat_same_in_all_chunkings": "yes" if stable["expat"] else "NO",
                         "configs_differing": len(bad), "first_configs": "; ".join(bad[:3]),
                         "pairs_same": sum(g03.key(res["xpact"][c]) == g03.key(res["expat"][c]) for c in CONFIGS)})
            if status != "match" or not all(stable.values()):
                d = out / "differences" / m["set"]
                d.mkdir(parents=True, exist_ok=True)
                trace = {"id": m["id"], "status": status, "whole": {e: g03.brief(whole[e]) for e in ENGINES},
                         "configs": {g03.config_name(*c): {"xpact": g03.brief(res["xpact"][c]),
                                                           "expat": g03.brief(res["expat"][c]),
                                                           "first_event_difference": g03.first_difference(res["xpact"][c], res["expat"][c])}
                                     for c in CONFIGS if g03.key(res["xpact"][c]) != g03.key(res["expat"][c])}}
                (d / (Path(m["id"]).name + ".json")).write_text(json.dumps(shorten(trace), indent=1), encoding="utf-8")
    finally:
        for p in pools.values():
            p.close()
    sets = {}
    for r in rows:
        s = sets.setdefault(r["set"], {"fixtures": 0, "match": 0, "verdict same (whole)": 0, "pairs": 0,
                                       "pairs same": 0, "xpact stable": 0, "expat stable": 0, "status": {}})
        s["fixtures"] += 1
        s["match"] += r["status"] == "match"
        s["verdict same (whole)"] += r["xpact"] == r["expat"]
        s["pairs"] += len(CONFIGS)
        s["pairs same"] += r["pairs_same"]
        s["xpact stable"] += r["xpact_same_in_all_chunkings"] == "yes"
        s["expat stable"] += r["expat_same_in_all_chunkings"] == "yes"
        s["status"][r["status"]] = s["status"].get(r["status"], 0) + 1
    summary = {"tag": args.tag, "engines": {e: g03.describe(dlls[e]) for e in ENGINES}, "fixtures": len(rows),
               "parses": len(rows) * len(CONFIGS) * len(ENGINES), "sets": sets,
               "expected": {k: sum(r["xpact_vs_expected"] == k for r in rows) for k in ("pass", "FAIL")},
               "problems": problems}
    with (out / "results.tsv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, list(rows[0]), delimiter="\t")
        w.writeheader()
        w.writerows(rows)
    (out / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(f"{len(rows)} fixtures, {summary['parses']} parses, problems {len(problems)}, "
          f"expected pass {summary['expected']['pass']} FAIL {summary['expected']['FAIL']}")
    for k, s in sets.items():
        print(f"  {k}: {s['fixtures']} | match {s['match']} | verdict same {s['verdict same (whole)']} | "
              f"pairs same {s['pairs same']}/{s['pairs']} | xpact stable {s['xpact stable']} | {s['status']}")
    return 2 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
