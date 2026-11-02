"""Test 2b: for every case that is unstable in xpact only, say WHAT changes when it is fed byte by byte
(or at the first bad split point): the verdict, only the error code, or only the events.
"""
import csv
import json
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "harness"))
from pool import Pool  # noqa: E402
import w3c  # noqa: E402

tag = sys.argv[1] if len(sys.argv) > 1 else "xpact"
rows = {r["id"]: r for r in csv.DictReader(open(HERE / "logs" / f"chunked-{tag}.tsv", encoding="utf-8"), delimiter="\t")}
cases = {c.id: c for c, _ in w3c.cases()}
out, kinds = [], Counter()
with Pool("xpact", timeout=120) as xp:
    for cid, row in rows.items():
        if row["status"] != "xpact-only" or row["xpact"] != "UNSTABLE":
            continue
        split = "byte" if row["xpact_byte"] != "same" else int(row["xpact_bad_splits"].split()[0])
        case = cases[cid]
        r = xp.run({"file": str(case.path), "entity_root": str(w3c.SUITE), "namespaces": case.namespaces,
                    "explain_split": split})
        if r.get("verdict") in ("CRASH", "TIMEOUT"):
            kind = r["verdict"]
        elif r["whole"][0] != r["split"][0]:
            kind = f"verdict {r['whole'][0]} -> {r['split'][0]}"
        elif r["whole"][1] != r["split"][1]:
            kind = "same verdict, other error code"
        else:
            kind = "same verdict, other events"
        kinds[kind] += 1
        out.append({"id": cid, "lane": row["lane"], "split": split, "kind": kind,
                    "whole": " / ".join(map(str, r.get("whole", []))), "chunked": " / ".join(map(str, r.get("split", []))),
                    "first_diff_whole": r.get("ev_whole", ""), "first_diff_chunked": r.get("ev_split", "")})
with open(HERE / "logs" / f"unstable-{tag}.tsv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, list(out[0]), delimiter="\t")
    w.writeheader()
    w.writerows(out)
print(json.dumps(kinds.most_common(), indent=1))
