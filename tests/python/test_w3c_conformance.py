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
    FORWARD_VERSION_DOCUMENT = (b'<!DOCTYPE foo [\n<!ELEMENT foo ANY>\n'
                                b'<!ENTITY e SYSTEM "E38.ent">\n]>\n<foo>&e;</foo>\n')
    FORWARD_VERSION_ENTITY = b'<?xml version="1.1" encoding="utf-8"?>\n<foo/>\n'

    def test_reviewed_forward_version_case_uses_fifth_edition_and_retains_catalog_verdict(self):
        document = self.write("eduni/errata-2e/E38.xml", self.FORWARD_VERSION_DOCUMENT)
        entity = self.write("eduni/errata-2e/E38.ent", self.FORWARD_VERSION_ENTITY)
        self.catalog('<TEST ID="rmt-e2e-38" TYPE="not-wf" RECOMMENDATION="XML1.0-errata2e" '
                     'ENTITIES="general" URI="eduni/errata-2e/E38.xml"/>')

        case, = runner.load_catalog(self.suite)

        self.assertEqual((case.expected, case.catalog_expected, case.skip_reason), ("ACCEPT", "REJECT", ""))
        self.assertIn("erratum E10", case.expectation_adjustment)
        self.assertEqual(document.read_bytes(), self.FORWARD_VERSION_DOCUMENT)
        self.assertEqual(entity.read_bytes(), self.FORWARD_VERSION_ENTITY)

    def test_forward_version_correction_requires_reviewed_metadata_and_both_input_hashes(self):
        for changes in ({"ID": "other-case"}, {"URI": "other/E38.xml"}, {"TYPE": "valid"},
                        {"RECOMMENDATION": "XML1.0"}, {"ENTITIES": "both"}, {"NAMESPACE": "no"},
                        {"VERSION": "1.1"}, {"EDITION": "1 2 3 4"},
                        {"document": self.FORWARD_VERSION_DOCUMENT + b"\n"},
                        {"entity": self.FORWARD_VERSION_ENTITY + b"\n"}, {"entity": None}):
            with self.subTest(changes=changes):
                attributes = {"ID": "rmt-e2e-38", "TYPE": "not-wf", "RECOMMENDATION": "XML1.0-errata2e",
                              "ENTITIES": "general", "URI": "eduni/errata-2e/E38.xml", **changes}
                document = attributes.pop("document", self.FORWARD_VERSION_DOCUMENT)
                entity = attributes.pop("entity", self.FORWARD_VERSION_ENTITY)
                self.write(attributes["URI"], document)
                entity_path = self.suite / "eduni/errata-2e/E38.ent"
                if entity is None:
                    entity_path.unlink(missing_ok=True)
                else:
                    self.write("eduni/errata-2e/E38.ent", entity)
                self.catalog("<TEST " + " ".join(f'{key}="{value}"' for key, value in attributes.items()) + "/>")

                case, = runner.load_catalog(self.suite)

                expected = "ACCEPT" if attributes["TYPE"] == "valid" else "REJECT"
                self.assertEqual((case.expected, case.catalog_expected), (expected, expected))
                self.assertEqual(case.expectation_adjustment, "")

    def test_malformed_entity_inputs_are_selected_without_case_id_or_byte_exceptions(self):
        original = b"<!DOCTYPE r SYSTEM 'malformed.dtd'><r/>"
        path = self.write("input.xml", original)
        self.catalog('<TEST ID="not-wf-not-sa-002" TYPE="not-wf" ENTITIES="both" URI="input.xml"/>'
                     '<TEST ID="other-malformed" TYPE="not-wf" ENTITIES="parameter" URI="input.xml"/>')

        cases = runner.load_catalog(self.suite)

        self.assertEqual([(case.expected, case.skip_reason) for case in cases], [("REJECT", "")] * 2)
        self.assertEqual(path.read_bytes(), original)

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
            {"TYPE": "error"},
        ):
            with self.subTest(attributes=attributes):
                _, reason = runner.expectation({"TYPE": "not-wf", **attributes})
                self.assertTrue(reason)
        self.assertEqual(runner.expectation({"TYPE": "error"})[0], "unspecified")

    def test_entity_metadata_preserves_all_binary_expectations(self):
        for kind, expected in (("valid", "ACCEPT"), ("invalid", "ACCEPT"), ("not-wf", "REJECT")):
            for entities in ("none", "general", "parameter", "both"):
                with self.subTest(kind=kind, entities=entities):
                    self.assertEqual(runner.expectation({"TYPE": kind, "ENTITIES": entities}),
                                     (expected, ""))

    def test_entity_acceptance_does_not_override_version_edition_or_optional_exclusions(self):
        for attributes in ({"VERSION": "1.1"}, {"EDITION": "1 2 3 4"},
                           {"RECOMMENDATION": "XML1.1"}, {"RECOMMENDATION": "NS1.1"},
                           {"TYPE": "error"}):
            with self.subTest(attributes=attributes):
                _, reason = runner.expectation({"TYPE": "valid", "ENTITIES": "both", **attributes})
                self.assertTrue(reason)

    def test_lists_containing_supported_version_and_edition_remain_applicable(self):
        self.assertEqual(runner.expectation({"TYPE": "valid", "VERSION": "1.0 1.1", "EDITION": "4 5"}),
                         ("ACCEPT", ""))
        self.assertEqual(runner.expectation({"TYPE": "not-wf", "RECOMMENDATION": "NS1.0"}),
                         ("REJECT", ""))

    def test_out_of_profile_lanes_and_their_expectations(self):
        for attributes, lane in (
            ({"TYPE": "valid", "RECOMMENDATION": "XML1.1"}, ("xml-1.1", "ANY")),
            ({"TYPE": "not-wf", "VERSION": "1.1"}, ("xml-1.1", "ANY")),
            ({"TYPE": "error"}, ("optional-error", "ANY")),
            ({"TYPE": "error", "EDITION": "1 2 3 4"}, ("optional-error", "ANY")),
            ({"TYPE": "not-wf", "EDITION": "1 2 3 4"}, ("legacy-names", "REJECT")),
            ({"TYPE": "invalid", "ENTITIES": "parameter"}, ("external-entities", "ACCEPT")),
            ({"TYPE": "not-wf", "ENTITIES": "both"}, ("external-entities", "REJECT")),
        ):
            with self.subTest(attributes=attributes):
                self.assertEqual(runner.out_of_profile_lane(attributes), lane)

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

    def test_suite_root_is_canonical_and_keeps_original_input_bytes(self):
        case = self.case()
        original = case.path.read_bytes()
        completed = subprocess.CompletedProcess([], 0, b"XPACT_CONFORMANCE\tACCEPT\n", b"")
        with mock.patch.object(runner.subprocess, "run", return_value=completed) as process:
            result = runner.run_case(case, "xpact", Path("parser.exe"), 0.25, self.root,
                                     suite_root=self.suite / "subdir" / "..")
        self.assertEqual(result.status, "passed")
        self.assertEqual(process.call_args.args[0], ["parser.exe", "--conformance-file", str(case.path),
                         "--suite-root", str(self.suite.resolve()), "--namespaces"])
        self.assertEqual(case.path.read_bytes(), original)

    def test_invalid_suite_root_does_not_launch_parser_or_count_as_rejection(self):
        case = self.case(expected="REJECT")
        outside = self.root / "other suite"
        outside.mkdir()
        for suite_root in (outside, self.root / "missing suite"):
            with self.subTest(suite_root=suite_root), mock.patch.object(runner.subprocess, "run") as process:
                result = runner.run_case(case, "xpact", Path("parser.exe"), 0.25, self.root,
                                         suite_root=suite_root)
            process.assert_not_called()
            self.assertEqual((result.status, result.actual), ("error", "not-run"))

    def test_profile_adjustment_is_visible_even_when_the_case_passes(self):
        case = replace(self.case(), kind="not-wf", catalog_expected="REJECT",
                       expectation_adjustment="XML edition correction: required ACCEPT")
        result, _ = self.invoke(case, subprocess.CompletedProcess([], 0, b"XPACT_CONFORMANCE\tACCEPT\n", b""))
        self.assertEqual((result.status, result.expected, result.catalog_expected), ("passed", "ACCEPT", "REJECT"))

        report = runner.write_reports([result], self.output, {})

        self.assertEqual(report["expectation_adjustments"], [{"case_id": case.id, "catalog_expected": "REJECT",
                         "expected": "ACCEPT", "reason": case.expectation_adjustment}])
        properties = ET.parse(self.output / "junit.xml").getroot().findall("testsuite/testcase/properties/property")
        self.assertEqual({p.get("name"): p.get("value") for p in properties},
                         {"catalog_expected": "REJECT", "profile_expected": "ACCEPT",
                          "expectation_adjustment": case.expectation_adjustment})
        with (self.output / "results.tsv").open(encoding="utf-8", newline="") as source:
            row, = csv.DictReader(source, delimiter="\t")
        self.assertEqual((row["expected"], row["catalog_expected"], row["expectation_adjustment"]),
                         ("ACCEPT", "REJECT", case.expectation_adjustment))

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

    def test_either_verdict_expectation_passes_a_verdict_but_not_a_crash(self):
        case = replace(self.case(), expected="ANY")
        for code, stdout, status in ((0, b"XPACT_CONFORMANCE\tACCEPT\n", "passed"),
                                     (1, b"XPACT_CONFORMANCE\tREJECT\n", "passed"),
                                     (-1073741571, b"", "error")):
            with self.subTest(code=code):
                result, _ = self.invoke(case, subprocess.CompletedProcess([], code, stdout, b""))
                self.assertEqual(result.status, status)

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
        self.assertEqual(report["engines"][0], {"engine": "xpact", "total": 5, "passed": 2, "no_crash_only": 0, "failed": 1,
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

    def test_either_verdict_passes_are_reported_apart_from_checked_verdicts(self):
        rows = [
            runner.Result("xpact", "checked", "a.xml", "valid", "ACCEPT", "ACCEPT", "passed", 1),
            runner.Result("xpact", "any", "b.xml", "error", "ANY", "REJECT", "passed", 1, lane="optional-error"),
            runner.Result("xpact", "crash", "c.xml", "valid", "ANY", "process-error", "error", 1, lane="xml-1.1"),
        ]
        runner.write_reports(rows, self.output, {})
        report = json.loads((self.output / "summary.json").read_text(encoding="utf-8"))
        self.assertEqual((report["engines"][0]["passed"], report["engines"][0]["no_crash_only"],
                          report["engines"][0]["errors"]), (1, 1, 1))
        suites = {suite.get("name"): suite for suite in ET.parse(self.output / "junit.xml").getroot().findall("testsuite")}
        self.assertEqual(set(suites), {"w3c-xml-xpact", "w3c-xml-xpact-no-crash-only"})
        self.assertEqual(suites["w3c-xml-xpact"].get("tests"), "1")
        self.assertEqual({key: suites["w3c-xml-xpact-no-crash-only"].get(key) for key in ("tests", "errors")},
                         {"tests": "2", "errors": "1"})
        self.assertEqual(suites["w3c-xml-xpact-no-crash-only"].find("testcase").get("classname"),
                         "w3c.xml.xpact.optional-error")
        summary = (self.output / "summary.md").read_text(encoding="utf-8")
        self.assertIn("No crash only", summary)
        self.assertIn("| xpact | optional-error | no crash only |", summary)

    def test_all_cases_runs_out_of_profile_cases_in_their_lanes(self):
        self.catalog('<TEST ID="core" TYPE="valid" URI="a.xml"/>'
                     '<TEST ID="old" TYPE="not-wf" EDITION="1 2 3 4" URI="a.xml"/>'
                     '<TEST ID="ext" TYPE="error" ENTITIES="general" URI="a.xml"/>'
                     '<TEST ID="opt" TYPE="error" URI="a.xml"/>'
                     '<TEST ID="coreext" TYPE="valid" ENTITIES="general" URI="a.xml"/>')
        self.write("a.xml", "<r/>")
        engine = self.root / "parser.exe"
        checker = self.root / "checker.exe"
        engine.touch()
        checker.touch()
        arguments = ["--suite-dir", str(self.suite), "--output-dir", str(self.output), "--all-cases",
                     "--engine", f"xpact={engine}", "--entity-engine", f"xpact={checker}"]
        verdicts = [subprocess.CompletedProcess([], 0, b"XPACT_CONFORMANCE\tACCEPT\n", b""),
                    subprocess.CompletedProcess([], 1, b"XPACT_CONFORMANCE\tREJECT\n", b""),
                    subprocess.CompletedProcess([], 0, b"XPACT_CONFORMANCE\tACCEPT\n", b""),
                    subprocess.CompletedProcess([], 0, b"XPACT_CONFORMANCE\tACCEPT\n", b""),
                    subprocess.CompletedProcess([], 0, b"XPACT_CONFORMANCE\tACCEPT\n", b"")]
        with mock.patch.object(runner.subprocess, "run", side_effect=verdicts) as process, contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(runner.main(arguments), 0)
        commands = [call.args[0] for call in process.call_args_list]
        # In-profile entity cases run in the core lane with the suite root (#150); only
        # out-of-profile entity cases go to the DLL checker.
        self.assertEqual([Path(command[0]).name for command in commands],
                         ["parser.exe", "parser.exe", "checker.exe", "parser.exe", "parser.exe"])
        self.assertIn("--legacy-names", commands[1])
        self.assertEqual(commands[2][-2:], ["--entity-root", str(self.suite.resolve())])
        self.assertIn("--suite-root", commands[4])
        report = json.loads((self.output / "summary.json").read_text())
        self.assertEqual({key: report["engines"][0][key] for key in ("passed", "no_crash_only", "skipped")},
                         {"passed": 3, "no_crash_only": 2, "skipped": 0})

    def test_all_cases_requires_an_entity_engine_for_every_engine(self):
        self.catalog('<TEST ID="core" TYPE="valid" URI="a.xml"/>')
        self.write("a.xml", "<r/>")
        engine = self.root / "parser.exe"
        engine.touch()
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(runner.main(["--suite-dir", str(self.suite), "--output-dir", str(self.output),
                                          "--all-cases", "--engine", f"xpact={engine}"]), 1)
        report = json.loads((self.output / "summary.json").read_text())
        self.assertEqual(report["engines"][0]["engine"], "harness")

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
        for call in process.call_args_list:
            self.assertEqual(call.args[0][3:5], ["--suite-root", str(self.suite.resolve())])
        report = json.loads((self.output / "summary.json").read_text())
        self.assertEqual([row["failed"] for row in report["engines"]], [0, 1])
        self.assertEqual(report["source_mode"], "local-directory")
        self.assertIsNone(report["archive_sha256"])

    def test_parallel_jobs_report_the_same_results_in_catalog_order(self):
        self.catalog("".join(f'<TEST ID="c{i}" TYPE="{"valid" if i % 2 else "not-wf"}" URI="c{i}.xml"/>'
                             for i in range(12)))
        for i in range(12):
            self.write(f"c{i}.xml", "<r/>" if i % 3 else "<r>")
        executable = self.root / "parser.exe"
        executable.touch()

        def verdict(command, **_):
            # The verdict depends on the input only, as with a real parser.
            if Path(command[2]).read_text() == "<r/>":
                return subprocess.CompletedProcess(command, 0, b"XPACT_CONFORMANCE\tACCEPT\n", b"")
            return subprocess.CompletedProcess(command, 1, b"XPACT_CONFORMANCE\tREJECT\n", b"")

        rows = {}
        for jobs in ("1", "4"):
            output = self.root / f"reports-{jobs}"
            with mock.patch.object(runner.subprocess, "run", side_effect=verdict), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(runner.main(["--suite-dir", str(self.suite), "--output-dir", str(output),
                                              "--engine", f"xpact={executable}", "--jobs", jobs]), 1)
            with open(output / "results.tsv", encoding="utf-8") as source:
                rows[jobs] = [{key: value for key, value in row.items() if key != "elapsed_ms"}
                              for row in csv.DictReader(source, delimiter="\t")]
        self.assertEqual([row["case_id"] for row in rows["4"]], [f"c{i}" for i in range(12)])
        self.assertEqual(rows["4"], rows["1"])

    def test_jobs_must_be_positive(self):
        with self.assertRaises(SystemExit), contextlib.redirect_stderr(io.StringIO()):
            runner.main(["--suite-dir", str(self.suite), "--engine", "xpact=x", "--jobs", "0"])

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
