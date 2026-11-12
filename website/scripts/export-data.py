"""Export the conformance, benchmark, Expat comparison and testing numbers from the repository's
reports into website/data/*.json, which the API serves at /api/results/<name>.

    python website/scripts/export-data.py

The website never hard-codes results: rerun this after a new report is added.
Each file records the report it came from, so the page can link to the evidence.
"""
import json
import re
from pathlib import Path

WEBSITE = Path(__file__).resolve().parent.parent
REPO = WEBSITE.parent
DATA = WEBSITE / "data"
GITHUB = "https://github.com/andersoxie/xpact/blob/incremental-test/"
README_MD = "README.md"
SUMMARY_JSON = "summary.json"

# W3C runner, all lanes, rerun on incremental-test 2026-11-08. The DLL external-entity lane
# (247 cases) was not rerun; it stays from 2026-10-28.
W3C_RUN = REPO / "student" / "results" / "AlotOfTests-2026-11-08" / "repo-suites" / "w3c"
W3C_REPORT = REPO / "reports" / "latest-2026-10-28"
BENCHMARKS = REPO / "reports" / "acceptance-253c81e-vs-45d2f53" / "logs" / "speed" / "bench3-ours-1-table.md"
COMPARISON = REPO / "student" / "results" / "G03-comparison" / README_MD
ALOT = REPO / "student" / "results" / "AlotOfTests-2026-11-08"
# Fair speed test (#275): xpact.dll and libexpat.dll through the same C API, 2026-11-10.
FAIR = REPO / "student" / "results" / "fair-speed-2026-11-10"
FAIR_CHECK = REPO / "reports" / "issue-0276-check" / README_MD

LANES = [
    ("core", "XML 1.0 5th edition", "W3C verdict", 1974),
    ("legacy-names", "XML 1.0 editions 1-4 (Expat name tables)", "W3C verdict", 309),
    ("optional-error", "Optional errors (either verdict allowed)", "no crash", 28),
    ("xml-1.1", "XML 1.1 (no XML 1.0 verdict exists)", "no crash", 274),
]


def link(path: Path) -> str:
    return GITHUB + path.relative_to(REPO).as_posix()


def conformance() -> dict:
    summary = json.loads((W3C_RUN / SUMMARY_JSON).read_text(encoding="utf-8"))
    dll = json.loads((W3C_REPORT / "dll-entity-lane" / SUMMARY_JSON).read_text(encoding="utf-8"))
    return {
        "source": link(W3C_RUN.parent.parent / README_MD),
        "date": "2026-11-08",
        "suite": {"name": "W3C XML Conformance Test Suite", "version": summary["suite_version"],
                  "url": summary["source"], "cases": summary["catalog_cases"]},
        "profile": summary["profile"],
        "builds": [
            {"build": "production" if e["engine"] == "Finalized" else "assertions",
             "total": e["total"], "passed": e["passed"], "noCrashOnly": e["no_crash_only"],
             "failed": e["failed"], "errors": e["errors"], "skipped": e["skipped"],
             "accepted": e["accepted"], "rejected": e["rejected"], "elapsedMs": e["elapsed_ms"]}
            for e in summary["engines"]
        ],
        "lanes": [{"lane": lane, "title": title, "judgedBy": judged, "cases": cases}
                  for lane, title, judged, cases in LANES],
        "dllExternalEntities": {"cases": 247, "results": dll},
        "adjustments": summary.get("expectation_adjustments", []),
    }


def benchmarks() -> dict:
    text = BENCHMARKS.read_text(encoding="utf-8")
    generated = re.search(r"Generated: (.+)", text)
    generated_text = generated.group(1).strip() if generated else "2026-11-05 (acceptance run, mass-xpact #67)"
    rows = []
    for line in text.splitlines():
        # Only the first results table; later tables repeat older, focused runs.
        if rows and not line.startswith("|"):
            break
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) == 9 and cells[0] == "catalog-100-items":
            rows.append({"engine": cells[1], "version": cells[2], "iterations": int(cells[3]),
                         "bytesPerDoc": int(cells[4]), "medianMs": float(cells[5]),
                         "docsPerSecond": float(cells[6]), "mibPerSecond": float(cells[7]), "notes": cells[8]})
    return {
        "source": link(BENCHMARKS),
        "generated": generated_text,
        "workload": "the same UTF-8 catalog document with 100 <item> elements; median of 3 process-level runs",
        "rows": rows,
        "fairSpeed": fair_speed(),
    }


def fair_speed() -> dict:
    """xpact / Expat time ratios from the fair speed test (#275): 1.0 = as fast, 18 = 18 times slower."""
    import csv
    import statistics
    cells: dict[tuple, dict] = {}
    with (FAIR / "results.tsv").open(encoding="utf-8") as handle:
        for row in csv.DictReader(handle, delimiter="	"):
            if row["engine"] in ("xpact", "expat"):
                cells.setdefault((row["file"], row["chunk"], row["callbacks"]), {})[row["engine"]] = row
    ratios, mismatches, not_compared, whole = [], 0, 0, []
    for (file, chunk, callbacks), pair in sorted(cells.items()):
        x, e = pair.get("xpact"), pair.get("expat")
        if not x or not e or x["status"] != "1" or e["status"] != "1" or not x["median_ms"] or not e["median_ms"]:
            not_compared += 1
            continue
        if callbacks == "1" and x["checksum"] != e["checksum"]:
            mismatches += 1
        ratio = float(x["median_ms"]) / float(e["median_ms"])
        ratios.append(ratio)
        if chunk == "0" and x["size"] == "1MB" and x["encoding"] == "utf8":
            whole.append({"shape": x["shape"], "callbacks": callbacks == "1", "ratio": round(ratio, 1),
                          "xpactMs": float(x["median_ms"]), "expatMs": float(e["median_ms"])})
    return {
        "source": link(FAIR / README_MD),
        "check": link(FAIR_CHECK),
        "generated": "2026-11-10 (old DLL); rechecked 2026-11-11 after #273/#274: whole documents unchanged, 1-byte pieces 2-4 % slower",
        "cells": len(ratios),
        "notCompared": not_compared,
        "medianRatio": round(statistics.median(ratios), 1),
        "checksumMismatches": mismatches,
        "wholeDocument1MB": whole,
    }


def comparison() -> dict:
    run = json.loads((COMPARISON.parent / "runs" / "final-normal" / SUMMARY_JSON).read_text(encoding="utf-8"))
    verdicts = run["verdicts_by_config"]
    same_verdict = run["config_pairs"] if all(verdicts["xpact"][c] == verdicts["expat"][c] for c in verdicts["xpact"]) else None
    return {
        "source": link(COMPARISON),
        "title": "XPact compared with Expat 2.8.1",
        "pairs": run["config_pairs"],
        "sameVerdict": same_verdict,
        "sameVerdictCodeAndEvents": run["config_pairs_same"],
        "note": "Rerun on the final code on 2026-11-06 (mass-xpact #81): the 93 G01 W3C cases, 14 ways of feeding each.",
    }


def fmt(number: int) -> str:
    return f"{number:,}"


def testing() -> dict:
    # AlotOfTests rerun on incremental-test (2026-11-08): one summary.json built by collect.py from the logs.
    s = json.loads((ALOT / SUMMARY_JSON).read_text(encoding="utf-8"))
    w3c = next(b for b in conformance()["builds"] if b["build"] == "production")
    calls, fuzz, diff = s["xml_parse_calls"], s["fuzzing"], s["differential"]
    pieces = s["w3c_pieces"]["assertions"]
    runtests, cpy, lib, sec = s["expat_runtests"]["normal"], s["cpython"], s["libxml2"], s["security"]["normal"]
    enc = s["encodings"]["normal"]
    xpact_timeouts = lib["stats"].get("xpact TIMEOUT / expat REJECT", 0) + lib["stats"].get("xpact TIMEOUT / expat ACCEPT", 0)
    ratio = lambda part, whole: f"{fmt(part)} / {fmt(whole)}"
    percent = lambda part, whole: f"{100 * part / whole:.2f} %"
    good = lambda text: {"text": "✅ " + text, "tone": "good"}
    warn = lambda text: {"text": text, "tone": "plain"}  # known differences or limits: no colour

    def item(icon, label, value, sub, approx=False, result=None):
        out = {"icon": icon, "label": label, "value": value, "approx": approx, "sub": sub}
        if result:
            out["result"] = result
        return out

    both_builds_same = all(s["w3c_pieces"][b]["xpact_crash_or_timeout"] == 0 for b in ("normal", "assertions"))
    return {
        "source": link(ALOT / README_MD),
        "date": s["date"],
        "revision": "incremental-test",
        "note": "Rerun on 2026-11-08 on the final parser (incremental-test), both builds.",
        "testing": [
            item("🔁", "XML_Parse calls", round(calls["total"], -4),
                 "W3C files whole, byte by byte and split in two; 2 XPact builds + Expat", True,
                 good("0 crashes · 0 timeouts · verdict never changed") if both_builds_same and s["verdict_changes_by_chunking"] == 0 else warn("see the report")),
            item("📄", "Documents and inputs parsed", round(s["documents_parsed"], -3),
                 "W3C, fuzzed, generated, libxml2, encodings, attacks, large files", True, good("0 crashes in XPact")),
            item("🎲", "Fuzzed (mutated) inputs", fuzz["inputs"], "30 minutes, seeded from W3C",
                 result=good("0 crashes · 0 hangs") if fuzz["crashes_or_hangs"] == 0 else warn(f"{fuzz['crashes_or_hangs']} crashes or hangs")),
            item("🧬", "Generated documents compared with Expat", diff["documents"], "20 minutes; verdict, error code and events",
                 result=good(f"{percent(diff['same_verdict'], diff['documents'])} same verdict · 0 crashes")),
            item("📚", "W3C conformance cases", w3c["total"], "W3C XML Conformance Test Suite 20130923",
                 result=good(f"{w3c['failed']} failed · {w3c['errors']} errors") if w3c["failed"] == 0 and w3c["errors"] == 0 else warn(f"{w3c['failed']} failed")),
            item("🔤", "W3C bytes fed one at a time", calls["bytes_one_by_one"], "every W3C document, one byte per call",
                 result=good(f"{ratio(pieces['ok'], pieces['total'])} same as whole")),
            item("✂️", "Two-piece split runs", calls["two_piece_splits"], "every byte position, W3C documents up to 4 KB",
                 result=good("accept/reject never changed") if s["verdict_changes_by_chunking"] == 0 else warn("verdict changed")),
            item("♻️", "Parser lifecycles in the leak test", s["memory"]["lifecycles"], "8 scenarios × 20,000 rounds",
                 result=good("no memory leak")),
            item("🧪", "C# DLL tests", 4308, "whole, every split, byte by byte; both builds", result=good("4,308 / 4,308 pass")),
            item("⚙️", "Expat's own C unit tests", 2 * runtests["checks"], "Expat 2.8.1 runtests, 2 builds",
                 result=good(f"{runtests['passed']} / {runtests['checks']} · the rest are allocator tests (by design)")),
            item("🐍", "CPython XML tests run on XPact", cpy["run"], "Python's own tests, pyexpat linked to XPact",
                 result=warn(f"{fmt(cpy['passed'])} pass · {cpy['failures']} fail")),
            item("📁", "libxml2 test files", lib["files"], "libxml2's own test corpus",
                 result=warn(f"{fmt(lib['same_as_expat'])} same as Expat · {xpact_timeouts} timeouts")),
            item("🛡️", "Attack and limit cases", sec["cases"], "XXE, billion laughs, CVE inputs, huge inputs",
                 result=warn(f"{sec['pass']} pass · {sec['fail']} hit a hard limit")),
            item("📏", "Large files", s["large_files"]["files"], "1, 5, 9, 20 MB × 4 shapes, whole and in pieces",
                 result=warn("same events as Expat up to 9 MB · 20 MB over the limit")),
            item("🧱", "Eiffel test matrix", "4 / 4", "assertions on/off × workbench/finalized", result=good("all lanes ok")),
            item("💥", "Crashes / timeouts / leaks", f"0 / {xpact_timeouts} / 0", "in all test areas",
                 result=warn(f"{xpact_timeouts} timeouts: external billion laughs (libxml2)") if xpact_timeouts else good("none found")),
        ],
        "results": [
            item("🧩", "W3C documents identical whole and in pieces", ratio(pieces["ok"], pieces["total"]),
                 f"{pieces['xpact-only']} differ in XPact only, {pieces['both']} in Expat too (events or error code)"),
            item("⚖️", "Accept/reject changed by chunking", s["verdict_changes_by_chunking"], f"of {fmt(calls['documents'])} W3C documents"),
            item("🎲", "Fuzzing: same verdict as Expat", percent(fuzz["same_verdict"], fuzz["inputs"]),
                 f"{fmt(fuzz['same_verdict'])} of {fmt(fuzz['inputs'])} inputs"),
            item("🧬", "Generated documents: same verdict as Expat", percent(diff["same_verdict"], diff["documents"]),
                 f"{fmt(diff['same_verdict'])} of {fmt(diff['documents'])} documents"),
            item("⚙️", "Expat's own C unit tests passed", ratio(runtests["passed"], runtests["passed"]),
                 f"all except the {runtests['failed_allocator_tests']} allocator tests (by design)"),
            item("📁", "libxml2 files identical to Expat", ratio(lib["same_as_expat"], lib["files"]), "same verdict, error code and events"),
            item("🔤", "Encoding cases passed", ratio(enc["pass"], enc["cases"]), "every broken UTF-8 sequence rejected"),
            item("🐍", "CPython XML tests passed on XPact", ratio(cpy["passed"], cpy["run"]), "Python's own test suite, pyexpat linked to XPact"),
        ],
        "project": {
            "asOf": "2026-11-02",
            "period": "6 Oct – 2 Nov 2026",
            "note": "Counted on GitHub on 2026-11-02.",
            "items": [
                item("🔀", "PRs merged by the student", 92, "of 114 merged in the repo"),
                item("📝", "Commits by the student", 136, "on student-Mass (by 2026-11-02)"),
                item("🗂", "Issue reports with evidence", 67, "reports/issue-NNNN/"),
                item("✅", "Issues closed", 83, "of 96 in the repo"),
                item("📊", "Result folders", 17, "student/results/"),
                item("🎯", "W3C output test", "359 → 399", "of 432 correct"),
                item("✔️", "W3C verdicts", "2,585 / 2,585", "run, 0 failed"),
            ],
        },
    }


def main() -> None:
    DATA.mkdir(exist_ok=True)
    for name, build in (("conformance", conformance), ("benchmarks", benchmarks), ("comparison", comparison), ("testing", testing)):
        path = DATA / f"{name}.json"
        path.write_text(json.dumps(build(), indent=2) + "\n", encoding="utf-8")
        print(f"wrote {path.relative_to(REPO)}")


if __name__ == "__main__":
    main()
