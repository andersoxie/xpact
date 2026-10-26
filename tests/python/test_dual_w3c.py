"""Verify dual W3C coverage, result accounting and publication without Eiffel."""

import contextlib
import csv
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
SPEC = importlib.util.spec_from_file_location("run_dual_w3c", SCRIPTS / "run_dual_w3c.py")
runner = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = runner
SPEC.loader.exec_module(runner)


CASE_IDS = ("raw_utf8", "raw_utf16", "namespace_switch", "reuse_recovery", "gc_restoration")


def metadata_for(implementation="xpact", assertions=False):
    return {
        "schema_version": 1, "status": "verified", "profile": "w3c",
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
    return "\t".join(("XPACT_W3C_IDENTITY", metadata["implementation"],
                      metadata["source"]["revision"], metadata["build"]["configuration"],
                      metadata["gc_policy"]))


def qualification(metadata, cases=CASE_IDS, failing=()):
    return "\n".join([identity(metadata)] + [
        "\t".join(("XPACT_W3C_CASE", case, "FAIL" if case in failing else "PASS",
                    "fixture observation")) for case in cases])


class QualificationProtocolTests(unittest.TestCase):
    def test_complete_pass_and_explicit_semantic_failure_preserve_the_named_outcomes(self):
        metadata = metadata_for()
        passed = runner.validate_qualification(qualification(metadata), metadata, returncode=0)
        self.assertEqual([row["case_id"] for row in passed], list(CASE_IDS))
        self.assertTrue(all(row["status"] == "PASS" for row in passed))
        failed = runner.validate_qualification(
            qualification(metadata, failing=("raw_utf16",)), metadata, returncode=1)
        self.assertEqual([row["case_id"] for row in failed if row["status"] == "FAIL"], ["raw_utf16"])

    def test_missing_duplicate_extra_case_or_arbitrary_output_is_protocol_error(self):
        metadata = metadata_for()
        complete = qualification(metadata)
        invalid = ("", qualification(metadata, CASE_IDS[:-1]),
                   qualification(metadata, CASE_IDS + (CASE_IDS[0],)),
                   qualification(metadata, CASE_IDS + ("unknown_case",)),
                   complete + "\n" + identity(metadata), complete + "\nunverified output")
        for output in invalid:
            with self.subTest(output=output):
                with self.assertRaises(runner.LaneError):
                    runner.validate_qualification(output, metadata, returncode=0)

    def test_wrong_build_identity_or_inconsistent_exit_cannot_borrow_a_verdict(self):
        metadata = metadata_for()
        complete = qualification(metadata)
        invalid = ((complete.replace("\txpact\t", "\txpact-core\t", 1), 0),
                   (complete.replace("a" * 40, "c" * 40, 1), 0),
                   (complete.replace("assertions-off", "assertions-on", 1), 0),
                   (complete.replace("\tnormal", "\tcore-managed-off-full-collect", 1), 0),
                   (complete, 1), (complete, 2),
                   (qualification(metadata, failing=("raw_utf8",)), 0))
        for output, code in invalid:
            with self.subTest(code=code, output=output):
                with self.assertRaises(runner.LaneError):
                    runner.validate_qualification(output, metadata, returncode=code)


class W3CLaneLifecycleTests(unittest.TestCase):
    def setUp(self):
        scratch = REPO / "build/dual-w3c-runner-tests"
        scratch.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="run-", dir=scratch)
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.suite = self.directory / "original suite with spaces"
        self.suite.mkdir()
        self.documents = {
            "good.xml": b"\xff\xfe<\x00r\x00/\x00>\x00",
            "broken.xml": b"<r>",
            "no-namespace.xml": b"<a:b:c/>",
            "excluded.xml": b"<!DOCTYPE r SYSTEM 'never-open.dtd'><r/>",
        }
        for name, content in self.documents.items():
            (self.suite / name).write_bytes(content)
        (self.suite / "xmlconf.xml").write_text(
            '<TESTSUITE><TESTCASES>'
            '<TEST ID="utf16-valid" TYPE="valid" URI="good.xml"/>'
            '<TEST ID="malformed" TYPE="not-wf" URI="broken.xml"/>'
            '<TEST ID="namespace-optout" TYPE="valid" NAMESPACE="no" URI="no-namespace.xml"/>'
            '<TEST ID="profile-exclusion" TYPE="valid" ENTITIES="general" URI="excluded.xml"/>'
            '</TESTCASES></TESTSUITE>', encoding="utf-8")
        self.original_files = self.snapshot()
        self.build_calls = []
        self.qualifications = []
        self.parser_calls = []
        self.parser_workdirs = []
        self.metadata = {}
        self.build_failure = None
        self.qualification_failure = None
        self.qualification_protocol_error = False
        self.qualifier_behavior = None
        self.case_behavior = {}
        self.metadata_mutation = None
        self.mutate_binary = False
        self.mutate_suite = False
        self.mutate_current_input = False
        self.qualification_start = 0
        self.parser_start = 0
        self.execution_complete = False

    def snapshot(self):
        return {path.relative_to(self.suite).as_posix(): path.read_bytes()
                for path in self.suite.rglob("*") if path.is_file()}

    def fake_build(self, repo_root, run_root, implementation, tools, environment,
                   compiler_metadata, *, offline=False, profile="probe", assertions=True):
        self.build_calls.append((implementation, profile, assertions))
        if (implementation, assertions) == self.build_failure:
            raise runner.builds.BuildError("deliberate build failure")
        destination = Path(run_root) / implementation
        destination.mkdir(parents=True)
        executable = destination / (implementation.replace("-", "_") + "_w3c_conformance.exe")
        executable.write_bytes((implementation + str(assertions)).encode("ascii"))
        metadata = metadata_for(implementation, assertions)
        metadata.update(executable=str(executable), executable_sha256=runner.builds.file_sha256(executable),
                        build_inputs_sha256=runner.builds.source_fingerprint(REPO, implementation, profile="w3c"),
                        toolchain={"fixture": "compiler metadata"})
        if self.metadata_mutation:
            self.metadata_mutation(metadata)
        manifest = destination / "build.json"
        manifest.write_text(json.dumps(metadata), encoding="utf-8")
        self.metadata[str(executable)] = metadata
        return {"implementation": implementation, "status": "verified", "manifest": str(manifest)}

    def fake_process(self, command, **kwargs):
        command = [str(value) for value in command]
        metadata = self.metadata[command[0]]
        implementation = metadata["implementation"]
        if command[1:] == ["--qualify"]:
            self.qualifications.append(metadata)
            failing = CASE_IDS[:1] if (implementation, metadata["build"]["assertions"]) == self.qualification_failure else ()
            output = qualification(metadata, failing=failing)
            if self.qualification_protocol_error:
                output += "\nunexpected native output"
            if (implementation, metadata["build"]["assertions"]) == ("xpact-core", True):
                if self.qualifier_behavior == "timeout":
                    raise subprocess.TimeoutExpired(command, kwargs["timeout"], output=b"partial qualifier output")
                if self.qualifier_behavior == "crash":
                    return subprocess.CompletedProcess(command, 0xC0000409,
                                                       (identity(metadata) + "\n").encode("utf-8"),
                                                       b"directed audit contract exception")
                if self.qualifier_behavior == "partial":
                    return subprocess.CompletedProcess(command, 0,
                                                       qualification(metadata, CASE_IDS[:1]).encode("utf-8"), b"")
            if self.mutate_binary and len(self.qualifications) - self.qualification_start == 4:
                own = next(item for item in self.metadata.values()
                           if item["implementation"] == "xpact" and not item["build"]["assertions"])
                Path(own["executable"]).write_bytes(b"changed after qualification")
            return subprocess.CompletedProcess(command, 1 if failing else 0,
                                               output.encode("utf-8"), b"")
        self.assertEqual(command[1], "--conformance-file")
        self.assertFalse(metadata["build"]["assertions"], "The full W3C lane must use the OFF builds")
        self.assertEqual(len(self.qualifications) - self.qualification_start, 4,
                         "Every audit and benchmark must be qualified first")
        path = Path(command[2])
        self.assertEqual(path.read_bytes(), self.documents[path.name], "W3C bytes must not be rewritten")
        work = Path(kwargs["cwd"])
        self.assertTrue(work.is_dir(), "Each parser cwd must exist before the native process starts")
        self.assertEqual(work.parent.name, implementation)
        self.assertEqual(work.parent.parent.name, "work")
        self.parser_workdirs.append(work)
        (work / "exception_trace.log").write_text(implementation + "/" + path.name, encoding="utf-8")
        self.parser_calls.append((implementation, path.name, "--namespaces" in command, kwargs["timeout"]))
        self.execution_complete = len(self.parser_calls) - self.parser_start >= 6
        if self.mutate_suite:
            (self.suite / "excluded.xml").write_bytes(b"mutated profile-excluded input")
        if self.mutate_current_input:
            path.write_bytes(b"changed while this case was running")
            self.mutate_current_input = False
        behavior = self.case_behavior.get((implementation, path.name))
        if behavior == "timeout":
            raise subprocess.TimeoutExpired(command, kwargs["timeout"], output=b"partial stdout", stderr=b"partial stderr")
        if behavior == "crash":
            return subprocess.CompletedProcess(command, 0xC0000409, b"", b"fixture crash detail")
        expected = "REJECT" if path.name == "broken.xml" else "ACCEPT"
        actual = ("ACCEPT" if expected == "REJECT" else "REJECT") if behavior == "wrong" else expected
        return subprocess.CompletedProcess(command, 0 if actual == "ACCEPT" else 1,
                                           ("XPACT_CONFORMANCE\t" + actual + "\n").encode("ascii"), b"")

    def invoke(self, name):
        run_root = self.directory / name
        self.qualification_start = len(self.qualifications)
        self.parser_start = len(self.parser_calls)
        self.execution_complete = False
        with mock.patch.object(runner.builds, "toolchain", return_value=({}, {}, {})), \
                mock.patch.object(runner.builds, "build_one", side_effect=self.fake_build), \
                mock.patch.object(runner.subprocess, "run", side_effect=self.fake_process), \
                mock.patch.object(runner.w3c, "prepare_suite") as prepare, \
                contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            result = runner.run_lane(REPO, run_root, suite_dir=self.suite, offline=True, timeout_seconds=2)
        prepare.assert_not_called()
        return result, run_root

    def results(self, run_root):
        with (run_root / "conformance/results.tsv").open(encoding="utf-8", newline="") as source:
            return list(csv.DictReader(source, delimiter="\t"))

    def assert_no_complete_reports(self, run_root):
        self.assertFalse((run_root / "report.json").exists())
        self.assertFalse((run_root / "comparison.tsv").exists())
        if (run_root / "run.json").exists():
            self.assertEqual(json.loads((run_root / "run.json").read_text())["status"], "failed")

    def test_complete_matrix_preserves_ids_verdicts_profile_exclusions_and_original_bytes(self):
        report, output = self.invoke("complete")
        self.assertEqual(report["status"], "complete")
        self.assertEqual(self.build_calls, [("xpact", "w3c", True), ("xpact-core", "w3c", True),
                                           ("xpact", "w3c", False), ("xpact-core", "w3c", False)])
        rows = self.results(output)
        self.assertEqual(len(rows), 8)
        by_key = {(row["engine"], row["case_id"]): row for row in rows}
        self.assertEqual(set(by_key), {(engine, case) for engine in ("xpact", "xpact-core")
                                      for case in ("utf16-valid", "malformed", "namespace-optout", "profile-exclusion")})
        for engine in ("xpact", "xpact-core"):
            self.assertEqual(by_key[engine, "malformed"]["status"], "passed")
            self.assertEqual(by_key[engine, "malformed"]["actual"], "REJECT")
            skipped = by_key[engine, "profile-exclusion"]
            self.assertEqual((skipped["status"], skipped["actual"]), ("skipped", "not-run"))
            self.assertIn("resolver is disabled", skipped["message"])
            self.assertTrue(all(not row["known"] for row in rows if row["engine"] == engine))
        self.assertEqual(len(self.parser_calls), 6)
        self.assertEqual({(name, ns) for _, name, ns, _ in self.parser_calls},
                         {("good.xml", True), ("broken.xml", True), ("no-namespace.xml", False)})
        self.assertTrue(all(timeout == 2 for *_, timeout in self.parser_calls))
        self.assertEqual(len(set(self.parser_workdirs)), 6,
                         "Native exception traces must be isolated by implementation and case")
        for work, (implementation, name, _, _) in zip(self.parser_workdirs, self.parser_calls):
            self.assertEqual((work / "exception_trace.log").read_text(encoding="utf-8"), implementation + "/" + name)
            self.assertTrue((work / "stdout.bin").is_file())
            self.assertTrue((work / "stderr.bin").is_file())
            evidence = json.loads((work / "result.json").read_text(encoding="utf-8"))
            self.assertEqual(Path(evidence["command"][2]).name, name)
            self.assertEqual(evidence["result"]["engine"], implementation)
        self.assertEqual(self.snapshot(), self.original_files)
        with (output / "comparison.tsv").open(encoding="utf-8", newline="") as source:
            comparison = list(csv.DictReader(source, delimiter="\t"))
        self.assertEqual({row["case_id"] for row in comparison},
                         {"utf16-valid", "malformed", "namespace-optout", "profile-exclusion"})

    def test_semantic_qualifier_failure_is_visible_and_does_not_hide_full_suite_cases(self):
        self.qualification_failure = ("xpact-core", True)
        report, output = self.invoke("qualifier-failed")
        self.assertEqual(report["status"], "complete_with_failures")
        self.assertEqual(len(self.parser_calls), 6)
        self.assertEqual(len(self.results(output)), 8)
        serialized = json.dumps(report)
        self.assertIn('"FAIL"', serialized)
        self.assertIn("raw_utf8", serialized)
        self.assertIn("Exit code: 1", (output / "audit/xpact-core/qualification.log").read_text(encoding="utf-8"))

    def test_wrong_verdict_crash_and_timeout_remain_gaps_and_other_engine_continues(self):
        self.case_behavior[("xpact-core", "good.xml")] = "wrong"
        self.case_behavior[("xpact-core", "broken.xml")] = "crash"
        self.case_behavior[("xpact-core", "no-namespace.xml")] = "timeout"
        report, output = self.invoke("parser-gaps")
        self.assertEqual(report["status"], "complete_with_failures")
        rows = self.results(output)
        core = {row["case_id"]: row for row in rows if row["engine"] == "xpact-core"}
        self.assertEqual((core["utf16-valid"]["status"], core["utf16-valid"]["actual"]), ("failed", "REJECT"))
        self.assertEqual((core["malformed"]["status"], core["malformed"]["actual"]), ("error", "process-error"))
        self.assertEqual((core["namespace-optout"]["status"], core["namespace-optout"]["actual"]), ("error", "timeout"))
        self.assertTrue(all(not row["known"] for row in rows))
        self.assertEqual(len(rows), 8)
        self.assertEqual(len(self.parser_calls), 6)
        self.assertEqual(self.snapshot(), self.original_files)
        logs = list(output.rglob("stderr.bin"))
        self.assertTrue(any(b"fixture crash detail" in log.read_bytes() for log in logs))
        self.assertEqual(core["malformed"]["exit_code"], str(0xC0000409))
        self.assertTrue(any(b"partial stderr" in log.read_bytes() for log in logs))
        self.assertTrue(any(b"partial stdout" in log.read_bytes() for log in output.rglob("stdout.bin")))

    def test_identical_wrong_parser_verdicts_are_still_failures(self):
        for implementation in ("xpact", "xpact-core"):
            self.case_behavior[(implementation, "broken.xml")] = "wrong"
        report, output = self.invoke("matching-parser-bugs")
        self.assertEqual(report["status"], "complete_with_failures")
        malformed = [row for row in self.results(output) if row["case_id"] == "malformed"]
        self.assertEqual(len(malformed), 2)
        self.assertTrue(all(row["status"] == "failed" and row["actual"] == "ACCEPT" for row in malformed))

    def test_build_failure_cannot_publish_complete_case_comparison(self):
        self.build_failure = ("xpact", True)
        with self.assertRaises(runner.LaneError):
            self.invoke("build-failed")
        self.assertEqual(self.parser_calls, [])
        self.assert_no_complete_reports(self.directory / "build-failed")

    def test_bad_qualifier_protocol_remains_visible_without_hiding_catalog_cases(self):
        self.qualification_protocol_error = True
        report, output = self.invoke("protocol-failed")
        self.assertEqual(report["status"], "complete_with_failures")
        self.assertEqual(len(self.results(output)), 8)
        self.assertEqual(len(self.parser_calls), 6)
        self.assertTrue(all(row.get("qualification_error") and not row["cases"]
                            for row in report["qualification"]))

    def test_qualifier_crash_partial_output_or_timeout_cannot_hide_full_counterpart_matrix(self):
        for behavior in ("crash", "partial", "timeout"):
            with self.subTest(behavior=behavior):
                self.qualifier_behavior = behavior
                report, output = self.invoke("qualifier-" + behavior)
                self.assertEqual(report["status"], "complete_with_failures")
                rows = self.results(output)
                self.assertEqual(len(rows), 8)
                failed_control = [row for row in report["qualification"] if row.get("qualification_error")]
                self.assertEqual(len(failed_control), 1)
                self.assertEqual((failed_control[0]["implementation"], failed_control[0]["assertions"]),
                                 ("xpact-core", True))
                self.assertEqual(failed_control[0]["cases"], [])
                log = (output / "audit/xpact-core/qualification.log").read_text(encoding="utf-8")
                if behavior == "crash":
                    self.assertIn("Exit code: " + str(0xC0000409), log)
                    self.assertIn("directed audit contract exception", log)
                elif behavior == "partial":
                    self.assertIn("Exit code: 0", log)
                    self.assertIn("XPACT_W3C_CASE\traw_utf8\tPASS", log)
                else:
                    self.assertIn("partial qualifier output", log)
                self.assertEqual(len(self.parser_calls) - self.parser_start, 6)

    def test_changed_qualified_binary_prevents_case_execution(self):
        self.mutate_binary = True
        with self.assertRaises(runner.LaneError):
            self.invoke("binary-changed")
        self.assertEqual(self.parser_calls, [])
        self.assert_no_complete_reports(self.directory / "binary-changed")

    def test_audit_and_off_source_mismatch_cannot_be_qualified_as_one_snapshot(self):
        def change(metadata):
            if metadata["implementation"] == "xpact" and metadata["build"]["assertions"]:
                metadata["build_inputs_sha256"] = "c" * 64
        self.metadata_mutation = change
        with self.assertRaises(runner.LaneError):
            self.invoke("source-mismatch")
        self.assertEqual(self.parser_calls, [])
        self.assert_no_complete_reports(self.directory / "source-mismatch")

    def test_profile_excluded_input_mutation_invalidates_run_and_fresh_retry_recovers(self):
        self.mutate_suite = True
        with self.assertRaises(runner.LaneError):
            self.invoke("suite-mutated")
        self.assert_no_complete_reports(self.directory / "suite-mutated")
        self.assertTrue(self.parser_calls)
        self.assertEqual({implementation for implementation, *_ in self.parser_calls}, {"xpact"})
        (self.suite / "excluded.xml").write_bytes(self.documents["excluded.xml"])
        self.mutate_suite = False
        self.assertEqual(self.invoke("suite-recovered")[0]["status"], "complete")
        self.assertEqual(self.snapshot(), self.original_files)

    def test_input_mutation_during_first_case_stops_before_counterpart_then_clean_retry_recovers(self):
        self.mutate_current_input = True
        with self.assertRaisesRegex(runner.LaneError, "input bytes changed"):
            self.invoke("case-input-mutated")
        self.assertEqual(self.parser_calls, [("xpact", "good.xml", True, 2)])
        self.assert_no_complete_reports(self.directory / "case-input-mutated")
        self.assertTrue((self.parser_workdirs[0] / "result.json").is_file(),
                        "Failed integrity validation must preserve the observed native result")
        (self.suite / "good.xml").write_bytes(self.documents["good.xml"])
        report, output = self.invoke("case-input-restored")
        self.assertEqual(report["status"], "complete")
        self.assertEqual(len(self.results(output)), 8)
        self.assertEqual(self.snapshot(), self.original_files)

    def test_missing_referenced_input_has_a_case_error_for_each_engine_and_others_continue(self):
        catalog = self.suite / "xmlconf.xml"
        catalog.write_text(catalog.read_text().replace(
            "</TESTCASES>", '<TEST ID="missing-input" TYPE="valid" URI="missing.xml"/></TESTCASES>'),
            encoding="utf-8")
        expected_files = self.snapshot()
        report, output = self.invoke("missing-input")
        self.assertEqual(report["status"], "complete_with_failures")
        rows = self.results(output)
        self.assertEqual(len(rows), 10)
        missing = [row for row in rows if row["case_id"] == "missing-input"]
        self.assertEqual({row["engine"] for row in missing}, {"xpact", "xpact-core"})
        self.assertTrue(all(row["status"] == "error" and "missing" in row["message"] for row in missing))
        self.assertEqual(len(self.parser_calls), 6)
        self.assertEqual(self.snapshot(), expected_files)

    def test_source_change_after_case_execution_cannot_publish_complete_comparison(self):
        original = runner.builds.source_fingerprint
        def changed_after_cases(*args, **kwargs):
            return "f" * 64 if self.execution_complete else original(*args, **kwargs)
        with mock.patch.object(runner.builds, "source_fingerprint", changed_after_cases):
            with self.assertRaises(runner.LaneError):
                self.invoke("wrapper-source-changed")
        self.assert_no_complete_reports(self.directory / "wrapper-source-changed")
        self.assertEqual(self.invoke("wrapper-source-recovered")[0]["status"], "complete")

    def test_output_inside_suite_is_rejected_before_mutating_input_tree(self):
        original_files = self.snapshot()
        with mock.patch.object(runner.builds, "toolchain") as tools:
            with self.assertRaises((runner.LaneError, ValueError)):
                runner.run_lane(REPO, self.suite / "new run", suite_dir=self.suite, offline=True)
        tools.assert_not_called()
        self.assertEqual(self.snapshot(), original_files)
        self.assertFalse((self.suite / "new run").exists())

    def test_diagnostic_write_failure_is_infrastructure_error_and_does_not_become_parser_gap(self):
        original = Path.write_bytes
        def fail_output(path, content):
            if path.name == "stdout.bin":
                raise OSError("deliberate diagnostic persistence failure")
            return original(path, content)
        with mock.patch.object(Path, "write_bytes", fail_output):
            with self.assertRaisesRegex(OSError, "diagnostic persistence failure"):
                self.invoke("diagnostic-unpublished")
        self.assert_no_complete_reports(self.directory / "diagnostic-unpublished")

    def test_final_report_failure_preserves_prior_run_and_leaves_no_new_success(self):
        _, previous = self.invoke("previous")
        old_files = {path: path.read_bytes() for path in previous.rglob("*") if path.is_file()}
        original = Path.replace
        def fail_report(path, destination):
            if Path(destination).name == "report.json":
                raise OSError("deliberate final report persistence failure")
            return original(path, destination)
        with mock.patch.object(Path, "replace", fail_report):
            with self.assertRaisesRegex(OSError, "final report persistence failure"):
                self.invoke("report-unpublished")
        self.assert_no_complete_reports(self.directory / "report-unpublished")
        self.assertEqual({path: path.read_bytes() for path in previous.rglob("*") if path.is_file()}, old_files)
        self.assertEqual(self.invoke("report-recovered")[0]["status"], "complete")

    def test_reusing_run_directory_cannot_overwrite_prior_results_or_inputs(self):
        _, previous = self.invoke("occupied")
        old_files = {path: path.read_bytes() for path in previous.rglob("*") if path.is_file()}
        calls = len(self.build_calls)
        with self.assertRaises(FileExistsError):
            self.invoke("occupied")
        self.assertEqual(len(self.build_calls), calls)
        self.assertEqual({path: path.read_bytes() for path in previous.rglob("*") if path.is_file()}, old_files)
        self.assertEqual(self.snapshot(), self.original_files)


class ResultMatrixIntegrityTests(unittest.TestCase):
    def setUp(self):
        self.cases = [runner.w3c.Case("valid", Path("valid.xml"), "valid", True, "ACCEPT"),
                      runner.w3c.Case("excluded", Path("excluded.xml"), "valid", True, "ACCEPT", "outside profile")]
        self.results = []
        for engine in ("xpact", "xpact-core"):
            self.results += [runner.w3c.Result(engine, "valid", "valid.xml", "valid", "ACCEPT", "ACCEPT", "passed", exit_code=0),
                             runner.w3c.Result(engine, "excluded", "excluded.xml", "valid", "ACCEPT", "not-run", "skipped",
                                               message="outside profile")]

    def test_complete_consistent_matrix_includes_both_process_exit_codes(self):
        rows = runner.comparison_rows(self.cases, self.results)
        self.assertEqual(len(rows), 2)
        self.assertEqual((rows[0]["xpact_exit_code"], rows[0]["core_exit_code"]), (0, 0))
        self.assertTrue(rows[0]["agreement"])

    def test_status_verdict_and_native_exit_code_must_agree(self):
        from dataclasses import replace
        mutations = ({"status": "failed"}, {"actual": "REJECT", "exit_code": 1},
                     {"exit_code": 1}, {"exit_code": None}, {"exit_code": 0xC0000409},
                     {"status": "failed", "actual": "REJECT", "exit_code": 0})
        for changed in mutations:
            rows = self.results.copy()
            rows[0] = replace(rows[0], **changed)
            with self.subTest(change=changed):
                with self.assertRaisesRegex(runner.LaneError, "inconsistent"):
                    runner.comparison_rows(self.cases, rows)

    def test_missing_duplicate_or_extra_counterpart_cannot_form_complete_comparison(self):
        bad = (self.results[:-1], self.results + [self.results[0]],
               self.results + [runner.w3c.Result("other", "valid", "", "valid", "ACCEPT", "ACCEPT", "passed")])
        for rows in bad:
            with self.subTest(length=len(rows)):
                with self.assertRaises(runner.LaneError):
                    runner.comparison_rows(self.cases, rows)

    def test_changed_expectation_suppressed_failure_or_forged_exclusion_is_rejected(self):
        from dataclasses import replace
        mutations = ((0, {"expected": "REJECT"}), (0, {"known": "unapproved allowlist"}),
                     (0, {"status": "skipped", "actual": "not-run"}),
                     (1, {"status": "passed", "actual": "ACCEPT"}),
                     (1, {"message": "different exclusion for this backend"}))
        for index, changed in mutations:
            rows = self.results.copy()
            rows[index] = replace(rows[index], **changed)
            with self.subTest(change=changed):
                with self.assertRaises(runner.LaneError):
                    runner.comparison_rows(self.cases, rows)


class CliExitTests(unittest.TestCase):
    def test_success_parser_gaps_and_infrastructure_failure_have_distinct_exit_codes(self):
        for outcome, expected in (({"status": "complete"}, 0),
                                  ({"status": "complete_with_failures"}, 1),
                                  (runner.LaneError("deliberate setup error"), 2)):
            with self.subTest(outcome=outcome), \
                    mock.patch.object(runner, "run_lane", side_effect=(outcome if isinstance(outcome, Exception) else None),
                                      return_value=outcome) as lane, \
                    contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(runner.main(["--offline", "--timeout", "2"]), expected)
            self.assertEqual(lane.call_args.kwargs["timeout_seconds"], 2)
            self.assertTrue(lane.call_args.kwargs["offline"])


if __name__ == "__main__":
    unittest.main()
