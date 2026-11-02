"""Export the conformance, benchmark and Expat comparison numbers from the repository's
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
GITHUB = "https://github.com/andersoxie/xpact/blob/student-Mass/"

W3C_REPORT = REPO / "reports" / "latest-2026-10-28"
BENCHMARKS = REPO / "docs" / "benchmarks.md"
COMPARISON = REPO / "student" / "results" / "G03-comparison" / "README.md"

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
        "generated": generated.group(1).strip() if generated else "",
        "workload": "the same UTF-8 catalog document with 100 <item> elements; median of 3 process-level runs",
        "rows": rows,
    }


def comparison() -> dict:
    text = COMPARISON.read_text(encoding="utf-8")
    verdict = re.search(r"all ([\d,]+) configuration pairs", text)
    full = re.search(r"\*\*([\d,]+) of ([\d,]+)\*\* pairs give the same verdict, error code and events", text)
    number = lambda s: int(s.replace(",", ""))
    return {
        "source": link(COMPARISON),
        "title": "XPact compared with Expat 2.8.1",
        "pairs": number(verdict.group(1)) if verdict else None,
        "sameVerdict": number(verdict.group(1)) if verdict else None,
        "sameVerdictCodeAndEvents": number(full.group(1)) if full else None,
        "note": "Measured before the 2026-10-31 fixes (#172-#175, #124, #125), which closed several of the differences.",
    }


def main() -> None:
    DATA.mkdir(exist_ok=True)
    for name, build in (("conformance", conformance), ("benchmarks", benchmarks), ("comparison", comparison)):
        path = DATA / f"{name}.json"
        path.write_text(json.dumps(build(), indent=2) + "\n", encoding="utf-8")
        print(f"wrote {path.relative_to(REPO)}")


if __name__ == "__main__":
    main()
