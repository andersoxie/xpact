"""G01: select 50-100 W3C XML cases and write a portable corpus manifest.

The cases come from the official catalog (`xmlconf.xml` of xmlts20130923), read
with `load_catalog()` of `scripts/run_w3c_conformance.py`, so the expected
outcome and the "counted or skipped" decision are exactly the runner's (the
runner Jenkins uses). The catalog attributes (SECTIONS, ENTITIES, VERSION, ...)
are recorded while that function reads them.

Selection is deterministic: per category the candidates are sorted by catalog
order and taken evenly spread, half expected-ACCEPT and half expected-REJECT
where both exist. Selected by the student; not reviewed by the supervisor.

Usage, from the repository root:
    python -I student/results/G01-corpus/make_manifest.py \
        --suite-dir build/validation-corpora/w3c-xml-20130923/xmlconf \
        --today build/benchmarks/w3c-xml-conformance/results.tsv
    python -I student/results/G01-corpus/make_manifest.py --check \
        --suite-dir <another copy of xmlconf>
The first writes `manifest.tsv` and `summary.md` next to this script; the
second only verifies every path and SHA-256 of `manifest.tsv` (exit 1 on any
difference), so the manifest can be checked on another machine.
"""

import argparse
import csv
import hashlib
import importlib.util
import re
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
RUNNER = REPO / "scripts" / "run_w3c_conformance.py"
MANIFEST = HERE / "manifest.tsv"

# (category, productions, section prefixes, path filter, accept quota, reject quota)
# Productions are XML 1.0 grammar numbers as written in SECTIONS, e.g. "3.1 [41]".
ENCODING_PRODUCTIONS = {77, 78, 80, 81}
CATEGORIES = [
    ("namespaces", set(), (), "eduni/namespaces/1.0/", 4, 4),
    ("encodings", ENCODING_PRODUCTIONS, ("4.3.3", "4.3.1"), "", 5, 5),
    ("entities", {66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76}, ("4.1", "4.2", "4.4", "4.5"), "", 5, 5),
    ("dtd", {28, 29, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60}, ("2.8", "3.2", "3.3"), "", 5, 5),
    ("attributes", {10, 41}, ("3.3.3",), "", 5, 5),
    ("tags", {39, 40, 42, 43, 44}, ("3.1",), "", 5, 5),
    ("text", {14, 15, 16, 17, 18, 19, 20, 21}, ("2.4", "2.5", "2.6", "2.7"), "", 5, 5),
    ("characters", {2, 3, 4, 5}, ("2.2", "2.3"), "", 3, 3),
]
INVALID_QUOTA = 6          # type "invalid": well formed, breaks DTD validity -> ACCEPT
LARGEST_QUOTA = 3          # the largest applicable inputs
NOT_COUNTED = [            # present in the manifest, marked, not counted
    ("external entities", "Requires external", 4),
    ("XML 1.1", "XML 1.1", 3),
    ("other edition", "fifth edition", 1),
    ("error", "Optional error detection", 2),
]


def load_runner():
    spec = importlib.util.spec_from_file_location("run_w3c_conformance", RUNNER)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def productions(sections: str) -> set[int]:
    return {int(n) for n in re.findall(r"\[(\d+)\]", sections)}


def non_utf8_encoding(path: Path) -> bool:
    """UTF-16 byte order mark, or an XML declaration naming another encoding."""
    head = path.read_bytes()[:200]
    if head[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return True
    found = re.search(rb"""encoding\s*=\s*["']([A-Za-z0-9._-]+)["']""", head)
    return bool(found) and found.group(1).lower() not in (b"utf-8", b"utf8")


def matches(attrs: dict, case, rel: str, prods: set[int], prefixes: tuple, path_filter: str) -> bool:
    if path_filter:
        return rel.startswith(path_filter)
    if prods == ENCODING_PRODUCTIONS and non_utf8_encoding(case.path):
        return True
    sections = attrs.get("SECTIONS", "")
    numbers = productions(sections)
    if numbers:
        return bool(numbers & prods)
    return any(sections.startswith(prefix) for prefix in prefixes)


def spread(items: list, count: int) -> list:
    """`count` items evenly spread over `items` (deterministic)."""
    if count >= len(items):
        return list(items)
    step = len(items) / count
    return [items[int(i * step)] for i in range(count)]


def load_cases(suite_dir: Path):
    runner = load_runner()
    captured: dict[str, dict] = {}
    original = runner.expectation

    def recording(attributes):
        captured[attributes["ID"]] = dict(attributes)
        return original(attributes)

    runner.expectation = recording
    try:
        cases = runner.load_catalog(suite_dir)
    finally:
        runner.expectation = original
    return runner, cases, captured


def select(cases, captured, root: Path) -> list[tuple[str, object]]:
    applicable = [c for c in cases if not c.skip_reason]
    chosen: dict[str, str] = {}
    order: list[tuple[str, object]] = []

    def take(category, pool, count):
        pool = [c for c in pool if c.id not in chosen]
        for case in spread(pool, count):
            chosen[case.id] = category
            order.append((category, case))

    for category, prods, prefixes, path_filter, n_accept, n_reject in CATEGORIES:
        pool = [c for c in applicable if c.kind != "invalid"
                and matches(captured[c.id], c, c.path.relative_to(root).as_posix(), prods, prefixes, path_filter)]
        take(category, [c for c in pool if c.expected == "ACCEPT"], n_accept)
        take(category, [c for c in pool if c.expected == "REJECT"], n_reject)
    take("invalid", [c for c in applicable if c.kind == "invalid"], INVALID_QUOTA)
    largest = sorted(applicable, key=lambda c: c.path.stat().st_size, reverse=True)
    take("largest", largest[:LARGEST_QUOTA * 3], LARGEST_QUOTA)
    for category, marker, count in NOT_COUNTED:
        take("not counted: " + category, [c for c in cases if marker in c.skip_reason], count)
    return order


def dependencies(case, attrs: dict, root: Path) -> str:
    parts = []
    if attrs.get("ENTITIES", "none") != "none":
        parts.append(f"external {attrs['ENTITIES']} entities")
    output = attrs.get("OUTPUT")
    if output:
        # OUTPUT is relative to the same xml:base as URI, not to the case's folder.
        base = Path(case.path.as_posix()[: -len(attrs["URI"])])
        target = (base / output).resolve()
        if target.is_file():
            parts.append("canonical output " + target.relative_to(root).as_posix())
    return "; ".join(parts) or "none"


def review(case, today: dict) -> str:
    """Check the expected outcome against the guide's table and today's runs."""
    problems = []
    rule = {"valid": "ACCEPT", "invalid": "ACCEPT", "not-wf": "REJECT", "error": None}[case.kind]
    if rule and case.expected != rule:
        problems.append(f"expected {case.expected}, guide says {rule}")
    if case.kind == "error" and not case.skip_reason:
        problems.append("error case counted")
    for engine in ("Finalized", "FinalizedAssertions"):
        status = today.get((engine, case.id), "missing")
        want = "skipped" if case.skip_reason else "passed"
        if status != want:
            problems.append(f"{engine}: {status}, want {want}")
    return "ok" if not problems else "; ".join(problems)


def write(order, captured, root: Path, today: dict) -> list[dict]:
    rows = []
    for category, case in order:
        attrs = captured[case.id]
        rel = case.path.relative_to(root).as_posix()
        rows.append({
            "id": case.id,
            "category": category,
            "collection": rel.split("/")[0],
            "path": rel,
            "sha256": sha256(case.path),
            "bytes": case.path.stat().st_size,
            "type": case.kind,
            "expected": case.expected if not case.skip_reason else f"({case.expected})",
            "counted": "no" if case.skip_reason else "yes",
            "skip_reason": case.skip_reason,
            "recommendation": attrs.get("RECOMMENDATION", "XML1.0"),
            "version": attrs.get("VERSION", ""),
            "edition": attrs.get("EDITION", ""),
            "namespace": attrs.get("NAMESPACE", "yes"),
            "entities": attrs.get("ENTITIES", "none"),
            "sections": attrs.get("SECTIONS", ""),
            "dependencies": dependencies(case, attrs, root),
            "today_finalized": today.get(("Finalized", case.id), "missing"),
            "today_finalized_assertions": today.get(("FinalizedAssertions", case.id), "missing"),
            "review": review(case, today),
            "description": " ".join(case.description.split())[:160],
        })
    with MANIFEST.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]), delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    return rows


def summary(rows: list[dict], runner, catalog_sha: str) -> list[str]:
    counted = [r for r in rows if r["counted"] == "yes"]
    lines = [
        "# G01 corpus manifest: summary", "",
        "Generated by [`make_manifest.py`](make_manifest.py); every case in [`manifest.tsv`](manifest.tsv).", "",
        "| | |", "|---|---|",
        f"| Suite | W3C XML Conformance Test Suite `{runner.SUITE_VERSION}`, {runner.SUITE_URL} |",
        f"| Archive SHA-256 | `{runner.SUITE_SHA256}` |",
        f"| Root catalog `xmlconf.xml` SHA-256 | `{catalog_sha}` |",
        f"| Profile (runner) | {runner.PROFILE} |",
        f"| Cases | **{len(rows)}**: {len(counted)} counted, {len(rows) - len(counted)} marked not counted |",
        f"| Expected (counted) | {sum(r['expected'] == 'ACCEPT' for r in counted)} ACCEPT, {sum(r['expected'] == 'REJECT' for r in counted)} REJECT |",
        f"| Review | {sum(r['review'] == 'ok' for r in rows)} of {len(rows)} `ok` |",
        "", "## By category", "",
        "| Category | Cases | ACCEPT | REJECT | Collections |", "|---|---|---|---|---|",
    ]
    for category in dict.fromkeys(r["category"] for r in rows):
        group = [r for r in rows if r["category"] == category]
        lines.append(f"| {category} | {len(group)} | {sum('ACCEPT' in r['expected'] for r in group)} | "
                     f"{sum('REJECT' in r['expected'] for r in group)} | "
                     f"{', '.join(sorted({r['collection'] for r in group}))} |")
    lines += ["", "## By catalog type", "", "| Type | Cases | Counted |", "|---|---|---|"]
    for kind, value in Counter(r["type"] for r in rows).most_common():
        lines.append(f"| {kind} | {value} | {sum(r['type'] == kind and r['counted'] == 'yes' for r in rows)} |")
    lines += ["", "## Today's result (2026-10-26, both finalized builds)", "",
              "| `Finalized` | `FinalizedAssertions` | Cases |", "|---|---|---|"]
    for (a, b), value in Counter((r["today_finalized"], r["today_finalized_assertions"]) for r in rows).most_common():
        lines.append(f"| {a} | {b} | {value} |")
    return lines


def check(suite_dir: Path) -> int:
    root = suite_dir.resolve()
    with MANIFEST.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    bad = [r["id"] for r in rows if not (root / r["path"]).is_file() or sha256(root / r["path"]) != r["sha256"]]
    print(f"{len(rows)} cases checked, {len(bad)} missing or different" + (": " + ", ".join(bad) if bad else ""))
    return 1 if bad else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite-dir", type=Path, required=True)
    parser.add_argument("--today", type=Path, help="results.tsv of run_w3c_conformance.py")
    parser.add_argument("--check", action="store_true", help="only verify paths and SHA-256 of manifest.tsv")
    args = parser.parse_args()
    if args.check:
        return check(args.suite_dir)
    if args.today is None:
        parser.error("--today is required unless --check")

    root = args.suite_dir.resolve()
    runner, cases, captured = load_cases(root)
    with args.today.open(encoding="utf-8-sig", newline="") as handle:
        today = {(r["engine"], r["case_id"]): r["status"] for r in csv.DictReader(handle, delimiter="\t")}
    rows = write(select(cases, captured, root), captured, root, today)
    lines = summary(rows, runner, sha256(root / "xmlconf.xml"))
    (HERE / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{len(rows)} cases written; review ok: {sum(r['review'] == 'ok' for r in rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
