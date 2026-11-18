"""Test 7: libxml2's own test files (download/libxml2/test, not committed) through xpact.dll and Expat.

libxml2 has no machine-readable expected verdicts for most files, so Expat is the reference:
verdict, error code, and the events when both accept. Differences are grouped by signature.
External entities: relative paths below the libxml2 test folder only. Files in test/namespaces
use the namespace parser.
Usage: python run.py [--dll path] [--tag xpact]
"""
import argparse
import csv
import json
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "harness"))
from pool import Pool  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("--dll")
ap.add_argument("--tag", default="xpact")
args = ap.parse_args()
root = HERE / "download" / "libxml2" / "test"
skip_dirs = {"HTML", "htmlParse", "html", "HTMLparser"}
files = sorted(p for p in root.rglob("*") if p.is_file() and not (set(p.relative_to(root).parts) & skip_dirs)
               and p.stat().st_size <= 2 * 2**20 and p.suffix.lower() not in {".c", ".h", ".py", ".sh", ".txt", ".md"})


def signature(x, e):
    if x["verdict"] in ("CRASH", "TIMEOUT"):
        return f"xpact {x['verdict']}"
    if x["verdict"] != e["verdict"]:
        return f"verdict: xpact {x['verdict']} ({x.get('message', '')}) / expat {e['verdict']} ({e.get('message', '')})"
    if x["verdict"] == "REJECT":
        return None if x["error"] == e["error"] else f"error code: xpact {x['message']} / expat {e['message']}"
    if x["events"] == e["events"]:
        return None
    i = next((k for k, (a, b) in enumerate(zip(x["events"], e["events"])) if a != b),
             min(len(x["events"]), len(e["events"])))
    xa = x["events"][i] if i < len(x["events"]) else ["(none)"]
    ea = e["events"][i] if i < len(e["events"]) else ["(none)"]
    field = ""
    if xa[0] == ea[0]:
        diff = [k for k, (p, q) in enumerate(zip(xa, ea)) if p != q]
        field = f" field {diff[0] if diff else 'count'}"
    return f"events: xpact {xa[0]} / expat {ea[0]}{field}"


rows, groups, examples, stats = [], Counter(), {}, Counter()
with Pool("xpact", timeout=20, dll=args.dll) as xp, Pool("expat", timeout=20) as ex:
    for path in files:
        rel = path.relative_to(root).as_posix()
        job = {"file": str(path), "entity_root": str(root), "namespaces": rel.startswith("namespaces/")}
        x, e = xp.run(job), ex.run(job)
        stats[f"xpact {x['verdict']} / expat {e['verdict']}"] += 1
        sig = signature(x, e)
        if sig:
            groups[sig] += 1
            examples.setdefault(sig, []).append(rel)
        rows.append({"file": rel, "xpact": x["verdict"], "expat": e["verdict"], "signature": sig or "same",
                     "xpact_message": x.get("message", x.get("exit_hex", "")), "expat_message": e.get("message", "")})
out = HERE / "logs"
out.mkdir(exist_ok=True)
with open(out / f"libxml2-{args.tag}.tsv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, list(rows[0]), delimiter="\t")
    w.writeheader()
    w.writerows(rows)
report = {"files": len(rows), "same": sum(r["signature"] == "same" for r in rows), "stats": stats,
          "groups": [{"signature": s, "count": n, "examples": examples[s][:8]} for s, n in groups.most_common()]}
(out / f"libxml2-{args.tag}-summary.json").write_text(json.dumps(report, indent=1, ensure_ascii=False), encoding="utf-8")
sys.stdout.reconfigure(encoding="utf-8")
print(json.dumps({k: report[k] for k in ("files", "same", "stats")}, indent=1))
for g in report["groups"]:
    print(f"{g['count']:5}  {g['signature']}\n         e.g. {', '.join(g['examples'][:4])}")
