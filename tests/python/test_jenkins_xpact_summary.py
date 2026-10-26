"""Keep reference-parser observations out of Jenkins' subject test summary."""

import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock
import xml.etree.ElementTree as ET


REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts"))
import jenkins_xpact_summary as summary


class OwnSummaryTests(unittest.TestCase):
    def setUp(self):
        scratch = REPO / "build/xpact-subject-summary-tests"
        scratch.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=scratch)
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.reports, self.states = {}, {}
        for lane in ("catalog", "w3c"):
            directory = self.root / lane
            directory.mkdir()
            rows = []
            for assertions in (True, False):
                for engine in ("xpact", "xpact-core"):
                    cases = [{"case_id": name, "status": "PASS" if engine == "xpact" else "FAIL",
                              "detail": "observed control"} for name in sorted(summary.CONTROLS[lane])]
                    row = {"implementation": engine, "assertions": assertions,
                           "status": "qualified" if lane == "catalog" else "executed", "cases": cases}
                    if engine == "xpact":
                        executable = directory / ("own-{}.exe".format(assertions))
                        executable.write_bytes((lane + str(assertions)).encode())
                        artifact = {"status": "verified", "implementation": "xpact", "profile": lane,
                                    "build": {"mode": "finalized", "assertions": assertions,
                                              "configuration": "finalized/assertions-{}/msvc-x64".format("on" if assertions else "off")},
                                    "source": {"revision": "a" * 40, "source_sha256": "b" * 64},
                                    "build_inputs_sha256": "c" * 64, "executable": str(executable),
                                    "executable_sha256": hashlib.sha256(executable.read_bytes()).hexdigest()}
                        manifest = executable.with_suffix(".json")
                        manifest.write_text(json.dumps(artifact))
                        row["manifest"] = str(manifest)
                    rows.append(row)
            status = "complete" if lane == "catalog" else "complete_with_failures"
            self.reports[lane] = {"status": status, "qualification": rows}
            self.states[lane] = {"status": status}
            (directory / "run.json").write_text(json.dumps({"status": status, "builds": rows}))
        self.reports["w3c"].update(source={"catalog_cases": 3}, engines=[
            {"engine": "xpact", "total": 3, "passed": 2, "failed": 0, "errors": 0, "skipped": 1},
            {"engine": "xpact-core", "total": 3, "passed": 0, "failed": 1, "errors": 1, "skipped": 1}])
        directory = self.root / "w3c/conformance"
        directory.mkdir()
        document = ET.Element("testsuites")
        for engine in ("xpact", "xpact-core"):
            suite = ET.SubElement(document, "testsuite", name="w3c-xml-" + engine, tests="3",
                                  failures="0" if engine == "xpact" else "1",
                                  errors="0" if engine == "xpact" else "1", skipped="1", time="0.3")
            for index in range(3):
                test = ET.SubElement(suite, "testcase", classname="w3c.xml." + engine,
                                     name="case-" + str(index), time="0.1")
                if index == 2:
                    ET.SubElement(test, "skipped", message="Excluded profile")
                elif engine == "xpact-core":
                    ET.SubElement(test, "failure" if index == 0 else "error", message="reference result")
        ET.ElementTree(document).write(directory / "junit.xml")
        self.raw_path = directory / "junit.xml"
        self.raw_bytes = self.raw_path.read_bytes()

    def publish(self, **kwargs):
        return summary.publish_summary(self.root, self.reports, self.states, **kwargs)

    def own_row(self, lane, assertions):
        return next(row for row in self.reports[lane]["qualification"]
                    if row["implementation"] == "xpact" and row["assertions"] is assertions)

    def test_reference_failures_are_omitted_from_summary_but_raw_evidence_remains(self):
        result = self.publish()
        self.assertEqual(result["status"], "complete")
        self.assertEqual({key: result[key] for key in ("tests", "passed", "failures", "errors", "skipped")},
                         {"tests": 23, "passed": 22, "failures": 0, "errors": 0, "skipped": 1})
        document = ET.parse(self.root / summary.JUNIT_FILE).getroot()
        self.assertEqual(len(document.findall(".//testcase")), 23)
        self.assertFalse(any("xpact-core" in test.get("classname", "") for test in document.findall(".//testcase")))
        self.assertEqual(self.raw_path.read_bytes(), self.raw_bytes)
        self.assertEqual(json.loads((self.root / summary.SUMMARY_FILE).read_text()), result)

    def test_own_case_and_directed_control_failures_remain_gating(self):
        document = ET.parse(self.raw_path)
        suite = document.getroot()[0]
        suite.set("failures", "1")
        ET.SubElement(suite.find("testcase"), "failure", message="our own incorrect verdict")
        document.write(self.raw_path)
        self.reports["w3c"]["engines"][0].update(passed=1, failed=1)
        self.own_row("w3c", True)["cases"][0]["status"] = "FAIL"
        result = self.publish()
        self.assertEqual(result["status"], "complete_with_failures")
        self.assertEqual(result["failures"], 2)
        self.assertIn("our own incorrect verdict", (self.root / summary.JUNIT_FILE).read_text())

    def test_own_control_process_error_still_fails_while_reference_errors_do_not(self):
        row = self.own_row("w3c", True)
        row.update(cases=[], qualification_error="own qualifier exceeded timeout")
        result = self.publish()
        self.assertEqual(result["status"], "complete_with_failures")
        self.assertEqual(result["errors"], 1)
        self.assertIn("own qualifier exceeded timeout", (self.root / summary.JUNIT_FILE).read_text())

    def test_missing_or_duplicated_own_controls_cannot_make_green_summary(self):
        original = copy.deepcopy(self.reports["catalog"]["qualification"])
        for change in (lambda rows: rows.pop(0), lambda rows: rows.append(copy.deepcopy(rows[0])),
                       lambda rows: rows[0]["cases"].pop()):
            with self.subTest(change=change):
                rows = copy.deepcopy(original)
                change(rows)
                self.reports["catalog"]["qualification"] = rows
                result = self.publish()
                self.assertEqual(result["status"], "failed")
                self.assertGreater(result["errors"], 0)

    def test_core_only_catalog_gate_keeps_authenticated_own_controls_green(self):
        rows = self.reports["catalog"]["qualification"]
        next(row for row in rows if row["implementation"] == "xpact-core")["status"] = "failed"
        (self.root / "catalog/run.json").write_text(json.dumps({
            "status": "failed", "error": summary.CATALOG_CORE_GATE, "builds": rows}))
        del self.reports["catalog"]
        self.states["catalog"]["status"] = "failed"
        self.assertEqual(self.publish()["status"], "complete")

    def test_postqualification_or_unknown_failure_is_not_assumed_core_only(self):
        rows = self.reports["catalog"]["qualification"]
        next(row for row in rows if row["implementation"] == "xpact-core")["status"] = "failed"
        del self.reports["catalog"]
        self.states["catalog"]["status"] = "failed"
        for fields in ({"error": "Catalog paired measurement failed"},
                       {"error": summary.CATALOG_CORE_GATE, "comparison_arguments": ["untrusted"]}):
            with self.subTest(fields=fields):
                (self.root / "catalog/run.json").write_text(json.dumps({"status": "failed", "builds": rows, **fields}))
                self.assertEqual(self.publish()["status"], "failed")

    def test_changed_binary_and_different_source_snapshots_are_subject_errors(self):
        row = self.own_row("catalog", True)
        path = Path(row["manifest"])
        original = path.read_text()
        for field in ("executable_sha256", "build_inputs_sha256"):
            with self.subTest(field=field):
                artifact = json.loads(original)
                artifact[field] = "d" * 64
                path.write_text(json.dumps(artifact))
                self.assertEqual(self.publish()["status"], "failed")
        path.write_text(original)
        with mock.patch.object(summary.builds, "source_fingerprint", return_value="d" * 64):
            self.assertEqual(self.publish(repo_root=REPO)["status"], "failed")

    def test_w3c_missing_duplicate_or_foreign_own_cases_are_infrastructure_errors(self):
        for mode in ("missing", "duplicate-suite", "foreign-case", "nested-foreign-suite", "wrong-count"):
            with self.subTest(mode=mode):
                self.raw_path.write_bytes(self.raw_bytes)
                document = ET.parse(self.raw_path)
                root = document.getroot()
                if mode == "missing":
                    root.remove(root[0])
                elif mode == "duplicate-suite":
                    root.append(copy.deepcopy(root[0]))
                elif mode == "foreign-case":
                    root[0].find("testcase").set("classname", "w3c.xml.xpact-core")
                elif mode == "nested-foreign-suite":
                    root[0].append(copy.deepcopy(root[1]))
                else:
                    root[0].set("tests", "7")
                document.write(self.raw_path)
                result = self.publish()
                self.assertEqual(result["status"], "failed")
                own = ET.parse(self.root / summary.JUNIT_FILE).getroot()
                self.assertFalse(any("xpact-core" in test.get("classname", "") for test in own.findall(".//testcase")))

    def test_incomplete_w3c_lane_cannot_count_only_controls_as_full_success(self):
        del self.reports["w3c"]
        self.states["w3c"]["status"] = "failed"
        result = self.publish()
        self.assertEqual(result["status"], "failed")
        self.assertGreaterEqual(result["errors"], 1)

    def test_publication_failure_cleans_own_files_preserves_raw_and_fresh_retry(self):
        original = summary._replace_text
        def fail_json(path, text):
            if path.name == summary.SUMMARY_FILE:
                raise OSError("owned summary storage unavailable")
            return original(path, text)
        with mock.patch.object(summary, "_replace_text", side_effect=fail_json):
            with self.assertRaisesRegex(OSError, "storage unavailable"):
                self.publish()
        self.assertFalse((self.root / summary.JUNIT_FILE).exists())
        self.assertFalse((self.root / summary.SUMMARY_FILE).exists())
        self.assertFalse(list(self.root.glob(".xpact-summary-*.tmp")))
        self.assertEqual(self.raw_path.read_bytes(), self.raw_bytes)
        self.assertEqual(self.publish()["status"], "complete")

    def test_standalone_w3c_cli_uses_subject_exit_status_without_rewriting_raw(self):
        directory = self.root / "w3c"
        (directory / "report.json").write_text(json.dumps(self.reports["w3c"]))
        self.assertEqual(summary.main(["--output-dir", str(directory), "--lane", "w3c"]), 0)
        result = json.loads((directory / summary.SUMMARY_FILE).read_text())
        self.assertEqual(result["tests"], 13)
        self.assertEqual(self.raw_path.read_bytes(), self.raw_bytes)

    def test_failed_standalone_reexport_cannot_publish_an_older_subject_summary(self):
        directory = self.root / "w3c"
        report_path = directory / "report.json"
        report_path.write_text(json.dumps(self.reports["w3c"]))
        arguments = ["--output-dir", str(directory), "--lane", "w3c"]
        self.assertEqual(summary.main(arguments), 0)
        broken = copy.deepcopy(self.reports["w3c"])
        broken["qualification"] = [1]
        report_path.write_text(json.dumps(broken))
        self.assertEqual(summary.main(arguments), 2)
        self.assertFalse((directory / summary.JUNIT_FILE).exists())
        self.assertFalse((directory / summary.SUMMARY_FILE).exists())
        self.assertEqual(self.raw_path.read_bytes(), self.raw_bytes)
        report_path.write_text(json.dumps(self.reports["w3c"]))
        self.assertEqual(summary.main(arguments), 0)


if __name__ == "__main__":
    unittest.main()
