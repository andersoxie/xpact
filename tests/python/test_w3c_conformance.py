"""Regression tests for the W3C catalog importer and verdict/report harness.

These fixtures are local and use only the standard library; no W3C download or
Eiffel installation is needed to verify the orchestration logic.
"""

from __future__ import annotations

import contextlib
import csv
from dataclasses import replace
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import xml.etree.ElementTree as ET
from xml.parsers import expat
import zipfile


SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "run_w3c_conformance.py"
SPEC = importlib.util.spec_from_file_location("run_w3c_conformance", SCRIPT)
runner = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = runner
SPEC.loader.exec_module(runner)


class TemporarySuite(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="xpact-w3c-tests-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.suite = self.root / "xmlconf"
        self.suite.mkdir()
        self.output = self.root / "reports"

    def write(self, relative: str, data: str | bytes) -> Path:
        path = self.suite / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data if isinstance(data, bytes) else data.encode("utf-8"))
        return path

    def catalog(self, tests: str):
        return self.write("xmlconf.xml", f"<TESTSUITE><TESTCASES>{tests}</TESTCASES></TESTSUITE>")

    def case(self, *, expected="ACCEPT", namespaces=True):
        path = self.write("document with spaces.xml", b"\xff\xfe<\x00r\x00/\x00>\x00")
        return runner.Case("case", path, "valid" if expected == "ACCEPT" else "not-wf",
                           namespaces, expected)


class CatalogTests(TemporarySuite):
    def test_entities_dtd_defaults_nested_bases_and_original_bytes(self):
        self.write("testcases.dtd", '<!ATTLIST TEST ENTITIES CDATA "none" '
                   'RECOMMENDATION CDATA "XML1.0" NAMESPACE CDATA "yes">')
        self.write("xmlconf.xml", '''<!DOCTYPE TESTSUITE SYSTEM "testcases.dtd" [
<!ENTITY supplier SYSTEM "supplier/catalog.xml">]>
<TESTSUITE><TESTCASES xml:base="supplier/">&supplier;</TESTCASES></TESTSUITE>''')
        self.write("supplier/catalog.xml", '''<?xml version="1.0" encoding="ISO-8859-1"?>
<TESTCASES xml:base="data/">
<TEST ID="default" TYPE="valid" URI="latin.xml">café <EM>description</EM></TEST>
<TEST ID="no-namespace" TYPE="invalid" URI="colons.xml" NAMESPACE="no"/>
<!-- <TEST ID="commented-out" TYPE="not-wf" URI="unused.xml"/> -->
</TESTCASES>'''.encode("iso-8859-1"))
        original = b'<?xml version="1.0" encoding="ISO-8859-1"?><r>\xe9</r>'
        path = self.write("supplier/data/latin.xml", original)
        self.write("supplier/data/colons.xml", "<a:b:c/>")

        cases = runner.load_catalog(self.suite)

        self.assertEqual([case.id for case in cases], ["default", "no-namespace"])
        self.assertEqual(cases[0].path, path.resolve())
        self.assertEqual((cases[0].expected, cases[0].skip_reason), ("ACCEPT", ""))
        self.assertEqual(cases[0].recommendation, "XML1.0")
        self.assertTrue(cases[0].namespaces)
        self.assertIn("café", cases[0].description)
        self.assertFalse(cases[1].namespaces)
        self.assertEqual(cases[1].expected, "ACCEPT")
        self.assertEqual(path.read_bytes(), original)

    def test_duplicate_ids_and_empty_catalog_are_setup_errors(self):
        for tests in ('<TEST ID="dup" TYPE="valid" URI="a.xml"/>' * 2, ""):
            with self.subTest(tests=tests):
                self.catalog(tests)
                with self.assertRaises(ValueError):
                    runner.load_catalog(self.suite)

    def test_network_and_parent_paths_are_rejected(self):
        for reference in ("https://example.com/input.xml", "../outside.xml", "file://server/input.xml"):
            with self.subTest(reference=reference):
                self.catalog(f'<TEST ID="escape" TYPE="valid" URI="{reference}"/>')
                with self.assertRaises(ValueError):
                    runner.load_catalog(self.suite)

    def test_external_catalog_entities_cannot_access_network_or_parent(self):
        for reference in ("https://example.com/catalog.xml", "../outside.xml"):
            with self.subTest(reference=reference):
                self.write("xmlconf.xml", f'''<!DOCTYPE TESTSUITE [
<!ENTITY remote SYSTEM "{reference}">]><TESTSUITE>&remote;</TESTSUITE>''')
                with self.assertRaises(ValueError):
                    runner.load_catalog(self.suite)

    def test_inherited_network_base_is_rejected_even_for_empty_group(self):
        self.write("xmlconf.xml", '<TESTSUITE><TESTCASES xml:base="https://example.com/"/></TESTSUITE>')
        with self.assertRaises(ValueError):
            runner.load_catalog(self.suite)

    def test_unpinned_bad_encoding_is_not_silently_repaired(self):
        self.write("xmlconf.xml", b'<?xml version="1.0" encoding="UTF-8"?>'
                   b'<!-- caf\xe9 --><TESTSUITE><TEST ID="a" TYPE="valid" URI="a.xml"/></TESTSUITE>')
        with self.assertRaises(expat.ExpatError):
            runner.load_catalog(self.suite)


class ExpectationTests(unittest.TestCase):
    def test_nonvalidating_binary_expectations(self):
        for kind, expected in (("valid", "ACCEPT"), ("invalid", "ACCEPT"), ("not-wf", "REJECT")):
            with self.subTest(kind=kind):
                self.assertEqual(runner.expectation({"TYPE": kind}), (expected, ""))

    def test_out_of_profile_cases_have_explicit_skip_reason(self):
        for attributes in (
            {"VERSION": "1.1"}, {"EDITION": "1 2 3 4"},
            {"RECOMMENDATION": "XML1.1"}, {"RECOMMENDATION": "NS1.1"},
            {"ENTITIES": "general"}, {"ENTITIES": "parameter"}, {"ENTITIES": "both"},
            {"TYPE": "error"},
        ):
            with self.subTest(attributes=attributes):
                _, reason = runner.expectation({"TYPE": "not-wf", **attributes})
                self.assertTrue(reason)
        self.assertEqual(runner.expectation({"TYPE": "error"})[0], "unspecified")

    def test_lists_containing_supported_version_and_edition_remain_applicable(self):
        self.assertEqual(runner.expectation({"TYPE": "valid", "VERSION": "1.0 1.1", "EDITION": "4 5"}),
                         ("ACCEPT", ""))
        self.assertEqual(runner.expectation({"TYPE": "not-wf", "RECOMMENDATION": "NS1.0"}),
                         ("REJECT", ""))

    def test_unknown_metadata_does_not_become_a_pass(self):
        for attributes in ({"TYPE": "unknown"}, {"RECOMMENDATION": "XML2.0"}, {"ENTITIES": "unknown"}):
            with self.subTest(attributes=attributes), self.assertRaises(ValueError):
                runner.expectation({"TYPE": "valid", **attributes})


class ExecutionTests(TemporarySuite):
    def invoke(self, case, completed=None, error=None):
        with mock.patch.object(runner.subprocess, "run", return_value=completed, side_effect=error) as process:
            result = runner.run_case(case, "xpact", Path("parser.exe"), 0.25, self.root)
        return result, process

    def test_original_binary_path_and_namespace_switch_are_passed_as_arguments(self):
        case = self.case()
        original = case.path.read_bytes()
        completed = subprocess.CompletedProcess([], 0, b"XPACT_CONFORMANCE\tACCEPT\n", b"")
        result, process = self.invoke(case, completed)
        self.assertEqual((result.status, result.actual), ("passed", "ACCEPT"))
        self.assertEqual(process.call_args.args[0],
                         ["parser.exe", "--conformance-file", str(case.path), "--namespaces"])
        self.assertEqual(process.call_args.kwargs["cwd"], self.root)
        self.assertEqual(process.call_args.kwargs["timeout"], 0.25)
        self.assertNotIn("input", process.call_args.kwargs)
        self.assertEqual(case.path.read_bytes(), original)

    def test_expected_rejection_is_a_pass_and_namespace_opt_out_is_preserved(self):
        completed = subprocess.CompletedProcess([], 1, b"diagnostic\nXPACT_CONFORMANCE\tREJECT\n", b"")
        result, process = self.invoke(self.case(expected="REJECT", namespaces=False), completed)
        self.assertEqual((result.status, result.actual), ("passed", "REJECT"))
        self.assertNotIn("--namespaces", process.call_args.args[0])

    def test_incorrect_binary_verdict_is_a_conformance_failure(self):
        completed = subprocess.CompletedProcess([], 0, b"XPACT_CONFORMANCE\tACCEPT\n", b"")
        result, _ = self.invoke(self.case(expected="REJECT"), completed)
        self.assertEqual(result.status, "failed")
        self.assertIn("Expected REJECT, got ACCEPT", result.message)

    def test_crash_or_invalid_protocol_cannot_pass_a_negative_case(self):
        case = self.case(expected="REJECT")
        for code, stdout in (
            (1, b"Eiffel exception\n"), (-11, b""), (2, b"XPACT_CONFORMANCE\tREJECT\n"),
            (0, b"XPACT_CONFORMANCE\tREJECT\n"), (1, b"XPACT_CONFORMANCE\tACCEPT\n"),
            (1, b"XPACT_CONFORMANCE\tREJECT\nXPACT_CONFORMANCE\tREJECT\n"),
        ):
            with self.subTest(code=code, stdout=stdout):
                result, _ = self.invoke(case, subprocess.CompletedProcess([], code, stdout, b"\xff\x00"))
                self.assertEqual((result.status, result.actual), ("error", "process-error"))

    def test_timeout_and_launch_failure_are_errors(self):
        case = self.case(expected="REJECT")
        for error, actual in ((subprocess.TimeoutExpired("parser", 0.25), "timeout"),
                              (OSError("cannot launch"), "process-error")):
            with self.subTest(error=error):
                result, _ = self.invoke(case, error=error)
                self.assertEqual((result.status, result.actual), ("error", actual))

    def test_skipped_and_missing_inputs_do_not_launch_parser(self):
        case = self.case()
        for changed, status in ((replace(case, skip_reason="Unsupported XML 1.1"), "skipped"),
                                (replace(case, path=self.suite / "missing.xml"), "error")):
            with self.subTest(status=status):
                result, process = self.invoke(changed)
                self.assertEqual(result.status, status)
                self.assertEqual(result.actual, "not-run")
                process.assert_not_called()


class ReportAndCliTests(TemporarySuite):
    def test_junit_and_summary_reconcile_failure_error_skip_and_verdict_counts(self):
        rows = [
            runner.Result("xpact", "accept", "a.xml", "valid", "ACCEPT", "ACCEPT", "passed", 12),
            runner.Result("xpact", "reject", "b.xml", "not-wf", "REJECT", "REJECT", "passed", 4),
            runner.Result("xpact", "wrong", "c.xml", "not-wf", "REJECT", "ACCEPT", "failed", 2, "wrong\x00verdict"),
            runner.Result("xpact", "timeout", "d.xml", "not-wf", "REJECT", "timeout", "error", 30, "timeout\x01"),
            runner.Result("xpact", "skip", "e.xml", "error", "unspecified", "not-run", "skipped", message="optional"),
            runner.Result("expat", "accept", "a.xml", "valid", "ACCEPT", "ACCEPT", "passed", 1),
        ]
        runner.write_reports(rows, self.output, {"catalog_cases": 5})
        report = json.loads((self.output / "summary.json").read_text(encoding="utf-8"))
        self.assertEqual(report["engines"][0], {"engine": "xpact", "total": 5, "passed": 2, "failed": 1,
                         "errors": 1, "skipped": 1, "accepted": 2, "rejected": 1, "known": 0,
                         "unexpected": 2, "elapsed_ms": 48})
        suites = ET.parse(self.output / "junit.xml").getroot().findall("testsuite")
        self.assertEqual(len(suites), 2)
        self.assertEqual({key: suites[0].get(key) for key in ("tests", "failures", "errors", "skipped")},
                         {"tests": "5", "failures": "1", "errors": "1", "skipped": "1"})
        self.assertEqual(len(suites[0].findall("testcase/failure")), 1)
        self.assertEqual(len(suites[0].findall("testcase/error")), 1)
        self.assertEqual(len(suites[0].findall("testcase/skipped")), 1)
        self.assertEqual(suites[0].find("testcase/failure").text, "wrong?verdict")
        with (self.output / "results.tsv").open(encoding="utf-8", newline="") as source:
            tsv_rows = list(csv.DictReader(source, delimiter="\t"))
        self.assertEqual(len(tsv_rows), 6)
        self.assertEqual(tsv_rows[2]["message"], "wrong?verdict")

    def test_cli_runs_each_engine_and_fails_on_conformance_mismatch(self):
        self.catalog('<TEST ID="valid" TYPE="valid" URI="a.xml"/>')
        self.write("a.xml", "<r/>")
        executable = self.root / "parser.exe"
        executable.touch()
        arguments = ["--suite-dir", str(self.suite), "--output-dir", str(self.output),
                     "--engine", f"xpact={executable}", "--engine", f"expat={executable}"]
        verdicts = [subprocess.CompletedProcess([], 0, b"XPACT_CONFORMANCE\tACCEPT\n", b""),
                    subprocess.CompletedProcess([], 1, b"XPACT_CONFORMANCE\tREJECT\n", b"")]
        with mock.patch.object(runner.subprocess, "run", side_effect=verdicts) as process, contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(runner.main(arguments), 1)
        self.assertEqual(process.call_count, 2)
        report = json.loads((self.output / "summary.json").read_text())
        self.assertEqual([row["failed"] for row in report["engines"]], [0, 1])
        self.assertEqual(report["source_mode"], "local-directory")
        self.assertIsNone(report["archive_sha256"])

    def test_setup_failure_replaces_stale_junit_with_visible_error(self):
        self.output.mkdir()
        (self.output / "junit.xml").write_text("stale successful report")
        with contextlib.redirect_stdout(io.StringIO()):
            code = runner.main(["--suite-dir", str(self.suite), "--output-dir", str(self.output),
                                "--engine", f"xpact={self.root / 'missing.exe'}"])
        self.assertEqual(code, 1)
        suite = ET.parse(self.output / "junit.xml").getroot().find("testsuite")
        self.assertEqual(suite.get("errors"), "1")
        self.assertEqual(suite.find("testcase").get("name"), "suite-setup")


class KnownFailureTests(TemporarySuite):
    ACCEPT = subprocess.CompletedProcess([], 0, b"XPACT_CONFORMANCE\tACCEPT\n", b"")
    REJECT = subprocess.CompletedProcess([], 1, b"XPACT_CONFORMANCE\tREJECT\n", b"")
    CRASH = subprocess.CompletedProcess([], 1, b"Eiffel exception\n", b"")

    def setUp(self):
        super().setUp()
        self.catalog('<TEST ID="good" TYPE="valid" URI="a.xml"/><TEST ID="bad" TYPE="not-wf" URI="b.xml"/>')
        self.write("a.xml", "<r/>")
        self.write("b.xml", "<r>")
        self.executable = self.root / "parser.exe"
        self.executable.touch()
        self.known = self.root / "known.tsv"

    def run_cli(self, known_rows, verdicts, *extra):
        self.known.write_text("# comment line\nengine\tcase_id\tstatus\tcategory\n"
                              + "".join("\t".join(row) + "\n" for row in known_rows), encoding="utf-8")
        arguments = ["--suite-dir", str(self.suite), "--output-dir", str(self.output),
                     "--engine", f"xpact={self.executable}", "--known-failures", str(self.known), *extra]
        with mock.patch.object(runner.subprocess, "run", side_effect=verdicts), contextlib.redirect_stdout(io.StringIO()):
            code = runner.main(arguments)
        return code, json.loads((self.output / "summary.json").read_text(encoding="utf-8"))

    def test_listed_failure_is_reported_as_known_and_does_not_fail_the_run(self):
        code, report = self.run_cli([("xpact", "bad", "failed", "accepts input that must be rejected")],
                                    [self.ACCEPT, self.ACCEPT])
        self.assertEqual(code, 0)
        self.assertEqual({key: report["engines"][0][key] for key in ("passed", "failed", "known", "unexpected")},
                         {"passed": 1, "failed": 1, "known": 1, "unexpected": 0})
        self.assertEqual(report["known_failures_listed"], 1)
        failure = ET.parse(self.output / "junit.xml").getroot().find("testsuite/testcase/failure")
        self.assertTrue(failure.get("message").startswith("[known: accepts input that must be rejected]"))

    def test_unlisted_failure_still_fails_the_run(self):
        code, report = self.run_cli([("xpact", "bad", "failed", "accepts input that must be rejected")],
                                    [self.REJECT, self.ACCEPT])
        self.assertEqual(code, 1)
        self.assertEqual((report["engines"][0]["known"], report["engines"][0]["unexpected"]), (1, 1))

    def test_listed_case_that_passes_or_changes_status_fails_the_run(self):
        listed = [("xpact", "bad", "failed", "accepts input that must be rejected")]
        for verdict, now in ((self.REJECT, "passed"), (self.CRASH, "error")):
            with self.subTest(now=now):
                code, report = self.run_cli(listed, [self.ACCEPT, verdict])
                self.assertEqual(code, 1)
                stale = [row for row in report["engines"] if row["engine"] == "harness"]
                self.assertEqual(stale[0]["errors"], 1)
                with (self.output / "results.tsv").open(encoding="utf-8", newline="") as source:
                    harness = [row for row in csv.DictReader(source, delimiter="\t") if row["engine"] == "harness"]
                self.assertEqual(harness[0]["case_id"], "known-failures:xpact:bad")
                self.assertIn(f"but is now {now}", harness[0]["message"])

    def test_entries_for_engines_not_run_are_ignored(self):
        code, _ = self.run_cli([("other", "bad", "failed", "accepts input that must be rejected")],
                               [self.ACCEPT, self.REJECT])
        self.assertEqual(code, 0)

    def test_invalid_list_is_a_setup_error(self):
        for rows in ([("xpact", "bad", "passed", "x")],
                     [("xpact", "bad", "failed", "x"), ("xpact", "bad", "error", "y")],
                     [("xpact", "bad", "failed", "")]):
            with self.subTest(rows=rows):
                code, report = self.run_cli(rows, [self.ACCEPT, self.ACCEPT])
                self.assertEqual(code, 1)
                self.assertEqual(report["engines"][0]["engine"], "harness")

    def test_written_list_round_trips_into_a_passing_run(self):
        written = self.root / "written.tsv"
        code, _ = self.run_cli([], [self.ACCEPT, self.CRASH], "--write-known-failures", str(written))
        self.assertEqual(code, 1)
        self.assertEqual(written.read_text(encoding="utf-8"),
                         "engine\tcase_id\tstatus\tcategory\n"
                         "xpact\tbad\terror\tprocess error (crash or contract violation)\n")
        self.assertEqual(len(runner.load_known_failures(written)), 1)


class ArchiveTests(TemporarySuite):
    def test_hash_mismatch_rejects_changed_archive(self):
        archive = self.root / "archive.zip"
        archive.write_bytes(b"not the pinned W3C release")
        with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
            runner.verify_archive(archive)
        with mock.patch.object(runner, "SUITE_SHA256", hashlib.sha256(archive.read_bytes()).hexdigest()):
            runner.verify_archive(archive)

    def test_archive_members_are_checked_before_any_extraction(self):
        for index, member in enumerate(("../outside.xml", "/outside.xml", "..\\outside.xml", "C:/outside.xml")):
            with self.subTest(member=member):
                archive = self.root / "archive.zip"
                with zipfile.ZipFile(archive, "w") as bundle:
                    bundle.writestr("xmlconf/safe.xml", "<r/>")
                    # Assign after construction: Windows ZipInfo normalizes a
                    # backslash before writing, unlike an untrusted ZIP file.
                    unsafe = zipfile.ZipInfo("placeholder")
                    unsafe.filename = member
                    bundle.writestr(unsafe, "<r/>")
                destination = self.root / f"extracted-{index}"
                with self.assertRaises(ValueError):
                    runner.extract_archive(archive, destination)
                self.assertFalse((destination / "xmlconf/safe.xml").exists())

    def test_symlinks_are_rejected_and_safe_file_bytes_are_preserved(self):
        archive = self.root / "archive.zip"
        link = zipfile.ZipInfo("xmlconf/link.xml")
        link.create_system = 3
        link.external_attr = 0o120777 << 16
        with zipfile.ZipFile(archive, "w") as bundle:
            bundle.writestr(link, "../../outside.xml")
        with self.assertRaisesRegex(ValueError, "symbolic link"):
            runner.extract_archive(archive, self.root / "extracted")
        payload = b"\xff\xfe<\x00r\x00/\x00>\x00"
        with zipfile.ZipFile(archive, "w") as bundle:
            bundle.writestr("xmlconf/raw.xml", payload)
        runner.extract_archive(archive, self.root / "extracted")
        self.assertEqual((self.root / "extracted/xmlconf/raw.xml").read_bytes(), payload)


if __name__ == "__main__":
    unittest.main()
