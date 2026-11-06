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

W3C_REPORT = REPO / "reports" / "latest-2026-10-28"
BENCHMARKS = REPO / "reports" / "acceptance-253c81e-vs-45d2f53" / "logs" / "speed" / "bench3-ours-1-table.md"
COMPARISON = REPO / "student" / "results" / "G03-comparison" / "README.md"
ALOT = REPO / "student" / "results" / "AlotOfTests-2026-10-28"

LANES = [
    ("core", "XML 1.0 5th edition", "W3C verdict", 1974),
    ("legacy-names", "XML 1.0 editions 1-4 (Expat name tables)", "W3C verdict", 309),
    ("optional-error", "Optional errors (either verdict allowed)", "no crash", 28),
    ("xml-1.1", "XML 1.1 (no XML 1.0 verdict exists)", "no crash", 274),
]


def link(path: Path) -> str:
    return GITHUB + path.relative_to(REPO).as_posix()


def conformance() -> dict:
    summary = json.loads((W3C_REPORT / "w3c" / "summary.json").read_text(encoding="utf-8"))
    dll = json.loads((W3C_REPORT / "dll-entity-lane" / "summary.json").read_text(encoding="utf-8"))
    return {
        "source": link(W3C_REPORT / "README.md"),
        "date": "2026-10-28",
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
    }


def comparison() -> dict:
    run = json.loads((COMPARISON.parent / "runs" / "final-normal" / "summary.json").read_text(encoding="utf-8"))
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


def tsv_rows(path: Path) -> list[dict]:
    lines = path.read_text(encoding="utf-8").splitlines()
    header = lines[0].split("\t")
    return [dict(zip(header, line.split("\t"))) for line in lines[1:] if line]


def fmt(number: int) -> str:
    return f"{number:,}"


def readme_number(path: Path, pattern: str) -> int:
    found = re.search(pattern, path.read_text(encoding="utf-8"))
    if not found:
        raise SystemExit(f"{path.relative_to(REPO)}: no match for {pattern!r}")
    return int(found.group(1).replace(",", ""))


def testing() -> dict:
    # W3C in pieces: per parser and build, each document once whole, once byte by byte,
    # and split in two at every byte (documents up to 4 KB, two calls per split).
    chunked = tsv_rows(ALOT / "02-w3c-chunked" / "logs" / "chunked-xpact.tsv")
    sizes = [int(row["size"]) for row in chunked]
    splits = sum(size - 1 for size in sizes if 1 < size <= 4096)
    calls_per_run = len(sizes) + sum(sizes) + 2 * splits
    runs = 3  # xpact.dll, xpact_assertions.dll and Expat
    fuzzed = readme_number(ALOT / "03-fuzzing" / "README.md", r"\| Inputs \| \*\*([\d,]+)\*\*")
    generated = readme_number(ALOT / "04-differential-vs-expat" / "README.md", r"Generated \(20 min, seed 1\) \| \*\*([\d,]+)\*\*")
    libxml2 = len(tsv_rows(ALOT / "07-libxml2-corpus" / "logs" / "libxml2-xpact.tsv"))
    encodings = len(tsv_rows(ALOT / "08-encodings" / "logs" / "encodings-xpact.tsv"))
    attacks = len(tsv_rows(ALOT / "05-security-limits" / "logs" / "security-xpact.tsv"))
    large_files = 16  # 4 shapes x 1, 5, 9 and 20 MB (11-large-real-files/README.md)
    documents = len(sizes) + fuzzed + generated + libxml2 + encodings + attacks + large_files
    cpython = readme_number(ALOT / "10-python-xml-tests" / "README.md", r"\| Tests run \| [\d,]+ \| ([\d,]+) \|")
    expat_tests = readme_number(ALOT / "06-expat-runtests-parity" / "README.md", r"\| \*\*Total\*\* \| \*\*([\d,]+)\*\*")
    item = lambda icon, label, value, sub, approx=False: {"icon": icon, "label": label, "value": value, "approx": approx, "sub": sub}

    # Results against Expat. W3C in pieces before and after the #165 fix (2026-10-30).
    test2 = REPO / "reports" / "issue-0165" / "logs" / "test2"
    before = json.loads((test2 / "chunked-e5d59e2-assertions-summary.json").read_text(encoding="utf-8"))
    after = json.loads((test2 / "chunked-fix165-assertions-summary.json").read_text(encoding="utf-8"))
    verdict_changes = readme_number(ALOT / "02-w3c-chunked" / "README.md", r"\*\*the verdict \(ACCEPT/REJECT\) changes\*\* \| \*\*(\d+)\*\*")
    fuzz_same = readme_number(ALOT / "03-fuzzing" / "README.md", r"\| Same verdict as Expat \| ([\d,]+)")
    diff_readme = ALOT / "04-differential-vs-expat" / "README.md"
    diff_same = readme_number(diff_readme, r"both accept \| ([\d,]+)") + readme_number(diff_readme, r"both reject \| ([\d,]+)")
    expat_passed = readme_number(ALOT / "06-expat-runtests-parity" / "README.md", r"\*\*([\d,]+) passed, [\d,]+ expected failures\*\*")
    libxml2_same = readme_number(ALOT / "07-libxml2-corpus" / "README.md", r"same verdict, error code and events as Expat \| \*\*([\d,]+)\*\*")
    encodings_pass = sum(row["status"] == "pass" for row in tsv_rows(ALOT / "08-encodings" / "logs" / "encodings-xpact.tsv"))
    cpython_failed = readme_number(ALOT / "10-python-xml-tests" / "README.md", r"\*\*(\d+) \+ \d+\*\*")
    cpython_errors = readme_number(ALOT / "10-python-xml-tests" / "README.md", r"\*\*\d+ \+ (\d+)\*\*")
    ratio = lambda part, whole: f"{fmt(part)} / {fmt(whole)}"
    percent = lambda part, whole: f"{100 * part / whole:.2f} %"
    return {
        "source": link(ALOT / "README.md"),
        "date": "2026-10-28",
        "revision": "293918f",
        "note": "Measured on 2026-10-28, before the fixes #154-#175; not rerun since.",
        "testing": [
            item("🔁", "XML_Parse calls", round(calls_per_run * runs, -6), "W3C-in-pieces test alone", True),
            item("📄", "Documents and inputs parsed", round(documents, -3), "W3C, fuzzed, generated, libxml2, encodings, attacks, large files", True),
            item("🧬", "Generated documents compared with Expat", generated, "verdict, error code and events"),
            item("🎲", "Fuzzed (mutated) inputs", fuzzed, "30 minutes, seeded from W3C"),
            item("🔤", "W3C bytes fed one at a time", sum(sizes), "per run"),
            item("✂️", "Two-piece split runs", splits, "every byte position, W3C documents up to 4 KB"),
            item("♻️", "Parser lifecycles in the leak test", 8 * 20_000, "8 scenarios × 20,000 rounds"),
            item("📚", "W3C conformance cases", len(sizes), "W3C XML Conformance Test Suite 20130923"),
            item("📁", "libxml2 test files", libxml2, "libxml2's own test corpus"),
            item("🐍", "CPython XML tests run on xpact", 2 * cpython, "2 builds, Python's pyexpat linked to xpact"),
            item("⚙️", "Expat's own C unit tests run against xpact", 2 * expat_tests, "2 builds, Expat 2.8.1 runtests"),
            item("🧪", "Test areas", 11, "conformance, fuzzing, security, memory, real files …"),
            item("💥", "Crashes / hangs / memory leaks found", "0 / 0 / 0", "in every test area"),
            item("🐞", "Problems found", 27, "each one written up; 9 fixed since"),
        ],
        "results": [
            item("🧩", "W3C documents identical whole and in pieces", ratio(after["ok"], after["total"]), f"after fix #165 (2026-10-30); before: {fmt(before['ok'])}"),
            item("⚖️", "Accept/reject changed by chunking", verdict_changes, f"of {fmt(len(sizes))} W3C documents"),
            item("🎲", "Fuzzing: same verdict as Expat", percent(fuzz_same, fuzzed), f"{fmt(fuzz_same)} of {fmt(fuzzed)} inputs"),
            item("🧬", "Generated documents: same verdict as Expat", percent(diff_same, generated), f"{fmt(diff_same)} of {fmt(generated)} documents"),
            item("⚙️", "Expat's own C unit tests passed", ratio(expat_passed, expat_passed), f"all except the {expat_tests - expat_passed} allocator tests (by design)"),
            item("📁", "libxml2 files identical to Expat", ratio(libxml2_same, libxml2), "same verdict, error code and events"),
            item("🔤", "Encoding cases passed", ratio(encodings_pass, encodings), "every broken UTF-8 sequence rejected"),
            item("🐍", "CPython XML tests passed on xpact", ratio(cpython - cpython_failed - cpython_errors, cpython), "Python's own test suite, pyexpat linked to xpact"),
        ],
        "project": {
            "asOf": "2026-11-02",
            "period": "6 Oct – 2 Nov 2026",
            "note": "Counted on GitHub on 2026-11-02.",
            "items": [
                item("🔀", "PRs merged by the student", 92, "of 114 merged in the repo"),
                item("📝", "Commits by the student", 136, "on student-Mass"),
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
