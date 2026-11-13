"""Build summary.json for the 2026-11-08 AlotOfTests rerun from the logs in this folder.

python -I collect.py   (no arguments; reads */logs and console/, writes summary.json)
"""
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent


def tsv(path):
    lines = (HERE / path).read_text(encoding="utf-8").splitlines()
    head = lines[0].split("\t")
    return [dict(zip(head, line.split("\t"))) for line in lines[1:] if line]


def load(path):
    return json.loads((HERE / path).read_text(encoding="utf-8"))


def tail_json(path, opener="{"):
    """The last JSON block (opener at a line start) a script printed to its console."""
    text = "\n" + (HERE / path).read_text(encoding="utf-8", errors="replace")
    return json.loads(text[text.rindex("\n" + opener) + 1:])


def count(rows, key, value):
    return sum(row[key] == value for row in rows)


# 1. W3C output comparison and all verdicts through the DLL
out = {b: load(f"01-w3c-output-comparison/logs-it/{b}/summary.json") for b in ("normal", "assertions")}
verdicts = {b: load(f"01-w3c-output-comparison/logs/verdicts-{t}-summary.json") for b, t in (("normal", "it"), ("assertions", "it_assertions"))}

# 2. W3C in pieces
chunked = {b: tsv(f"02-w3c-chunked/logs/chunked-{t}.tsv") for b, t in (("normal", "it"), ("assertions", "it_assertions"))}
sizes = [int(r["size"]) for r in chunked["normal"]]
splits = sum(s - 1 for s in sizes if 1 < s <= 4096)
calls_per_run = len(sizes) + sum(sizes) + 2 * splits
pieces = {b: {"ok": count(rows, "status", "ok"), "xpact-only": count(rows, "status", "xpact-only"),
              "both": count(rows, "status", "both"), "total": len(rows),
              "xpact_crash_or_timeout": sum(r["xpact"] in ("CRASH", "TIMEOUT") for r in rows)}
          for b, rows in chunked.items()}
analyze = dict(tail_json("console/02-analyze.txt", "["))  # [[kind, n], ...]
verdict_changes = sum(n for kind, n in analyze.items() if "verdict" in kind and not kind.startswith("same verdict"))

# 3-4. Fuzzing and differential (time-boxed: 30 and 20 minutes, seed 1)
fuzz = load("03-fuzzing/logs/fuzz-it-seed1.json")
fuzz_same = fuzz["verdicts"].get("xpact REJECT / expat REJECT", 0) + fuzz["verdicts"].get("xpact ACCEPT / expat ACCEPT", 0)
diff_text = (HERE / "console/04-diff.txt").read_text(encoding="utf-8", errors="replace")
diff = json.loads(diff_text[: diff_text.index("\n}") + 2])
diff_same = diff["xpact REJECT / expat REJECT"] + diff["xpact ACCEPT / expat ACCEPT"]

# 5. Security and limits
security = {b: tsv(f"05-security-limits/logs/security-{t}.tsv") for b, t in (("normal", "it"), ("assertions", "it_assertions"))}

# 6. Expat's own unit tests
runtests = {}
for b, t in (("normal", "it"), ("assertions", "it_assertions")):
    log = (HERE / f"06-expat-runtests-parity/logs/{t}/libexpat-native-suite.log").read_text(encoding="utf-8", errors="replace")
    checks, failed = map(int, re.search(r"Checks: (\d+), Failed: (\d+)", log).groups())
    runtests[b] = {"checks": checks, "failed_allocator_tests": failed, "passed": checks - failed}

# 7. libxml2 corpus
libxml2 = load("07-libxml2-corpus/logs/libxml2-it-summary.json")

# 8. Encodings
encodings = {b: tsv(f"08-encodings/logs/encodings-{t}.tsv") for b, t in (("normal", "it"), ("assertions", "it_assertions"))}

# 10. CPython's XML tests on pyexpat linked to xpact
cpy = (HERE / "console/10-xpact.txt").read_text(encoding="utf-8", errors="replace")
run, failures, skipped = map(int, re.search(r"Total tests: run=(\d+) failures=(\d+) skipped=(\d+)", cpy).groups())

# 11. Large files
large = tsv("11-large-real-files/logs/large-it.tsv")

summary = {
    "date": "2026-11-08",
    "branch": "incremental-test",
    "w3c_output": out,
    "w3c_verdicts": verdicts,
    "w3c_pieces": pieces,
    "w3c_pieces_differences": analyze,
    "verdict_changes_by_chunking": verdict_changes,
    "xml_parse_calls": {"per_run": calls_per_run, "runs": 3, "total": 3 * calls_per_run,
                        "documents": len(sizes), "bytes_one_by_one": sum(sizes), "two_piece_splits": splits},
    "fuzzing": {"seconds": fuzz["seconds"], "inputs": fuzz["stats"]["inputs"], "same_verdict": fuzz_same,
                "crashes_or_hangs": len(fuzz["saved"]), "verdicts": fuzz["verdicts"]},
    "differential": {"seconds": 1200, "documents": diff["documents"], "same_verdict": diff_same, "verdicts": diff},
    "security": {b: {"cases": len(rows), "pass": count(rows, "status", "pass"), "fail": count(rows, "status", "FAIL")}
                 for b, rows in security.items()},
    "expat_runtests": runtests,
    "libxml2": {"files": libxml2["files"], "same_as_expat": libxml2["same"], "stats": libxml2["stats"]},
    "encodings": {b: {"cases": len(rows), "pass": count(rows, "status", "pass")} for b, rows in encodings.items()},
    "memory": {"scenarios": 8, "rounds": 20000, "lifecycles": 8 * 20000},
    "cpython": {"run": run, "failures": failures, "skipped": skipped, "passed": run - failures},
    "large_files": {"files": 16, "runs": len(large)},
}
summary["documents_parsed"] = (len(sizes) + summary["fuzzing"]["inputs"] + summary["differential"]["documents"]
                               + libxml2["files"] + len(encodings["normal"]) + len(security["normal"]) + 16)
(HERE / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
print(json.dumps({k: summary[k] for k in ("documents_parsed", "xml_parse_calls", "verdict_changes_by_chunking")}, indent=1))
