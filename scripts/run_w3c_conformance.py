#!/usr/bin/env python3
"""Run W3C XML binary conformance cases against the Eiffel benchmark targets.

Only the Python standard library is required. Test documents are never decoded
or rewritten: the Eiffel executable reads the original file in binary mode.
"""

from __future__ import annotations

import argparse
from collections import Counter
import csv
from dataclasses import asdict, dataclass
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
from urllib.parse import urljoin, urlsplit
from urllib.request import url2pathname, urlopen
import xml.etree.ElementTree as ET
from xml.parsers import expat
import zipfile


SUITE_VERSION = "20130923"
SUITE_URL = "https://www.w3.org/XML/Test/xmlts20130923.zip"
SUITE_SHA256 = "f9510b3532926e1b4c2e54855b021e4b8a66ec98a5337dcf4ff07e8a41968deb"
ROOT_CATALOG_SHA256 = "a10d3fc409fc0de5ea1758d2e4fe6efcbc51df6d1942c80f299dbbe085b2fd52"
PROFILE = "XML 1.0 fifth edition; namespaces unless NAMESPACE=no; nonvalidating; no external entities; binary verdicts only"
REPORT_FILES = ("junit.xml", "results.tsv", "summary.json", "summary.md")
KNOWN_FAILURE_FIELDS = ("engine", "case_id", "status", "category")


@dataclass(frozen=True)
class Case:
    id: str
    path: Path
    kind: str
    namespaces: bool
    expected: str
    skip_reason: str = ""
    description: str = ""
    recommendation: str = "XML1.0"


@dataclass
class Result:
    engine: str
    case_id: str
    path: str
    kind: str
    expected: str
    actual: str
    status: str
    elapsed_ms: float = 0.0
    message: str = ""
    known: str = ""
    exit_code: int | None = None


def contained_path(root: Path, candidate: Path) -> Path:
    resolved = candidate.resolve()
    if not resolved.is_relative_to(root.resolve()):
        raise ValueError(f"Path escapes suite directory: {candidate}")
    return resolved


def local_uri(root: Path, base: str, reference: str) -> Path:
    uri = urlsplit(urljoin(base, reference))
    if uri.scheme != "file" or uri.netloc or uri.query or uri.fragment:
        raise ValueError(f"Only local suite files are allowed: {reference}")
    return contained_path(root, Path(url2pathname(uri.path)))


def verify_archive(archive: Path) -> None:
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    if digest != SUITE_SHA256:
        raise ValueError(f"W3C archive SHA-256 mismatch: {digest}; expected {SUITE_SHA256}")


def extract_archive(archive: Path, destination: Path) -> None:
    """Validate every member before extracting; retain upstream notices."""
    with zipfile.ZipFile(archive) as bundle:
        for item in bundle.infolist():
            if "\\" in item.filename or ":" in item.filename:
                raise ValueError(f"Invalid archive member: {item.filename}")
            contained_path(destination, destination / item.filename)
            if (item.external_attr >> 16) & 0o170000 == 0o120000:
                raise ValueError(f"Archive contains a symbolic link: {item.filename}")
        bundle.extractall(destination)


def prepare_suite(cache_dir: Path) -> Path:
    """Cache the pinned ZIP, verify even on reuse, and extract fresh bytes."""
    cache_dir.mkdir(parents=True, exist_ok=True)
    archive = cache_dir / f"xmlts{SUITE_VERSION}.zip"
    if not archive.is_file():
        temporary = archive.with_suffix(".download")
        try:
            with urlopen(SUITE_URL, timeout=60) as source, temporary.open("wb") as target:
                shutil.copyfileobj(source, target)
            verify_archive(temporary)
            temporary.replace(archive)
        finally:
            temporary.unlink(missing_ok=True)
    verify_archive(archive)
    extract_archive(archive, cache_dir)
    return cache_dir / "xmlconf"


def expectation(attributes: dict[str, str]) -> tuple[str, str]:
    """Return expected binary verdict and an explicit out-of-profile reason."""
    kind = attributes["TYPE"]
    if kind not in {"valid", "invalid", "not-wf", "error"}:
        raise ValueError(f"Unknown test TYPE: {kind}")
    expected = "REJECT" if kind == "not-wf" else "ACCEPT"
    recommendation = attributes.get("RECOMMENDATION", "XML1.0")
    if recommendation.startswith(("XML1.1", "NS1.1")):
        return expected, "XML 1.1 / Namespaces 1.1 is outside this profile"
    if recommendation not in {"XML1.0", "XML1.0-errata2e", "XML1.0-errata3e", "XML1.0-errata4e", "NS1.0", "NS1.0-errata1e"}:
        raise ValueError(f"Unknown RECOMMENDATION: {recommendation}")
    if "VERSION" in attributes and "1.0" not in attributes["VERSION"].split():
        return expected, "Case does not apply to XML 1.0"
    if "EDITION" in attributes and "5" not in attributes["EDITION"].split():
        return expected, "Case does not apply to XML 1.0 fifth edition"
    if kind == "error":
        return "unspecified", "Optional error detection has no required binary verdict"
    entities = attributes.get("ENTITIES", "none")
    if entities not in {"none", "general", "parameter", "both"}:
        raise ValueError(f"Unknown ENTITIES: {entities}")
    if entities != "none":
        return expected, f"Requires external {entities} entities; resolver is disabled"
    return expected, ""


def load_catalog(suite_dir: Path) -> list[Case]:
    """Expand only local catalog entities, then apply inherited xml:base.

    The pinned root catalog has two packaging defects: an ISO-8859-1 comment
    despite its UTF-8 declaration, and eduni/namespaces/misc instead of eduni/misc.
    Accommodations apply only to the exact upstream root hash, in memory.
    Parser input files and the on-disk catalogs remain unchanged.
    """
    root = suite_dir.resolve()
    catalog = root / "xmlconf.xml"
    data = catalog.read_bytes()
    pinned_root = hashlib.sha256(data).hexdigest() == ROOT_CATALOG_SHA256
    builder = ET.TreeBuilder()
    active: set[Path] = set()

    def configure(parser, path: Path) -> None:
        parser.SetBase(path.as_uri())
        parser.StartElementHandler = builder.start
        parser.EndElementHandler = builder.end
        parser.CharacterDataHandler = builder.data
        parser.SetParamEntityParsing(expat.XML_PARAM_ENTITY_PARSING_ALWAYS)

        def external(context, base, system_id, public_id):
            target = local_uri(root, base, system_id)
            if target in active:
                raise ValueError(f"Recursive catalog entity: {target}")
            child = parser.ExternalEntityParserCreate(context)
            configure(child, target)
            active.add(target)
            try:
                child.Parse(target.read_bytes(), True)
            finally:
                active.remove(target)
            return 1

        parser.ExternalEntityRefHandler = external

    parser = expat.ParserCreate("ISO-8859-1" if pinned_root else None)
    configure(parser, catalog)
    active.add(catalog)
    parser.Parse(data, True)
    tree = builder.close()
    cases: list[Case] = []
    identifiers: set[str] = set()

    def visit(element: ET.Element, base: str) -> None:
        reference = element.get("xml:base", "")
        if pinned_root and reference == "eduni/namespaces/misc/":
            reference = "eduni/misc/"
        current_base = urljoin(base, reference)
        # Check inherited bases as well as leaf paths, including empty groups.
        local_uri(root, current_base, "")
        if element.tag == "TEST":
            attributes = element.attrib
            identifier = attributes["ID"]
            if identifier in identifiers:
                raise ValueError(f"Duplicate test ID: {identifier}")
            identifiers.add(identifier)
            expected, skip_reason = expectation(attributes)
            namespace = attributes.get("NAMESPACE", "yes")
            if namespace not in {"yes", "no"}:
                raise ValueError(f"Unknown NAMESPACE for {identifier}: {namespace}")
            path = local_uri(root, current_base, attributes["URI"])
            cases.append(Case(identifier, path, attributes["TYPE"], namespace == "yes",
                              expected, skip_reason, " ".join(element.itertext()).strip(),
                              attributes.get("RECOMMENDATION", "XML1.0")))
        for child in element:
            visit(child, current_base)

    visit(tree, catalog.as_uri())
    if not cases:
        raise ValueError("W3C catalog contains no test cases")
    return cases


def run_case(case: Case, engine: str, executable: Path, timeout: float, work_dir: Path,
             *, diagnostic_dir: Path | None = None) -> Result:
    result = Result(engine, case.id, str(case.path), case.kind, case.expected, "not-run", "skipped")
    if case.skip_reason:
        result.message = case.skip_reason
        return result
    if not case.path.is_file():
        result.status = "error"
        result.message = "Catalog input file is missing"
        return result
    command = [str(executable), "--conformance-file", str(case.path)]
    if case.namespaces:
        command.append("--namespaces")
    started = time.perf_counter()
    stdout_bytes, stderr_bytes = b"", b""
    try:
        completed = subprocess.run(command, capture_output=True, timeout=timeout, cwd=work_dir)
        result.exit_code = completed.returncode
        stdout_bytes, stderr_bytes = completed.stdout, completed.stderr
        stdout = stdout_bytes.decode("utf-8", errors="replace")
        stderr = stderr_bytes.decode("utf-8", errors="replace")
        markers = [line for line in stdout.splitlines() if line.startswith("XPACT_CONFORMANCE\t")]
        result.message = (stdout + stderr)[-12000:].strip()
        if markers == ["XPACT_CONFORMANCE\tACCEPT"] and completed.returncode == 0:
            result.actual = "ACCEPT"
        elif markers == ["XPACT_CONFORMANCE\tREJECT"] and completed.returncode == 1:
            result.actual = "REJECT"
        else:
            result.status = "error"
            result.actual = "process-error"
            result.message = f"Exit code {completed.returncode}; missing or inconsistent verdict.\n{result.message}"
            return result
        result.status = "passed" if result.actual == case.expected else "failed"
        if result.status == "failed":
            result.message = f"Expected {case.expected}, got {result.actual}. {case.description}\n{result.message}"
    except subprocess.TimeoutExpired as error:
        stdout_bytes, stderr_bytes = error.output or b"", error.stderr or b""
        result.status, result.actual = "error", "timeout"
        result.message = f"Parser exceeded the per-case timeout of {timeout:g} seconds"
    except OSError as error:
        result.status, result.actual, result.message = "error", "process-error", str(error)
    finally:
        result.elapsed_ms = round((time.perf_counter() - started) * 1000, 3)
        if diagnostic_dir is not None:
            # Persistence errors are harness errors, never parser verdicts.
            diagnostic_dir.mkdir(parents=True, exist_ok=True)
            (diagnostic_dir / "stdout.bin").write_bytes(stdout_bytes)
            (diagnostic_dir / "stderr.bin").write_bytes(stderr_bytes)
            (diagnostic_dir / "result.json").write_text(
                json.dumps({"command": command, "result": tsv_row(result)}, indent=2) + "\n",
                encoding="utf-8")
    return result


def load_known_failures(path: Path) -> dict[tuple[str, str], dict[str, str]]:
    """Read the engine/case pairs whose current failure or error is a recorded parser gap.

    Lines starting with '#' are comments. Every listed result must still occur:
    a listed case that passes, changes status, or no longer exists is reported.
    """
    with path.open(encoding="utf-8", newline="") as source:
        rows = list(csv.DictReader((line for line in source if not line.startswith("#")), delimiter="\t"))
    known: dict[tuple[str, str], dict[str, str]] = {}
    for number, row in enumerate(rows, 1):
        if any(not row.get(field) for field in KNOWN_FAILURE_FIELDS):
            raise ValueError(f"Known-failures row {number} needs {', '.join(KNOWN_FAILURE_FIELDS)}: {path}")
        if row["status"] not in {"failed", "error"}:
            raise ValueError(f"Known-failures row {number} has status {row['status']!r}; use failed or error: {path}")
        key = (row["engine"], row["case_id"])
        if key in known:
            raise ValueError(f"Duplicate known failure {key[0]} {key[1]}: {path}")
        known[key] = row
    return known


def apply_known_failures(results: list[Result], known: dict[tuple[str, str], dict[str, str]]) -> list[Result]:
    """Mark recorded parser gaps and return harness errors for stale list entries."""
    by_key = {(row.engine, row.case_id): row for row in results}
    engines = {row.engine for row in results}
    stale = []
    for key, entry in known.items():
        if key[0] not in engines:
            continue
        row = by_key.get(key)
        if row is not None and row.status == entry["status"]:
            row.known = entry["category"]
            continue
        actual = row.status if row is not None else "absent from the catalog"
        stale.append(Result("harness", f"known-failures:{key[0]}:{key[1]}", "", "", entry["status"], actual, "error",
                            message=f"{key[0]} {key[1]} is listed as a known {entry['status']} ({entry['category']}) "
                                    f"but is now {actual}. Update the known-failures list."))
    return stale


def observed_category(row: Result) -> str:
    """Describe what was observed, not why: causes belong in the linked issues."""
    if row.actual == "ACCEPT":
        return "accepts input that must be rejected"
    if row.actual == "REJECT":
        return "rejects input that must be accepted"
    return "timeout" if row.actual == "timeout" else "process error (crash or contract violation)"


def write_known_failures(results: list[Result], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as target:
        writer = csv.writer(target, delimiter="\t", lineterminator="\n")
        writer.writerow(KNOWN_FAILURE_FIELDS)
        for row in results:
            if row.engine != "harness" and row.status in {"failed", "error"}:
                writer.writerow((row.engine, row.case_id, row.status, row.known or observed_category(row)))


def unexpected(row: Result) -> bool:
    return row.status in {"failed", "error"} and not row.known


def xml_text(value: str) -> str:
    # Malformed-input diagnostics may contain NUL or invalid XML characters.
    return re.sub(r"[^\x09\x0a\x0d\x20-\ud7ff\ue000-\ufffd\U00010000-\U0010ffff]", "?", value)


def tsv_row(row: Result) -> dict:
    # Before Python 3.11 the csv module cannot write NUL ("need to escape").
    return {key: value.replace("\x00", "?") if isinstance(value, str) else value
            for key, value in asdict(row).items()}


def write_reports(results: list[Result], output_dir: Path, metadata: dict) -> dict:
    output_dir.mkdir(parents=True, exist_ok=True)
    suites = ET.Element("testsuites")
    summaries = []
    for engine in dict.fromkeys(row.engine for row in results):
        rows = [row for row in results if row.engine == engine]
        counts = Counter(row.status for row in rows)
        elapsed_ms = round(sum(row.elapsed_ms for row in rows), 3)
        summary = {"engine": engine, "total": len(rows), "passed": counts["passed"],
                   "failed": counts["failed"], "errors": counts["error"], "skipped": counts["skipped"],
                   "accepted": sum(row.actual == "ACCEPT" for row in rows),
                   "rejected": sum(row.actual == "REJECT" for row in rows),
                   "known": sum(bool(row.known) for row in rows), "unexpected": sum(map(unexpected, rows)),
                   "elapsed_ms": elapsed_ms}
        summaries.append(summary)
        suite = ET.SubElement(suites, "testsuite", name=f"w3c-xml-{engine}", tests=str(len(rows)),
                              failures=str(counts["failed"]), errors=str(counts["error"]),
                              skipped=str(counts["skipped"]), time=f"{elapsed_ms / 1000:.6f}")
        properties = ET.SubElement(suite, "properties")
        ET.SubElement(properties, "property", name="profile", value=PROFILE)
        for row in rows:
            test = ET.SubElement(suite, "testcase", classname=f"w3c.xml.{engine}",
                                 name=row.case_id, time=f"{row.elapsed_ms / 1000:.6f}", file=row.path)
            if row.status in {"failed", "error", "skipped"}:
                tag = {"failed": "failure", "error": "error", "skipped": "skipped"}[row.status]
                text = f"[known: {row.known}] {row.message}" if row.known else row.message
                detail = ET.SubElement(test, tag, message=xml_text(text.splitlines()[0] if text else row.status))
                detail.text = xml_text(text)
    ET.indent(suites)
    ET.ElementTree(suites).write(output_dir / "junit.xml", encoding="utf-8", xml_declaration=True)
    with (output_dir / "results.tsv").open("w", newline="", encoding="utf-8") as target:
        writer = csv.DictWriter(target, fieldnames=list(Result.__dataclass_fields__), delimiter="\t")
        writer.writeheader()
        writer.writerows(tsv_row(row) for row in results)
    report = {**metadata, "profile": PROFILE, "engines": summaries}
    (output_dir / "summary.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    lines = ["# W3C XML conformance", "", f"Source: {SUITE_URL}", "", f"Profile: {PROFILE}", "",
             "| Engine | Cases | Passed | Failed | Errors | Skipped | Known | Unexpected | Elapsed ms |",
             "|---|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for row in summaries:
        lines.append(f"| {row['engine']} | {row['total']} | {row['passed']} | {row['failed']} | {row['errors']} | {row['skipped']} | {row['known']} | {row['unexpected']} | {row['elapsed_ms']} |")
    lines += ["", "Known counts failures and errors listed in the known-failures file; they are still parser gaps.",
              "Unexpected counts every other failure or error; any unexpected result fails the run.",
              "Elapsed time includes a fresh process and file read per executed case; it is not parser-only throughput.",
              "Skipped cases are excluded from conformance results. Canonical output comparisons are not implemented.", ""]
    (output_dir / "summary.md").write_text("\n".join(lines), encoding="utf-8")
    return report


def main(argv: list[str] | None = None) -> int:
    repo = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite-dir", type=Path, help="Offline extracted directory containing xmlconf.xml")
    parser.add_argument("--cache-dir", type=Path, default=repo / "build/validation-corpora/w3c-xml-20130923")
    parser.add_argument("--output-dir", type=Path, default=repo / "build/benchmarks/w3c-xml-conformance")
    parser.add_argument("--engine", action="append", required=True, metavar="NAME=EXE")
    parser.add_argument("--timeout", type=float, default=10.0, help="Maximum seconds per case (default: 10)")
    parser.add_argument("--known-failures", type=Path,
                        help="TSV of recorded parser gaps (engine, case_id, status, category); listed results do not fail the run")
    parser.add_argument("--write-known-failures", type=Path, metavar="PATH",
                        help="Write this run's failures and errors as a known-failures TSV for review")
    args = parser.parse_args(argv)
    if not 0 < args.timeout < float("inf"):
        parser.error("--timeout must be positive and finite")
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    for name in REPORT_FILES:
        (output / name).unlink(missing_ok=True)
    results: list[Result] = []
    metadata = {"suite_version": SUITE_VERSION, "source": SUITE_URL,
                "archive_sha256": SUITE_SHA256 if args.suite_dir is None else None,
                "source_mode": "local-directory" if args.suite_dir else "verified-archive"}
    known: dict[tuple[str, str], dict[str, str]] = {}
    try:
        if args.known_failures:
            known = load_known_failures(args.known_failures.resolve())
            metadata["known_failures_file"] = str(args.known_failures.resolve())
            metadata["known_failures_listed"] = len(known)
        engines: dict[str, Path] = {}
        for value in args.engine:
            name, separator, executable = value.partition("=")
            if not separator or not name or not executable or name in engines:
                raise ValueError(f"Invalid or duplicate --engine NAME=EXE: {value}")
            engines[name] = Path(executable).resolve()
            if not engines[name].is_file():
                raise ValueError(f"Engine executable does not exist: {engines[name]}")
        suite_dir = args.suite_dir.resolve() if args.suite_dir else prepare_suite(args.cache_dir.resolve())
        metadata["suite_directory"] = str(suite_dir)
        metadata["executables"] = {name: str(path) for name, path in engines.items()}
        cases = load_catalog(suite_dir)
        metadata["catalog_cases"] = len(cases)
        if not any(not case.skip_reason for case in cases):
            raise ValueError("No applicable cases in the catalog")
        # Isolate Eiffel exception_trace.log and other crash output from the checkout.
        with tempfile.TemporaryDirectory(prefix="w3c-", dir=output) as work:
            for engine, executable in engines.items():
                print(f"W3C XML: {engine}: {len(cases)} catalog cases", flush=True)
                for index, case in enumerate(cases, 1):
                    results.append(run_case(case, engine, executable, args.timeout, Path(work)))
                    if index % 250 == 0:
                        print(f"  {engine}: {index}/{len(cases)}", flush=True)
    except (OSError, ValueError, KeyError, expat.ExpatError, zipfile.BadZipFile) as error:
        results.append(Result("harness", "suite-setup", "", "", "", "not-run", "error", message=str(error)))
    if known and not any(row.engine == "harness" for row in results):
        results += apply_known_failures(results, known)
    if args.write_known_failures:
        write_known_failures(results, args.write_known_failures.resolve())
    report = write_reports(results, output, metadata)
    for summary in report["engines"]:
        print(json.dumps(summary), flush=True)
    print(f"W3C XML reports: {output}", flush=True)
    return 1 if any(map(unexpected, results)) else 0


if __name__ == "__main__":
    sys.exit(main())
