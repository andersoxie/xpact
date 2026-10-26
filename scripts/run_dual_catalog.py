#!/usr/bin/env python3
"""Qualify and measure only the finalized, assertion-discarded dual catalog lane."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import statistics
import sys
import tempfile
import uuid

import build_implementations as builds
import compare_eiffel_benchmarks as paired
from prepare_xpact_core import DependencyError


QUALIFICATION_CASES = ("catalog_observed", "catalog_noop", "observed_reuse_recovery",
                       "noop_reuse_recovery", "gc_restoration")
GC_POLICIES = {"xpact": "normal", "xpact-core": "core-managed-off-full-collect"}
DOCUMENT = ("<catalog>" + "".join('<item id="{}">value</item>'.format(i)
                                for i in range(1, 101)) + "</catalog>").encode("ascii")


class LaneError(RuntimeError):
    """A complete, qualified comparison cannot be published."""


def validate_qualification(output, metadata):
    expected = "\t".join(("XPACT_CATALOG_IDENTITY", metadata["implementation"],
                          metadata["source"]["revision"], metadata["build"]["configuration"],
                          metadata["gc_policy"]))
    lines = output.splitlines()
    if not lines or lines[0] != expected:
        raise LaneError("Qualification identity does not match the built executable")
    cases = []
    for line in lines[1:]:
        fields = line.split("\t")
        if len(fields) != 4 or fields[0] != "XPACT_CATALOG_CASE" or not fields[3]:
            raise LaneError("Invalid qualification case output: " + repr(line))
        cases.append({"case_id": fields[1], "status": fields[2], "detail": fields[3]})
    names = [case["case_id"] for case in cases]
    if len(names) != len(QUALIFICATION_CASES) or set(names) != set(QUALIFICATION_CASES):
        raise LaneError("Qualification must report every expected case exactly once")
    if any(case["status"] != "PASS" for case in cases):
        raise LaneError("At least one catalog qualification case failed")
    return cases


def verify_artifact(metadata):
    if builds.file_sha256(metadata["executable"]) != metadata["executable_sha256"]:
        raise LaneError("Executable changed after its build was verified")


def validate_build(metadata, implementation, assertions):
    expected_config = "finalized/assertions-{}/msvc-x64".format("on" if assertions else "off")
    if (metadata.get("status") != "verified" or metadata.get("profile") != "catalog"
            or metadata.get("implementation") != implementation
            or metadata.get("gc_policy") != GC_POLICIES[implementation]
            or metadata.get("build", {}).get("configuration") != expected_config
            or metadata["build"].get("mode") != "finalized"
            or metadata["build"].get("assertions") is not assertions):
        raise LaneError("Build manifest does not describe the requested catalog configuration")
    verify_artifact(metadata)


def verify_sources(repo_root, audits, artifacts):
    for implementation, artifact in artifacts.items():
        audit = audits[implementation]
        if (audit["build_inputs_sha256"] != artifact["build_inputs_sha256"]
                or audit["source"]["revision"] != artifact["source"]["revision"]
                or audit["source"]["source_sha256"] != artifact["source"]["source_sha256"]):
            raise LaneError("Audit and benchmark used different source snapshots: " + implementation)
        current = builds.source_fingerprint(repo_root, implementation, profile="catalog")
        if current != artifact["build_inputs_sha256"]:
            raise LaneError("Catalog source inputs changed after building: " + implementation)


def validate_comparison(report, artifacts, pairs):
    metadata = report["metadata"]
    workloads = metadata["workloads"]
    if (len(workloads) != 1 or workloads[0]["name"] != "catalog"
            or workloads[0]["document_bytes"] != len(DOCUMENT) or workloads[0].get("path") is not None):
        raise LaneError("Comparison contains a workload outside the selected catalog lane")
    for role, implementation in (("A", "xpact"), ("B", "xpact-core")):
        expected = artifacts[implementation]
        identity = metadata["executables"][role]
        if (Path(identity["path"]).resolve() != Path(expected["executable"]).resolve()
                or identity["sha256"] != expected["executable_sha256"]):
            raise LaneError("Comparison executable differs from the qualified build")
    rows, summaries = report["results"], report["summary"]
    if (len(rows) != pairs or len(summaries) != 1
            or summaries[0]["workload"] != "catalog" or summaries[0]["pairs"] != pairs):
        raise LaneError("Comparison is incomplete")
    iterations = set()
    for index, row in enumerate(rows, 1):
        if (row["Workload"] != "catalog" or row["Pair"] != index
                or row["Order"] != ("AB" if index % 2 else "BA")
                or row["DocumentBytes"] != len(DOCUMENT) or row["Iterations"] < 1):
            raise LaneError("Comparison row does not match the selected workload/pair")
        iterations.add(row["Iterations"])
        for field in ("BaselineElapsedMs", "CandidateElapsedMs", "BaselineMiBPerSecond",
                      "CandidateMiBPerSecond", "CandidateSpeedRatio"):
            if not math.isfinite(row[field]) or row[field] <= 0:
                raise LaneError("Comparison contains an invalid measurement")
    if len(iterations) != 1:
        raise LaneError("Comparison used different iteration counts across pairs")


def summary_markdown(report):
    comparison = report["comparison"]
    rows = comparison["results"]
    count = rows[0]["Iterations"]
    ratios = [row["CandidateSpeedRatio"] for row in rows]
    lines = ["# Dual catalog: finalized, assertions discarded", "",
             "Status: complete; both assertion configurations passed the scoped correctness gate.", "",
             "Workload: catalog-100-items, {} bytes, {} documents per sample.".format(len(DOCUMENT), count),
             "", "| Implementation | Revision | GC policy | Median ms | Median MiB/s |",
             "|---|---|---|---:|---:|"]
    for implementation, prefix in (("xpact", "Baseline"), ("xpact-core", "Candidate")):
        artifact = report["artifacts"][implementation]
        lines.append("| {} | `{}` | {} | {:.3f} | {:.3f} |".format(
            implementation, artifact["source"]["revision"], artifact["gc_policy"],
            statistics.median(row[prefix + "ElapsedMs"] for row in rows),
            statistics.median(row[prefix + "MiBPerSecond"] for row in rows)))
    lines += ["", "Median xpact time / core time: {:.4f}; pair range {:.4f}–{:.4f}.".format(
        statistics.median(ratios), min(ratios), max(ratios)), "",
        "Ratios above 1 favor core. This is an end-to-end implementation comparison:",
        "core disables GC internally and performs a full collection on final input; that cost is timed.",
        "The caller requests no additional GC suspension for either implementation.",
        "Parser reset/reuse and process startup are timed; compilation and qualification are excluded.",
        "Both use no-op handlers during timing. Observing-handler checks run before measurements.", "",
        "Raw alternating AB/BA pairs, calibration, executable hashes and all build manifests are retained.",
        "This gate covers the catalog and directed reuse/recovery checks, not general XML conformance.", ""]
    return "\n".join(lines)


def publish_reports(run_root, report):
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", newline="\n",
                                         dir=run_root, prefix=".summary-", suffix=".tmp", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(summary_markdown(report))
        builds.write_json_atomic(run_root / "report.json", report)
        temporary.replace(run_root / "summary.md")
    except BaseException:
        for name in ("report.json", "summary.md"):
            (run_root / name).unlink(missing_ok=True)
        raise
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def run_lane(repo_root, run_root, *, offline=False, iterations=1000, pairs=6,
             warmups=2, min_sample_seconds=1.0, sample_timeout_seconds=120):
    repo_root, run_root = Path(repo_root).resolve(), Path(run_root).resolve()
    # A run owns a fresh directory only: failure cleanup cannot erase earlier evidence.
    run_root.mkdir(parents=True)
    state = {"schema_version": 1, "status": "running", "lane": "catalog-finalized-assertions-off",
             "builds": []}
    try:
        builds.write_json_atomic(run_root / "run.json", state)
        tools, environment, compiler_metadata = builds.toolchain()
        artifacts, audits, qualification = {}, {}, []
        for assertions in (True, False):
            phase = run_root / ("audit" if assertions else "benchmark")
            phase.mkdir()
            for implementation in ("xpact", "xpact-core"):
                row = {"implementation": implementation, "assertions": assertions, "status": "failed"}
                try:
                    result = builds.build_one(repo_root, phase, implementation, tools, environment,
                                              compiler_metadata, offline=offline, profile="catalog",
                                              assertions=assertions)
                    artifact = json.loads(Path(result["manifest"]).read_text(encoding="utf-8"))
                    validate_build(artifact, implementation, assertions)
                    output = builds.run_checked([artifact["executable"], "--qualify"],
                                                cwd=phase / implementation, env=environment,
                                                log_path=phase / implementation / "qualification.log", timeout=30)
                    cases = validate_qualification(output, artifact)
                    verify_artifact(artifact)
                    row.update(status="qualified", manifest=result["manifest"], cases=cases)
                    qualification.append(row)
                    if assertions:
                        audits[implementation] = artifact
                    else:
                        artifacts[implementation] = artifact
                except (builds.BuildError, DependencyError, LaneError, OSError, ValueError, KeyError) as error:
                    row["error"] = str(error)
                state["builds"].append(row)
        if any(row["status"] != "qualified" for row in state["builds"]):
            raise LaneError("Catalog correctness/build gate failed; see per-build errors in run.json")
        verify_sources(repo_root, audits, artifacts)
        state["status"] = "qualified"
        builds.write_json_atomic(run_root / "run.json", state)
        for artifact in artifacts.values():
            verify_artifact(artifact)
        comparison_dir = run_root / "comparison"
        arguments = ["--baseline", artifacts["xpact"]["executable"],
                     "--candidate", artifacts["xpact-core"]["executable"], "--workload", "catalog",
                     "--output-dir", str(comparison_dir), "--iterations", str(iterations),
                     "--pairs", str(pairs), "--warmups", str(warmups),
                     "--min-sample-seconds", str(min_sample_seconds),
                     "--timeout-seconds", str(sample_timeout_seconds)]
        state["status"] = "measuring"
        state["comparison_arguments"] = arguments
        builds.write_json_atomic(run_root / "run.json", state)
        if paired.main(arguments) != 0:
            raise LaneError("Catalog paired measurement failed")
        comparison = json.loads((comparison_dir / "comparison.json").read_text(encoding="utf-8"))
        validate_comparison(comparison, artifacts, pairs)
        for artifact in artifacts.values():
            verify_artifact(artifact)
        verify_sources(repo_root, audits, artifacts)
        report = {"schema_version": 1, "status": "complete", "lane": state["lane"],
                  "input": {"name": "catalog-100-items", "bytes": len(DOCUMENT),
                            "sha256": hashlib.sha256(DOCUMENT).hexdigest()},
                  "artifacts": artifacts, "qualification": qualification, "comparison": comparison}
        publish_reports(run_root, report)
        state["status"] = "complete"
        builds.write_json_atomic(run_root / "run.json", state)
        return report
    except BaseException as error:
        for name in ("report.json", "summary.md"):
            (run_root / name).unlink(missing_ok=True)
        paired.clear_reports(run_root / "comparison")
        state.update(status="failed", error=str(error))
        builds.write_json_atomic(run_root / "run.json", state)
        raise


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--offline", action="store_true")
    parser.add_argument("--iterations", type=paired.positive_int, default=1000)
    parser.add_argument("--pairs", type=paired.positive_int, default=6)
    parser.add_argument("--warmups", type=paired.positive_int, default=2)
    parser.add_argument("--min-sample-seconds", type=paired.nonnegative_float, default=1.0)
    parser.add_argument("--sample-timeout-seconds", type=paired.positive_int, default=120)
    args = parser.parse_args(argv)
    root = Path(__file__).resolve().parents[1]
    run = root / "build/dual-catalog" / (datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ-") + uuid.uuid4().hex[:12])
    print("Dual catalog results: " + str(run), flush=True)
    try:
        run_lane(root, run, offline=args.offline, iterations=args.iterations, pairs=args.pairs,
                 warmups=args.warmups, min_sample_seconds=args.min_sample_seconds,
                 sample_timeout_seconds=args.sample_timeout_seconds)
    except (builds.BuildError, DependencyError, LaneError, OSError, ValueError, KeyError) as error:
        print("Dual catalog failed: " + str(error), file=sys.stderr)
        return 1
    print("Complete: " + str(run / "summary.md"), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
