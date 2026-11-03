"""Test 2: every W3C document whole vs byte by byte vs split at every byte, through xpact.dll and Expat.

A case is "unstable" for an engine when any chunked parse gives a different
verdict, error code or event list than the whole-document parse.
Usage: python run.py [--dll path] [--tag name] [--max-split-size 4096] [--jobs N]

Cases run on --jobs threads (default: one per CPU), each with its own xpact and Expat
worker process. Rows are written in suite order, so the output does not depend on --jobs.
"""
import argparse
import csv
import json
import os
import sys
import threading
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent / "issue-0154" / "tools" / "harness"))
from pool import Pool  # noqa: E402
import w3c  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("--dll")
ap.add_argument("--tag", default="xpact")
ap.add_argument("--max-split-size", type=int, default=4096)
ap.add_argument("--jobs", type=int, default=os.cpu_count() or 1)
args = ap.parse_args()
out = HERE / "logs"
out.mkdir(exist_ok=True)

local = threading.local()
all_pools, pools_lock = [], threading.Lock()


def worker_pools():
    # Pool is not thread-safe: every thread gets its own pair of worker processes.
    if not hasattr(local, "pools"):
        local.pools = (("xpact", Pool("xpact", timeout=300, dll=args.dll)), ("expat", Pool("expat", timeout=300)))
        with pools_lock:
            all_pools.extend(pool for _, pool in local.pools)
    return local.pools


def run_case(case):
    job = {"file": str(case.path), "entity_root": str(w3c.SUITE), "namespaces": case.namespaces,
           "compare_splits": args.max_split_size}
    row = {"id": case.id, "lane": case.lane, "size": case.path.stat().st_size}
    for name, pool in worker_pools():
        r = pool.run(job)
        if r["verdict"] in ("CRASH", "TIMEOUT"):
            row[name] = r["verdict"]
        else:
            stable = r["byte_same"] and not r["bad_splits"]
            row[name] = "stable" if stable else "UNSTABLE"
            row[name + "_byte"] = "same" if r["byte_same"] else f"differs ({r['byte_verdict']})"
            row[name + "_bad_splits"] = " ".join(map(str, r["bad_splits"][:20])) + (
                f" ... ({len(r['bad_splits'])})" if len(r["bad_splits"]) > 20 else "")
    row["status"] = ("ok" if row["xpact"] == "stable" else
                     "both" if row["expat"] != "stable" else "xpact-only")
    return row


def estimated_cost(case):
    # A document up to --max-split-size is parsed once per split point (size^2 bytes);
    # a larger one only whole and byte by byte.
    size = case.path.stat().st_size
    return size * size if size <= args.max_split_size else size * 100


cases = [case for case, attrs in w3c.cases() if case.path.is_file()]
results = [None] * len(cases)
try:
    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as executor:
        # Start the most expensive cases first, so no long case is left running alone at the end.
        order = sorted(range(len(cases)), key=lambda i: estimated_cost(cases[i]), reverse=True)
        futures = {executor.submit(run_case, cases[i]): i for i in order}
        for future, i in futures.items():
            results[i] = future.result()
finally:
    for pool in all_pools:
        pool.close()

# Rows and printed lines in suite order: the output is the same for any --jobs.
rows, summary = [], {}
for row in results:
    summary[row["status"]] = summary.get(row["status"], 0) + 1
    rows.append(row)
    if row["status"] != "ok":
        print(row, flush=True)

fields = ["id", "lane", "size", "status", "xpact", "xpact_byte", "xpact_bad_splits", "expat", "expat_byte", "expat_bad_splits"]
with open(out / f"chunked-{args.tag}.tsv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fields, delimiter="\t", extrasaction="ignore")
    w.writeheader()
    w.writerows(rows)
summary["total"] = len(rows)
(out / f"chunked-{args.tag}-summary.json").write_text(json.dumps(summary, indent=2))
print(json.dumps(summary, indent=2))
