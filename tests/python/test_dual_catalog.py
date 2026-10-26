"""Check the focused dual-catalog qualification and publication lifecycle."""

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


REPO = Path(__file__).resolve().parents[2]
SCRIPTS = REPO / "scripts"
sys.path.insert(0, str(SCRIPTS))
SPEC = importlib.util.spec_from_file_location("run_dual_catalog", SCRIPTS / "run_dual_catalog.py")
runner = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = runner
SPEC.loader.exec_module(runner)


CASE_IDS = ("catalog_observed", "catalog_noop", "observed_reuse_recovery",
            "noop_reuse_recovery", "gc_restoration")


def metadata_for(implementation="xpact", assertions=False):
    return {
        "schema_version": 1, "status": "verified", "profile": "catalog",
        "implementation": implementation,
        "source": {"repository": "https://github.com/fixture/" + implementation + ".git",
                   "revision": "a" * 40, "source_sha256": "b" * 64,
                   "source_dir": str(REPO), "worktree_dirty": False},
        "build": {"configuration": "finalized/assertions-{}/msvc-x64".format(
            "on" if assertions else "off"), "assertions": assertions,
                  "mode": "finalized", "void_safety": "all"},
        "gc_policy": ("normal" if implementation == "xpact" else "core-managed-off-full-collect"),
    }


def identity(metadata):
    return "\t".join(("XPACT_CATALOG_IDENTITY", metadata["implementation"],
                      metadata["source"]["revision"], metadata["build"]["configuration"],
                      metadata["gc_policy"]))


def qualification(metadata, cases=CASE_IDS):
    return "\n".join([identity(metadata)] + [
        "\t".join(("XPACT_CATALOG_CASE", case, "PASS", "fixture observation")) for case in cases])


class QualificationProtocolTests(unittest.TestCase):
    def test_accepts_only_the_complete_named_case_set_for_the_expected_build(self):
        metadata = metadata_for()
        rows = runner.validate_qualification(qualification(metadata), metadata)
        self.assertEqual(len(rows), len(CASE_IDS))

    def test_missing_duplicate_failed_and_unexpected_case_output_cannot_qualify(self):
        metadata = metadata_for()
        complete = qualification(metadata)
        invalid = (
            "",
            qualification(metadata, CASE_IDS[:-1]),
            qualification(metadata, CASE_IDS + (CASE_IDS[0],)),
            qualification(metadata, CASE_IDS + ("unselected_case",)),
            complete.replace("\tPASS\t", "\tFAIL\t", 1),
            complete + "\nunverified diagnostics",
            complete + "\n" + identity(metadata),
        )
        for output in invalid:
            with self.subTest(output=output):
                with self.assertRaises(runner.LaneError):
                    runner.validate_qualification(output, metadata)

    def test_other_backend_revision_configuration_and_gc_policy_cannot_borrow_success(self):
        metadata = metadata_for()
        complete = qualification(metadata)
        incorrect = (
            complete.replace("\txpact\t", "\txpact-core\t", 1),
            complete.replace("a" * 40, "c" * 40, 1),
            complete.replace("assertions-off", "assertions-on", 1),
            complete.replace("\tnormal", "\tcore-managed-off-full-collect", 1),
        )
        for output in incorrect:
            with self.subTest(output=output):
                with self.assertRaises(runner.LaneError):
                    runner.validate_qualification(output, metadata)


class CatalogLaneLifecycleTests(unittest.TestCase):
    def setUp(self):
        scratch = REPO / "build/dual-catalog-runner-tests"
        scratch.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="run-", dir=scratch)
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.build_calls = []
        self.qualifications = []
        self.pair_calls = []
        self.metadata = {}
        self.build_failure = None
        self.qualification_failure = None
        self.pair_failure = False
        self.comparison_mutation = None
        self.mutate_after_qualification = False
        self.build_metadata_mutation = None
        self.measurement_finished = False

    def fake_build(self, repo_root, run_root, implementation, tools, environment,
                   compiler_metadata, *, offline=False, profile="probe", assertions=True):
        self.build_calls.append((implementation, profile, assertions, Path(run_root)))
        if (implementation, assertions) == self.build_failure:
            raise runner.builds.BuildError("deliberate build failure")
        destination = Path(run_root) / implementation
        destination.mkdir(parents=True)
        executable = destination / (implementation.replace("-", "_") + "_catalog_benchmark.exe")
        executable.write_bytes((implementation + str(assertions)).encode("ascii"))
        metadata = metadata_for(implementation, assertions)
        metadata.update(executable=str(executable), executable_sha256=runner.builds.file_sha256(executable),
                        build_inputs_sha256=runner.builds.source_fingerprint(REPO, implementation, profile="catalog"),
                        toolchain={"fixture": "compiler metadata"})
        if self.build_metadata_mutation:
            self.build_metadata_mutation(metadata)
        manifest = destination / "build.json"
        manifest.write_text(json.dumps(metadata), encoding="utf-8")
        self.metadata[str(executable)] = metadata
        return {"implementation": implementation, "status": "verified", "manifest": str(manifest)}

    def fake_qualify(self, command, *, cwd=None, env=None, log_path=None, timeout=1200):
        command = [str(value) for value in command]
        self.assertEqual(command[1:], ["--qualify"])
        metadata = self.metadata[command[0]]
        self.qualifications.append(metadata)
        output = qualification(metadata)
        if (metadata["implementation"], metadata["build"]["assertions"]) == self.qualification_failure:
            output = output.replace("\tPASS\t", "\tFAIL\t", 1)
        if log_path:
            Path(log_path).write_text(output, encoding="utf-8")
        if self.mutate_after_qualification and len(self.qualifications) == 4:
            artifact = next(item for item in self.metadata.values()
                            if item["implementation"] == "xpact" and not item["build"]["assertions"])
            Path(artifact["executable"]).write_bytes(b"changed after qualification")
        return output

    def fake_pair(self, argv):
        argv = [str(value) for value in argv]
        self.pair_calls.append(argv)
        def value(option):
            return argv[argv.index(option) + 1]
        count = int(value("--iterations"))
        pairs = int(value("--pairs"))
        results = []
        for pair in range(1, pairs + 1):
            results.append({"Workload": "catalog", "Pair": pair,
                            "Order": "AB" if pair % 2 else "BA", "Iterations": count,
                            "DocumentBytes": 2611, "BaselineElapsedMs": 2.0,
                            "CandidateElapsedMs": 1.0, "BaselineMiBPerSecond": 1.0,
                            "CandidateMiBPerSecond": 2.0, "CandidateSpeedRatio": 2.0})
        report = {
            "metadata": {"executables": {role: {
                "path": value(option), "sha256": runner.builds.file_sha256(value(option))}
                for role, option in (("A", "--baseline"), ("B", "--candidate"))},
                         "workloads": [{"name": "catalog", "document_bytes": 2611}]},
            "calibration": [], "results": results,
            "summary": [{"workload": "catalog", "pairs": pairs, "iterations": count,
                         "document_bytes": 2611, "median_candidate_speed_ratio": 2.0,
                         "min_candidate_speed_ratio": 2.0, "max_candidate_speed_ratio": 2.0,
                         "median_baseline_ms": 2.0, "median_candidate_ms": 1.0,
                         "min_baseline_ms": 2.0, "max_baseline_ms": 2.0,
                         "min_candidate_ms": 1.0, "max_candidate_ms": 1.0}],
        }
        if self.comparison_mutation:
            self.comparison_mutation(report)
        output = Path(value("--output-dir"))
        output.mkdir(parents=True, exist_ok=True)
        runner.paired.publish_reports(output, report)
        self.measurement_finished = True
        return 1 if self.pair_failure else 0

    def invoke(self, name):
        run_root = self.directory / name
        with mock.patch.object(runner.builds, "toolchain", return_value=({}, {}, {})), \
                mock.patch.object(runner.builds, "build_one", side_effect=self.fake_build), \
                mock.patch.object(runner.builds, "run_checked", side_effect=self.fake_qualify), \
                mock.patch.object(runner.paired, "main", side_effect=self.fake_pair), \
                contextlib.redirect_stdout(io.StringIO()), \
                contextlib.redirect_stderr(io.StringIO()):
            result = runner.run_lane(REPO, run_root, offline=True, iterations=10,
                                     pairs=2, warmups=1, min_sample_seconds=0)
        return result, run_root

    def assert_no_numeric_reports(self, run_root):
        for path in (run_root / "report.json", run_root / "summary.md",
                     run_root / "comparison/comparison.json", run_root / "comparison/comparison.tsv"):
            self.assertFalse(path.exists(), str(path))
        self.assertEqual(list(run_root.glob(".summary-*.tmp")), [])

    def test_all_four_builds_qualify_before_only_the_assertion_discarded_catalog_is_measured(self):
        result, output = self.invoke("qualified")
        self.assertEqual(result["status"], "complete")
        self.assertEqual([(impl, profile, assertions) for impl, profile, assertions, _ in self.build_calls],
                         [("xpact", "catalog", True), ("xpact-core", "catalog", True),
                          ("xpact", "catalog", False), ("xpact-core", "catalog", False)])
        self.assertEqual(len(self.qualifications), 4)
        self.assertEqual(len(result["qualification"]), 4)
        self.assertEqual(len(self.pair_calls), 1)
        arguments = self.pair_calls[0]
        self.assertEqual(arguments.count("--workload"), 1)
        self.assertEqual(arguments[arguments.index("--workload") + 1], "catalog")
        for option in ("--baseline", "--candidate"):
            executable = arguments[arguments.index(option) + 1]
            self.assertFalse(self.metadata[executable]["build"]["assertions"])
        self.assertEqual(result["input"]["bytes"], 2611)
        self.assertEqual(result["artifacts"]["xpact"]["gc_policy"], "normal")
        self.assertEqual(result["artifacts"]["xpact-core"]["gc_policy"], "core-managed-off-full-collect")
        summary = (output / "summary.md").read_text(encoding="utf-8")
        self.assertIn("core disables GC internally", summary)
        self.assertIn("that cost is timed", summary)
        self.assertEqual(json.loads((output / "run.json").read_text(encoding="utf-8"))["status"], "complete")

    def test_qualification_failure_keeps_both_backend_evidence_and_never_starts_timing(self):
        self.qualification_failure = ("xpact", True)
        with self.assertRaises(runner.LaneError):
            self.invoke("failed")
        output = self.directory / "failed"
        self.assertEqual(len(self.build_calls), 4)
        self.assertEqual(self.pair_calls, [])
        state = json.loads((output / "run.json").read_text(encoding="utf-8"))
        self.assertEqual(state["status"], "failed")
        self.assertEqual([row["status"] for row in state["builds"]],
                         ["failed", "qualified", "qualified", "qualified"])
        self.assertTrue((output / "audit/xpact/qualification.log").exists())
        self.assert_no_numeric_reports(output)

    def test_success_build_failure_then_retry_preserves_previous_evidence(self):
        _, previous = self.invoke("previous")
        saved = (previous / "report.json").read_bytes()
        self.build_failure = ("xpact-core", False)
        with self.assertRaises(runner.LaneError):
            self.invoke("build-failed")
        self.assert_no_numeric_reports(self.directory / "build-failed")
        self.assertEqual((previous / "report.json").read_bytes(), saved)
        self.build_failure = None
        result, recovered = self.invoke("recovered")
        self.assertEqual(result["status"], "complete")
        self.assertNotEqual(previous, recovered)
        self.assertEqual((previous / "report.json").read_bytes(), saved)

    def test_pair_failure_removes_partial_comparison_and_allows_an_independent_retry(self):
        self.pair_failure = True
        with self.assertRaises(runner.LaneError):
            self.invoke("partial-pairs")
        output = self.directory / "partial-pairs"
        self.assertEqual(len(self.pair_calls), 1)
        self.assert_no_numeric_reports(output)
        state = json.loads((output / "run.json").read_text(encoding="utf-8"))
        self.assertEqual(state["status"], "failed")
        self.pair_failure = False
        self.assertEqual(self.invoke("pair-recovered")[0]["status"], "complete")

    def test_changed_qualified_executable_is_rejected_before_timing(self):
        self.mutate_after_qualification = True
        with self.assertRaisesRegex(runner.LaneError, "Executable changed"):
            self.invoke("mutated")
        self.assertEqual(self.pair_calls, [])
        self.assert_no_numeric_reports(self.directory / "mutated")

    def test_audit_and_benchmark_must_use_the_same_source_snapshot_before_timing(self):
        def different_digest(metadata):
            metadata["build_inputs_sha256"] = "c" * 64
        def different_revision(metadata):
            metadata["source"]["revision"] = "d" * 40
        def different_source_bytes(metadata):
            metadata["source"]["source_sha256"] = "e" * 64
        for index, mutate in enumerate((different_digest, different_revision, different_source_bytes)):
            with self.subTest(mutation=mutate.__name__):
                def change_audit(metadata):
                    if metadata["implementation"] == "xpact" and metadata["build"]["assertions"]:
                        mutate(metadata)
                self.build_metadata_mutation = change_audit
                name = "different-snapshot-" + str(index)
                with self.assertRaisesRegex(runner.LaneError, "different source snapshots"):
                    self.invoke(name)
                self.assertEqual(self.pair_calls, [])
                self.assert_no_numeric_reports(self.directory / name)

    def test_source_change_after_measurement_discards_numeric_results_and_retry_is_fresh(self):
        original_fingerprint = runner.builds.source_fingerprint
        def changed_after_measurement(*args, **kwargs):
            if self.measurement_finished:
                return "f" * 64
            return original_fingerprint(*args, **kwargs)
        with mock.patch.object(runner.builds, "source_fingerprint", side_effect=changed_after_measurement):
            with self.assertRaisesRegex(runner.LaneError, "source inputs changed"):
                self.invoke("source-changed-after-timing")
        output = self.directory / "source-changed-after-timing"
        self.assertEqual(len(self.pair_calls), 1)
        self.assert_no_numeric_reports(output)
        state = json.loads((output / "run.json").read_text(encoding="utf-8"))
        self.assertEqual(state["status"], "failed")
        self.measurement_finished = False
        self.assertEqual(self.invoke("source-change-recovered")[0]["status"], "complete")

    def test_wrong_workload_or_incomplete_pair_report_cannot_publish_a_ratio(self):
        def wrong_workload(report):
            report["metadata"]["workloads"][0]["name"] = "text"
        def incomplete(report):
            report["results"].pop()
        def different_binary(report):
            report["metadata"]["executables"]["B"]["sha256"] = "0" * 64
        def invalid_measurement(report):
            report["results"][0]["CandidateElapsedMs"] = float("nan")
        for index, mutate in enumerate((wrong_workload, incomplete, different_binary, invalid_measurement)):
            with self.subTest(mutation=mutate.__name__):
                self.comparison_mutation = mutate
                name = "invalid-comparison-" + str(index)
                with self.assertRaises(runner.LaneError):
                    self.invoke(name)
                self.assert_no_numeric_reports(self.directory / name)

    def test_summary_persistence_failure_removes_previously_published_numeric_outputs(self):
        original = Path.replace
        def fail_summary(source, destination):
            if Path(destination).name == "summary.md":
                raise OSError("deliberate summary persistence failure")
            return original(source, destination)
        with mock.patch.object(Path, "replace", fail_summary):
            with self.assertRaisesRegex(OSError, "persistence failure"):
                self.invoke("unpublished")
        self.assert_no_numeric_reports(self.directory / "unpublished")
        state = json.loads((self.directory / "unpublished/run.json").read_text(encoding="utf-8"))
        self.assertEqual(state["status"], "failed")
        self.assertEqual(self.invoke("publish-recovered")[0]["status"], "complete")

    def test_occupied_run_directory_is_rejected_before_mutating_previous_evidence(self):
        _, output = self.invoke("occupied")
        files = {path: path.read_bytes() for path in output.rglob("*") if path.is_file()}
        builds_before = len(self.build_calls)
        with self.assertRaises(FileExistsError):
            self.invoke("occupied")
        self.assertEqual(len(self.build_calls), builds_before)
        self.assertEqual({path: path.read_bytes() for path in output.rglob("*") if path.is_file()}, files)

    def test_timed_sample_deadline_is_forwarded_and_timeout_retains_failure_evidence(self):
        executable = self.directory / "fixture.exe"
        executable.write_bytes(b"fixture")
        workload = runner.paired.Workload("catalog", None, 2611, 10)
        output = self.directory / "timeout"
        with mock.patch.object(runner.paired.subprocess, "run", side_effect=subprocess.TimeoutExpired(
                [str(executable)], 3)) as process:
            with self.assertRaises(runner.paired.BenchmarkError):
                runner.paired.run_sample(executable, 10, workload, "catalog-timeout", output, timeout=3)
        self.assertEqual(process.call_args.kwargs["timeout"], 3)
        self.assertIn("timed out", (output / "logs/catalog-timeout.log").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
