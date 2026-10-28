"""Test 1b: the verdict of every W3C case through xpact.dll (Expat API, external entities on).

The Jenkins W3C run uses the Eiffel executable; the DLL entity lane covers 247 cases.
This runs all 2,585 through the DLL and Expat with the same loader and compares
with the runner's expectation (core and legacy-names lanes; "ANY" lanes only no-crash).
"""
import csv
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "harness"))
from pool import Pool  # noqa: E402
import w3c  # noqa: E402

dll = sys.argv[1] if len(sys.argv) > 1 else None
tag = sys.argv[2] if len(sys.argv) > 2 else "xpact"
out = Path(sys.argv[3]) if len(sys.argv) > 3 else HERE / "logs"
out.mkdir(exist_ok=True)
rows, summary = [], {}
with Pool("xpact", dll=dll) as xp, Pool("expat") as ex:
    for case, attrs in w3c.cases():
        expected = case.expected if not case.skip_reason else case.lane_expected
        if not case.path.is_file():
            continue
        job = {"file": str(case.path), "entity_root": str(w3c.SUITE), "namespaces": case.namespaces,
               "keep_events": False}
        x, e = xp.run(job), ex.run(job)
        if x["verdict"] in ("CRASH", "TIMEOUT"):
            status = x["verdict"].lower()
        elif expected == "ANY":
            status = "no-crash"
        else:
            status = "pass" if x["verdict"] == expected else "fail"
        rows.append({"id": case.id, "lane": case.lane, "type": case.kind, "expected": expected,
                     "xpact": x["verdict"], "expat": e["verdict"], "status": status,
                     "xpact_message": x.get("message", x.get("exit_hex", "")), "expat_message": e.get("message", "")})
        key = f"{case.lane}:{status}"
        summary[key] = summary.get(key, 0) + 1
with open(out / f"verdicts-{tag}.tsv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, list(rows[0]), delimiter="\t")
    w.writeheader()
    w.writerows(rows)
summary["total"] = len(rows)
(out / f"verdicts-{tag}-summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True))
print(json.dumps(summary, indent=2, sort_keys=True))
