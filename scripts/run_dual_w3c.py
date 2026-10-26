#!/usr/bin/env python3
"""Run one W3C profile on both finalized, assertion-discarded Eiffel parsers."""

import argparse
import csv
from dataclasses import asdict
from datetime import datetime, timezone
import hashlib
import io
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import uuid

import build_implementations as builds
import run_w3c_conformance as w3c
from prepare_xpact_core import DependencyError


QUALIFICATION_CASES = ("raw_utf8", "raw_utf16", "namespace_switch", "reuse_recovery", "gc_restoration")
GC_POLICIES = {"xpact": "normal", "xpact-core": "core-managed-off-full-collect"}
FINAL_REPORTS = ("report.json", "summary.md", "comparison.tsv", "suite-manifest.json")


class LaneError(RuntimeError):
    """The two-engine run cannot be verified as a complete campaign."""


def validate_qualification(output, metadata, returncode=0):
    expected = "\t".join(("XPACT_W3C_IDENTITY", metadata["implementation"],
                          metadata["source"]["revision"], metadata["build"]["configuration"],
                          metadata["gc_policy"]))
    lines = output.splitlines()
    if not lines or lines[0] != expected:
        raise LaneError("W3C qualification identity does not match the build")
    rows = []
    for line in lines[1:]:
        fields = line.split("\t")
        if (len(fields) != 4 or fields[0] != "XPACT_W3C_CASE"
                or fields[2] not in ("PASS", "FAIL") or not fields[3]):
            raise LaneError("Invalid W3C qualification output: " + repr(line))
        rows.append({"case_id": fields[1], "status": fields[2], "detail": fields[3]})
    names = [row["case_id"] for row in rows]
    if len(names) != len(QUALIFICATION_CASES) or set(names) != set(QUALIFICATION_CASES):
        raise LaneError("W3C qualification must report each named control exactly once")
    if returncode != (1 if any(row["status"] == "FAIL" for row in rows) else 0):
        raise LaneError("W3C qualification exit status contradicts its case results")
    return rows


def run_qualification(executable, *, env, cwd, log_path):
    try:
        result = subprocess.run([str(executable), "--qualify"], cwd=cwd, env=env,
                                capture_output=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired) as error:
        partial_out = getattr(error, "output", None) or b""
        partial_err = getattr(error, "stderr", None) or b""
        Path(log_path).write_text(str(error) + "\nSTDOUT:\n" + partial_out.decode("utf-8", errors="replace")
                                  + "\nSTDERR:\n" + partial_err.decode("utf-8", errors="replace"), encoding="utf-8")
        raise LaneError("Cannot complete W3C qualification: " + str(error)) from error
    stdout = result.stdout.decode("utf-8", errors="replace")
    stderr = result.stderr.decode("utf-8", errors="replace")
    Path(log_path).write_text("Exit code: {}\nSTDOUT:\n{}\nSTDERR:\n{}".format(
        result.returncode, stdout, stderr), encoding="utf-8")
    return stdout, result.returncode


def verify_artifact(artifact):
    if builds.file_sha256(artifact["executable"]) != artifact["executable_sha256"]:
        raise LaneError("W3C executable changed after build verification")


def validate_build(artifact, implementation, assertions):
    configuration = "finalized/assertions-{}/msvc-x64".format("on" if assertions else "off")
    if (artifact.get("status") != "verified" or artifact.get("profile") != "w3c"
            or artifact.get("implementation") != implementation
            or artifact.get("gc_policy") != GC_POLICIES[implementation]
            or artifact.get("build", {}).get("configuration") != configuration
            or artifact["build"].get("mode") != "finalized"
            or artifact["build"].get("assertions") is not assertions):
        raise LaneError("W3C build does not match the requested configuration")
    verify_artifact(artifact)


def verify_sources(repo_root, audits, artifacts):
    for implementation, artifact in artifacts.items():
        audit = audits[implementation]
        if (audit["build_inputs_sha256"] != artifact["build_inputs_sha256"]
                or audit["source"]["revision"] != artifact["source"]["revision"]
                or audit["source"]["source_sha256"] != artifact["source"]["source_sha256"]):
            raise LaneError("Audit and primary W3C builds used different source snapshots")
        if builds.source_fingerprint(repo_root, implementation, profile="w3c") != artifact["build_inputs_sha256"]:
            raise LaneError("W3C build inputs changed during the campaign")


def suite_snapshot(suite_dir):
    root = Path(suite_dir).resolve()
    files = {}
    for directory, directories, names in os.walk(root, followlinks=False):
        for name in directories + names:
            path = Path(directory) / name
            if path.is_symlink() or (hasattr(path, "is_junction") and path.is_junction()):
                raise LaneError("W3C suite contains a link or junction: " + str(path))
            if name in names:
                files[path.relative_to(root).as_posix()] = builds.file_sha256(path)
    digest = hashlib.sha256(json.dumps(files, sort_keys=True).encode("utf-8")).hexdigest()
    return {"sha256": digest, "files": files}


def prepare_suite(repo_root, run_root, suite_dir, offline):
    if suite_dir is not None:
        return Path(suite_dir).resolve(), {"source_mode": "local-directory", "archive_sha256": None}
    archive = Path(repo_root) / "build/validation-corpora/w3c-xml-20130923/xmlts20130923.zip"
    target = run_root / "suite"
    if archive.is_file():
        w3c.verify_archive(archive)
        target.mkdir()
        w3c.extract_archive(archive, target)
        suite = target / "xmlconf"
    elif offline:
        raise LaneError("Pinned W3C archive is not cached; provide --suite-dir or prepare it online once")
    else:
        suite = w3c.prepare_suite(target)
    return suite, {"source_mode": "verified-archive", "archive_sha256": w3c.SUITE_SHA256}


def verify_case_input(case, suite, snapshot):
    relative = case.path.relative_to(suite).as_posix()
    expected = snapshot["files"].get(relative)
    actual = builds.file_sha256(case.path) if case.path.is_file() else None
    if actual != expected:
        raise LaneError("W3C input bytes changed during execution: " + case.id)


def comparison_rows(cases, results):
    indexed = {(row.engine, row.case_id): row for row in results}
    expected = {(engine, case.id) for engine in GC_POLICIES for case in cases}
    if len(indexed) != len(results) or set(indexed) != expected:
        raise LaneError("W3C result matrix is incomplete or contains duplicate/extra cases")
    rows = []
    for case in cases:
        own, core = (indexed[(engine, case.id)] for engine in GC_POLICIES)
        for result in (own, core):
            if result.expected != case.expected or result.kind != case.kind or result.known:
                raise LaneError("W3C result expectations changed or a failure was suppressed")
            if case.skip_reason:
                if result.status != "skipped" or result.actual != "not-run" or result.message != case.skip_reason:
                    raise LaneError("W3C profile exclusion changed for one implementation")
            elif result.status not in ("passed", "failed", "error"):
                raise LaneError("An applicable W3C case was not executed")
            elif result.status in ("passed", "failed"):
                if (result.actual not in ("ACCEPT", "REJECT")
                        or (result.status == "passed") != (result.actual == case.expected)
                        or result.exit_code != (0 if result.actual == "ACCEPT" else 1)):
                    raise LaneError("W3C verdict, status and process exit code are inconsistent")
        rows.append({"case_id": case.id, "kind": case.kind, "namespaces": case.namespaces,
                     "expected": case.expected, "skip_reason": case.skip_reason,
                     "xpact_status": own.status, "xpact_actual": own.actual, "xpact_exit_code": own.exit_code,
                     "core_status": core.status, "core_actual": core.actual, "core_exit_code": core.exit_code,
                     "agreement": (own.status, own.actual) == (core.status, core.actual)})
    return rows


def publish_reports(run_root, report, rows, results, metadata, manifest):
    try:
        w3c.write_reports(results, run_root / "conformance", metadata)
        buffer = io.StringIO(newline="")
        writer = csv.DictWriter(buffer, fieldnames=list(rows[0]), delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
        (run_root / "comparison.tsv").write_text(buffer.getvalue(), encoding="utf-8")
        builds.write_json_atomic(run_root / "suite-manifest.json", manifest)
        builds.write_json_atomic(run_root / "report.json", report)
        lines = ["# Dual W3C: finalized, assertions discarded", "", "Status: " + report["status"], "",
                 "Profile: " + w3c.PROFILE, "",
                 "| Implementation | Cases | Passed | Failed | Errors | Excluded |",
                 "|---|---:|---:|---:|---:|---:|"]
        for summary in report["engines"]:
            lines.append("| {engine} | {total} | {passed} | {failed} | {errors} | {skipped} |".format(**summary))
        lines += ["", "## Directed audit controls", "",
                  "| Implementation | Assertions | Passed | Failed | Control process/protocol errors |",
                  "|---|---|---:|---:|---:|"]
        for controls in report["qualification"]:
            lines.append("| {} | {} | {} | {} | {} |".format(
                controls["implementation"], "on" if controls["assertions"] else "off",
                sum(case["status"] == "PASS" for case in controls["cases"]),
                sum(case["status"] == "FAIL" for case in controls["cases"]),
                1 if controls.get("qualification_error") else 0))
        lines += ["", "Every profile exclusion has the same explicit reason for both engines.",
                  "No known-failure allowlist is applied. Agreement alone is not a pass.",
                  "Wrong verdicts remain failures; crashes, inconsistent protocol, launch errors and timeouts remain errors.",
                  "Per-case original output and exit codes are retained under work/; input hashes are in suite-manifest.json.",
                  "Elapsed times include a fresh process and raw file read, not parser-only throughput.",
                  "Assertions-on builds supply directed audit controls; the full catalog runs on assertions-off builds.",
                  "Core's internal GC policy is retained; incoming caller GC state is restored.",
                  "This profile does not cover external entities, canonical output, full event equality or native DLLs.", ""]
        (run_root / "summary.md").write_text("\n".join(lines), encoding="utf-8")
    except BaseException:
        clear_reports(run_root)
        raise


def clear_reports(run_root):
    for name in FINAL_REPORTS:
        (run_root / name).unlink(missing_ok=True)
    for name in w3c.REPORT_FILES:
        (run_root / "conformance" / name).unlink(missing_ok=True)


def run_lane(repo_root, run_root, *, suite_dir=None, offline=False, timeout_seconds=10):
    repo_root, run_root = Path(repo_root).resolve(), Path(run_root).resolve()
    if not math.isfinite(timeout_seconds) or timeout_seconds <= 0:
        raise LaneError("Per-case timeout must be positive and finite")
    if suite_dir is not None:
        supplied = Path(suite_dir).resolve()
        if run_root.is_relative_to(supplied) or supplied.is_relative_to(run_root):
            raise LaneError("W3C inputs and run output must be separate directories")
    run_root.mkdir(parents=True)
    state = {"schema_version": 1, "status": "running", "lane": "w3c-finalized-assertions-off", "builds": []}
    try:
        builds.write_json_atomic(run_root / "run.json", state)
        suite, provenance = prepare_suite(repo_root, run_root, suite_dir, offline)
        before = suite_snapshot(suite)
        cases = w3c.load_catalog(suite)
        if not any(not case.skip_reason for case in cases):
            raise LaneError("W3C catalog contains no applicable cases")
        manifest = {"suite": str(suite), **before, "cases": [
            {"case_id": case.id, "path": str(case.path.relative_to(suite)), "kind": case.kind,
             "namespaces": case.namespaces, "expected": case.expected, "skip_reason": case.skip_reason,
             "input_sha256": before["files"].get(case.path.relative_to(suite).as_posix())}
            for case in cases]}
        tools, environment, compiler_metadata = builds.toolchain()
        artifacts, audits, qualification = {}, {}, []
        for assertions in (True, False):
            phase = run_root / ("audit" if assertions else "primary")
            phase.mkdir()
            for implementation in GC_POLICIES:
                row = {"implementation": implementation, "assertions": assertions, "status": "failed"}
                try:
                    built = builds.build_one(repo_root, phase, implementation, tools, environment,
                                             compiler_metadata, offline=offline, profile="w3c", assertions=assertions)
                    artifact = json.loads(Path(built["manifest"]).read_text(encoding="utf-8"))
                    validate_build(artifact, implementation, assertions)
                    controls = []
                    try:
                        output, code = run_qualification(artifact["executable"], env=environment,
                                                         cwd=phase / implementation,
                                                         log_path=phase / implementation / "qualification.log")
                        controls = validate_qualification(output, artifact, code)
                    except LaneError as error:
                        # The build identity is already authenticated. A broken
                        # directed control must remain visible without hiding
                        # thousands of independently executed catalog results.
                        row["qualification_error"] = str(error)
                    verify_artifact(artifact)
                    row.update(status="executed", manifest=built["manifest"], cases=controls)
                    qualification.append(row)
                    (audits if assertions else artifacts)[implementation] = artifact
                except (builds.BuildError, DependencyError, LaneError, OSError, ValueError, KeyError) as error:
                    row["error"] = str(error)
                state["builds"].append(row)
        if any(row["status"] != "executed" for row in state["builds"]):
            raise LaneError("W3C build/identity gate failed; see run.json")
        verify_sources(repo_root, audits, artifacts)
        state.update(status="executing", catalog_cases=len(cases), source=provenance)
        builds.write_json_atomic(run_root / "run.json", state)
        results = []
        for implementation, artifact in artifacts.items():
            verify_artifact(artifact)
            if suite_snapshot(suite) != before:
                raise LaneError("W3C suite bytes changed before engine execution")
            work = run_root / "work" / implementation
            work.mkdir(parents=True)
            print("W3C {}: {} catalog cases".format(implementation, len(cases)), flush=True)
            for index, case in enumerate(cases, 1):
                case_key = "{:04d}-{}".format(index, hashlib.sha256(case.id.encode()).hexdigest()[:12])
                case_work = work / case_key
                if not case.skip_reason:
                    case_work.mkdir()
                verify_case_input(case, suite, before)
                results.append(w3c.run_case(case, implementation, Path(artifact["executable"]),
                                           timeout_seconds, case_work, diagnostic_dir=case_work))
                verify_case_input(case, suite, before)
                if index % 250 == 0:
                    print("  {}: {}/{}".format(implementation, index, len(cases)), flush=True)
        rows = comparison_rows(cases, results)
        if suite_snapshot(suite) != before:
            raise LaneError("W3C suite bytes changed during execution")
        verify_sources(repo_root, audits, artifacts)
        for artifact in artifacts.values():
            verify_artifact(artifact)
        summaries = []
        for implementation in GC_POLICIES:
            group = [row for row in results if row.engine == implementation]
            summaries.append({"engine": implementation, "total": len(group),
                              "passed": sum(row.status == "passed" for row in group),
                              "failed": sum(row.status == "failed" for row in group),
                              "errors": sum(row.status == "error" for row in group),
                              "skipped": sum(row.status == "skipped" for row in group)})
        failures = any(row.status in ("failed", "error") for row in results)
        failures = failures or any(row.get("qualification_error") for row in qualification)
        failures = failures or any(case["status"] == "FAIL" for row in qualification for case in row["cases"])
        status = "complete_with_failures" if failures else "complete"
        metadata = {"suite_version": w3c.SUITE_VERSION, "source": w3c.SUITE_URL, **provenance,
                    "suite_directory": str(suite), "suite_sha256": before["sha256"], "catalog_cases": len(cases)}
        report = {"schema_version": 1, "status": status, "lane": state["lane"], "profile": w3c.PROFILE,
                  "source": metadata, "artifacts": artifacts, "qualification": qualification, "engines": summaries,
                  "agreement": {"same_outcome": sum(row["agreement"] for row in rows),
                                "different_outcome": sum(not row["agreement"] for row in rows)}}
        publish_reports(run_root, report, rows, results, metadata, manifest)
        state["status"] = status
        builds.write_json_atomic(run_root / "run.json", state)
        return report
    except BaseException as error:
        clear_reports(run_root)
        state.update(status="failed", error=str(error))
        builds.write_json_atomic(run_root / "run.json", state)
        raise


def positive_timeout(value):
    result = float(value)
    if not math.isfinite(result) or result <= 0:
        raise argparse.ArgumentTypeError("must be positive and finite")
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite-dir", type=Path)
    parser.add_argument("--offline", action="store_true")
    parser.add_argument("--timeout", type=positive_timeout, default=10)
    args = parser.parse_args(argv)
    root = Path(__file__).resolve().parents[1]
    run = root / "build/dual-w3c" / (datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ-") + uuid.uuid4().hex[:12])
    print("Dual W3C results: " + str(run), flush=True)
    try:
        report = run_lane(root, run, suite_dir=args.suite_dir, offline=args.offline, timeout_seconds=args.timeout)
    except (builds.BuildError, DependencyError, LaneError, OSError, ValueError, KeyError) as error:
        print("Dual W3C could not complete: " + str(error), file=sys.stderr)
        return 2
    print("{}: {}".format(report["status"], run / "summary.md"), flush=True)
    return 0 if report["status"] == "complete" else 1


if __name__ == "__main__":
    sys.exit(main())
