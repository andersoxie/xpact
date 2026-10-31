"""Re-score A04 runs from the saved watch.json with the fixed library filter.

Each load is identified against the library hashes recorded right after that runner
(results.json library_hashes, 16 hex digits), not against today's files: chunked-crc and
shim-audit rebuild build\\native-eiffel\\xpact.dll.
"""
import csv
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import run_a04 as A  # noqa: E402

results = json.loads((HERE / "results.json").read_text(encoding="utf-8"))
for rid, what, config, expected, command in A.RUNNERS:
    r = results[rid]
    watch = json.loads((A.OUT / rid / "watch.json").read_text(encoding="utf-8"))
    known = {v: k for k, v in r["library_hashes"].items() if v}
    loads = []
    for proc in watch["processes"]:
        for dll in proc["dlls"]:
            base = Path(dll).name.lower()
            if base in ("xpact.dll", "xpact_assertions.dll") or base.startswith("libexpat") and base.endswith(".dll"):
                digest = watch["files"].get(dll, {}).get("sha256")
                loads.append((proc["image"], dll, known.get((digest or "")[:16], "unknown"), digest))
    observed = {c for _, _, c, _ in loads}
    if expected is None:
        verdict = "ok" if "unknown" not in observed and "bridge-only" not in observed else "MISMATCH"
    else:
        verdict = "ok" if observed == expected else "MISMATCH"
    A.keep_evidence(rid, command, watch, loads, A.OUT / rid, HERE / "runs" / rid)
    r.update({"what": what, "configuration": config,
              "expected": ["any known build"] if expected is None else sorted(expected) or ["no xpact DLL"],
              "observed": sorted(observed) or ["no xpact DLL"], "verdict": verdict,
              "loads": sorted({A.load_line(i, d, c, s) for i, d, c, s in loads})})
    print(f"{rid:26} {verdict:8} expected {r['expected']} observed {r['observed']} exit {r['exit_code']}")
(HERE / "results.json").write_text(json.dumps(results, indent=1), encoding="utf-8")
order = [x[0] for x in A.RUNNERS]
with (HERE / "results.tsv").open("w", newline="", encoding="utf-8") as f:
    w = csv.writer(f, delimiter="\t")
    w.writerow(["id", "runner", "configuration", "expected", "observed", "verdict", "exit_code", "seconds", "processes"])
    for rid in order:
        r = results[rid]
        w.writerow([rid, r["what"], r["configuration"], " + ".join(r["expected"]), " + ".join(r["observed"]),
                    r["verdict"], r["exit_code"], r["seconds"], r["processes"]])
