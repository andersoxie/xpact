#!/usr/bin/env python3
"""Run and publish the two focused dual-implementation lanes for one Jenkins build."""

import argparse
import math
from pathlib import Path
import sys

import build_implementations as builds
import compare_eiffel_benchmarks as paired
import dual_jenkins_reports as reports
import jenkins_xpact_summary as subject
import run_dual_catalog as catalog
import run_dual_w3c as w3c


class CampaignError(RuntimeError):
    """A build cannot publish a complete dual-implementation campaign."""


def validate_arguments(output_dir, suite_dir, build_id, iterations, pairs, warmups,
                       min_sample_seconds, timeout_seconds, sample_timeout_seconds):
    if not isinstance(build_id, str) or not build_id.strip() or any(ord(c) < 32 for c in build_id):
        raise CampaignError("A nonempty Jenkins build identity without control characters is required")
    for name, value in (("iterations", iterations), ("pairs", pairs), ("warmups", warmups),
                        ("sample_timeout_seconds", sample_timeout_seconds)):
        if type(value) is not int or value <= 0:
            raise CampaignError(name + " must be a positive integer")
    for name, value, allow_zero in (("min_sample_seconds", min_sample_seconds, True),
                                    ("timeout_seconds", timeout_seconds, False)):
        if not math.isfinite(value) or value < 0 or (value == 0 and not allow_zero):
            raise CampaignError(name + " must be finite and " + ("nonnegative" if allow_zero else "positive"))
    if suite_dir is not None:
        supplied = Path(suite_dir).resolve()
        if output_dir.is_relative_to(supplied) or supplied.is_relative_to(output_dir):
            raise CampaignError("W3C inputs and Jenkins run output must be separate directories")


def run_campaign(repo_root, output_dir, *, build_id, offline=False, suite_dir=None,
                 timeout_seconds=10, iterations=1000, pairs=6, warmups=2,
                 min_sample_seconds=1.0, sample_timeout_seconds=120):
    repo_root, output_dir = Path(repo_root).resolve(), Path(output_dir).resolve()
    validate_arguments(output_dir, suite_dir, build_id, iterations, pairs, warmups,
                       min_sample_seconds, timeout_seconds, sample_timeout_seconds)
    # This process owns only a new directory. Neither failure cleanup nor a
    # repeated invocation can overwrite a previous build's reports.
    output_dir.mkdir(parents=True)
    state = {"schema_version": 1, "build_id": build_id, "status": "running", "lanes": {
        "catalog": {"status": "pending", "report": "catalog/report.json"},
        "w3c": {"status": "pending", "report": "w3c/report.json"}}}
    lane_reports = {}
    try:
        builds.write_json_atomic(output_dir / "run.json", state)
        invocations = (
            ("catalog", catalog.run_lane, {
                "offline": offline, "iterations": iterations, "pairs": pairs,
                "warmups": warmups, "min_sample_seconds": min_sample_seconds,
                "sample_timeout_seconds": sample_timeout_seconds}),
            ("w3c", w3c.run_lane, {
                "offline": offline, "suite_dir": suite_dir, "timeout_seconds": timeout_seconds}))
        for name, run_lane, options in invocations:
            row = state["lanes"][name]
            row["status"] = "running"
            builds.write_json_atomic(output_dir / "run.json", state)
            print("Jenkins dual lane: " + name, flush=True)
            try:
                report = run_lane(repo_root, output_dir / name, **options)
                allowed = ("complete", "complete_with_failures") if name == "w3c" else ("complete",)
                if report.get("status") not in allowed:
                    raise CampaignError("Child lane did not return a completed report: " + name)
                report_file = output_dir / row["report"]
                row["report_sha256"] = builds.file_sha256(report_file)
                row["status"] = report["status"]
                lane_reports[name] = report
            except Exception as error:
                # An incomplete lane must not hide independently executable
                # evidence from the other lane. Interruptions still propagate.
                row.update(status="failed", error=type(error).__name__ + ": " + str(error))
                # Windows PowerShell 5 can promote native stderr to a terminating
                # error before our own-only gate has evaluated the evidence.
                print("Comparison lane {} recorded an error: {}".format(name, row["error"]), flush=True)
            builds.write_json_atomic(output_dir / "run.json", state)
        statuses = [row["status"] for row in state["lanes"].values()]
        state["status"] = ("failed" if "failed" in statuses else
                           "complete_with_failures" if "complete_with_failures" in statuses else "complete")
        state["subject_summary"] = subject.publish_summary(
            output_dir, lane_reports, state["lanes"], repo_root=repo_root)
        if (state["subject_summary"].get("implementation") != "xpact"
                or state["subject_summary"].get("junit") != "xpact-junit.xml"
                or state["subject_summary"]["status"] not in ("complete", "complete_with_failures", "failed")):
            raise CampaignError("Invalid xpact test summary identity or status")
        state["publication"] = reports.publish_reports(output_dir, state, lane_reports)
        builds.write_json_atomic(output_dir / "run.json", state)
        return state
    except BaseException as error:
        state.pop("publication", None)
        state.pop("subject_summary", None)
        state.update(status="failed", error=type(error).__name__ + ": " + str(error))
        cleanup_errors = []
        for clear in (reports.clear_reports, subject.clear_summary):
            try:
                clear(output_dir)
            except Exception as cleanup_error:
                # Even locked files cannot leave a publishable owner state.
                cleanup_errors.append(type(cleanup_error).__name__ + ": " + str(cleanup_error))
        if cleanup_errors:
            state["cleanup_error"] = "; ".join(cleanup_errors)
        builds.write_json_atomic(output_dir / "run.json", state)
        raise


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--build-id", required=True)
    parser.add_argument("--offline", action="store_true")
    parser.add_argument("--suite-dir", type=Path)
    parser.add_argument("--timeout", type=w3c.positive_timeout, default=10)
    parser.add_argument("--iterations", type=paired.positive_int, default=1000)
    parser.add_argument("--pairs", type=paired.positive_int, default=6)
    parser.add_argument("--warmups", type=paired.positive_int, default=2)
    parser.add_argument("--min-sample-seconds", type=paired.nonnegative_float, default=1.0)
    parser.add_argument("--sample-timeout-seconds", type=paired.positive_int, default=120)
    args = parser.parse_args(argv)
    root = Path(__file__).resolve().parents[1]
    print("Jenkins dual reports: " + str(args.output_dir.resolve()), flush=True)
    try:
        state = run_campaign(root, args.output_dir, build_id=args.build_id, offline=args.offline,
                             suite_dir=args.suite_dir, timeout_seconds=args.timeout,
                             iterations=args.iterations, pairs=args.pairs, warmups=args.warmups,
                             min_sample_seconds=args.min_sample_seconds,
                             sample_timeout_seconds=args.sample_timeout_seconds)
    except Exception as error:
        print("Jenkins dual campaign could not complete: " + str(error), file=sys.stderr)
        return 2
    status = state["subject_summary"]["status"]
    print("xpact tests: {}; comparison: {}; {}".format(
        status, state["status"], args.output_dir / "run.json"), flush=True)
    return {"complete": 0, "complete_with_failures": 1, "failed": 2}[status]


if __name__ == "__main__":
    sys.exit(main())
