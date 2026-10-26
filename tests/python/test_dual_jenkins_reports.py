"""Check plot meaning, scoped data integrity and failed-publication recovery."""

import copy
import csv
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock


REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts"))
import dual_jenkins_reports as reports


def artifact(engine, profile):
    return {"status": "verified", "profile": profile, "implementation": engine,
            "gc_policy": reports.GC_POLICIES[engine],
            "build": {"configuration": "finalized/assertions-off/msvc-x64", "mode": "finalized", "assertions": False},
            "source": {"revision": "a" * 40}, "executable_sha256": "b" * 64,
            "build_inputs_sha256": "c" * 64}


def controls(profile):
    names = reports.CATALOG_CONTROLS if profile == "catalog" else reports.W3C_CONTROLS
    return [{"implementation": engine, "assertions": assertions,
             "status": "qualified" if profile == "catalog" else "executed",
             "cases": [{"case_id": name, "status": "PASS"} for name in sorted(names)]}
            for engine in reports.ENGINES for assertions in (True, False)]


def catalog_report(iterations=2000):
    rows = []
    for pair, elapsed in enumerate((2000.0, 4000.0), 1):
        row = {"Workload": "catalog", "Pair": pair, "Order": "AB" if pair % 2 else "BA",
               "Iterations": iterations, "DocumentBytes": 1000}
        for prefix, elapsed_ms in (("Baseline", elapsed), ("Candidate", elapsed / 2)):
            row[prefix + "ElapsedMs"] = elapsed_ms
            row[prefix + "MiBPerSecond"] = iterations * 1000 / (1024 * 1024) / (elapsed_ms / 1000)
        rows.append(row)
    return {"status": "complete", "lane": "catalog-finalized-assertions-off", "input": {"bytes": 1000},
            "artifacts": {engine: artifact(engine, "catalog") for engine in reports.ENGINES},
            "qualification": controls("catalog"),
            "comparison": {"results": rows, "metadata": {"pairs": 2}}}


def w3c_report(*, green=False):
    engines = [{"engine": "xpact", "total": 10, "passed": 7, "failed": 1, "errors": 1, "skipped": 1},
               {"engine": "xpact-core", "total": 10, "passed": 6, "failed": 2, "errors": 1, "skipped": 1}]
    if green:
        for engine in engines:
            engine.update(passed=9, failed=0, errors=0)
    return {"status": "complete" if green else "complete_with_failures", "lane": "w3c-finalized-assertions-off",
            "artifacts": {engine: artifact(engine, "w3c") for engine in reports.ENGINES},
            "qualification": controls("w3c"), "source": {"catalog_cases": 10}, "engines": engines}


def state_for(lane_reports):
    lanes = {lane: {"status": report["status"], "report": lane + "/report.json"}
             for lane, report in lane_reports.items()}
    for lane in ("catalog", "w3c"):
        lanes.setdefault(lane, {"status": "failed", "error": "Build failed <not XML>", "report": lane + "/report.json"})
    status = ("failed" if any(row["status"] == "failed" for row in lanes.values())
              else "complete_with_failures" if any(row["status"] == "complete_with_failures" for row in lanes.values())
              else "complete")
    return {"build_id": "jenkins-example-42", "status": status, "lanes": lanes}


class DualJenkinsReportTests(unittest.TestCase):
    def setUp(self):
        scratch = REPO / "build/dual-jenkins-report-tests"
        scratch.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="report-", dir=scratch)
        self.addCleanup(self.temporary.cleanup)
        self.output = Path(self.temporary.name)
        self.lanes = {"catalog": catalog_report(), "w3c": w3c_report()}

    def publish(self, lanes=None, state=None):
        lanes = self.lanes if lanes is None else lanes
        return reports.publish_reports(self.output, state or state_for(lanes), lanes)

    def csv_values(self, token):
        with (self.output / (token + ".csv")).open(encoding="utf-8", newline="") as stream:
            rows = list(csv.reader(stream))
        self.assertEqual(rows[0], list(reports.LABELS))
        self.assertEqual(len(rows), 2)
        return [float(value) for value in rows[1]]

    def manifest(self):
        with (self.output / reports.MANIFEST).open(encoding="utf-8", newline="") as stream:
            return list(csv.DictReader(stream, delimiter="\t"))

    def test_completed_red_w3c_and_qualified_catalog_publish_distinct_meaningful_plots(self):
        result = self.publish()
        self.assertEqual(result, {"manifest": "plots.tsv", "html": reports.HTML_REPORT, "plots": 6})
        self.assertEqual(self.csv_values("dual-catalog-ms-per-1000-documents"), [1500.0, 750.0])
        self.assertEqual(self.csv_values("dual-w3c-passed"), [7.0, 6.0])
        self.assertEqual(self.csv_values("dual-w3c-wrong-verdicts"), [1.0, 2.0])
        self.assertEqual(self.csv_values("dual-w3c-errors"), [1.0, 1.0])
        self.assertEqual(self.csv_values("dual-w3c-excluded"), [1.0, 1.0])
        self.assertEqual(len(self.manifest()), 6)
        for spec in self.manifest():
            self.assertTrue(spec["sourceFile"].startswith(self.output.relative_to(REPO).as_posix() + "/"))
            self.assertTrue((REPO / spec["sourceFile"]).is_file())
        page = (self.output / reports.HTML_REPORT).read_text(encoding="utf-8")
        self.assertIn("complete_with_failures", page)
        self.assertIn("No known-failure allowlist", page)
        self.assertIn("core-managed-off-full-collect", page)
        self.assertIn('href="w3c/report.json"', page)
        self.assertIn("are not compared here as parser throughput", page)
        self.assertNotIn("W3C median", page)

    def test_calibration_count_changes_do_not_create_a_false_elapsed_trend(self):
        self.publish()
        original_times = self.csv_values("dual-catalog-ms-per-1000-documents")
        original_rates = self.csv_values("dual-catalog-mib-per-second")
        for row in self.lanes["catalog"]["comparison"]["results"]:
            row["Iterations"] *= 2
            row["BaselineElapsedMs"] *= 2
            row["CandidateElapsedMs"] *= 2
        self.publish()
        self.assertEqual(self.csv_values("dual-catalog-ms-per-1000-documents"), original_times)
        self.assertEqual(self.csv_values("dual-catalog-mib-per-second"), original_rates)

    def test_catalog_infrastructure_failure_omits_its_values_while_red_w3c_still_publishes(self):
        lanes = {"w3c": self.lanes["w3c"]}
        self.assertEqual(self.publish(lanes)["plots"], 4)
        self.assertFalse((self.output / "dual-catalog-ms-per-1000-documents.csv").exists())
        self.assertEqual(self.csv_values("dual-w3c-errors"), [1.0, 1.0])
        page = (self.output / reports.HTML_REPORT).read_text()
        self.assertIn("Build failed &lt;not XML&gt;", page)
        self.assertNotIn('href="catalog/report.json"', page)

    def test_w3c_infrastructure_failure_keeps_catalog_plots_without_zero_w3c_values(self):
        lanes = {"catalog": self.lanes["catalog"]}
        self.assertEqual(self.publish(lanes)["plots"], 2)
        self.assertFalse((self.output / "dual-w3c-passed.csv").exists())
        self.assertEqual(self.csv_values("dual-catalog-ms-per-1000-documents"), [1500.0, 750.0])

    def test_both_infrastructure_failures_publish_diagnostics_and_an_empty_manifest(self):
        self.assertEqual(self.publish({})["plots"], 0)
        self.assertEqual(self.manifest(), [])
        self.assertEqual(list(self.output.glob("*.csv")), [])
        self.assertIn("failed", (self.output / reports.HTML_REPORT).read_text())

    def test_control_only_w3c_failure_remains_red_even_when_all_catalog_cases_pass(self):
        self.lanes["w3c"] = w3c_report(green=True)
        self.lanes["w3c"]["status"] = "complete_with_failures"
        self.lanes["w3c"]["qualification"][-1]["cases"][0]["status"] = "FAIL"
        self.publish()
        self.assertEqual(self.csv_values("dual-w3c-passed"), [9.0, 9.0])
        self.assertEqual(self.csv_values("dual-w3c-wrong-verdicts"), [0.0, 0.0])
        self.assertIn("complete_with_failures", (self.output / reports.HTML_REPORT).read_text())

    def test_control_process_error_is_visible_and_does_not_hide_w3c_catalog_counts(self):
        control = self.lanes["w3c"]["qualification"][-1]
        control.update(cases=[], qualification_error="Native control process crashed <status>")
        self.publish()
        self.assertEqual(self.csv_values("dual-w3c-wrong-verdicts"), [1.0, 2.0])
        self.assertIn("Native control process crashed &lt;status&gt;", (self.output / reports.HTML_REPORT).read_text())

    def test_false_green_bad_case_counts_and_different_exclusions_cannot_be_plotted(self):
        mutations = (
            lambda r: r.update(status="complete"),
            lambda r: r["engines"][0].update(passed=10),
            lambda r: r["engines"][1].update(skipped=2, passed=5),
            lambda r: r["engines"].append(copy.deepcopy(r["engines"][0])),
            lambda r: r["engines"][0].update(errors=-1, passed=9),
        )
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                lanes = copy.deepcopy(self.lanes)
                mutation(lanes["w3c"])
                with self.assertRaises(reports.ReportsError):
                    self.publish(lanes)
                self.assertFalse((self.output / reports.MANIFEST).exists())

    def test_unqualified_partial_or_invalid_catalog_samples_never_publish_speed(self):
        mutations = (
            lambda r: r["qualification"][0]["cases"][0].update(status="FAIL"),
            lambda r: r["comparison"]["results"].pop(),
            lambda r: r["comparison"]["results"][0].update(BaselineElapsedMs=float("nan")),
            lambda r: r["comparison"]["results"][0].update(CandidateMiBPerSecond=float("inf")),
            lambda r: r["comparison"]["results"][0].update(BaselineMiBPerSecond=9000),
            lambda r: r["comparison"]["results"][1].update(Order="AB"),
        )
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                lanes = copy.deepcopy(self.lanes)
                mutation(lanes["catalog"])
                with self.assertRaises(reports.ReportsError):
                    self.publish(lanes)
                self.assertFalse((self.output / reports.MANIFEST).exists())

    def test_wrong_build_configuration_missing_counterpart_or_missing_control_is_rejected(self):
        mutations = (
            lambda r: r["artifacts"]["xpact"]["build"].update(assertions=True),
            lambda r: r["artifacts"].pop("xpact-core"),
            lambda r: r["qualification"][0]["cases"].pop(),
            lambda r: r["qualification"].pop(),
            lambda r: r["artifacts"]["xpact"].update(executable_sha256="unknown"),
        )
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                lanes = copy.deepcopy(self.lanes)
                mutation(lanes["w3c"])
                with self.assertRaises(reports.ReportsError):
                    self.publish(lanes)

    def test_missing_completed_lane_or_failed_lane_values_do_not_reuse_old_plots(self):
        self.publish()
        with self.assertRaises(reports.ReportsError):
            self.publish({"catalog": self.lanes["catalog"]}, state_for(self.lanes))
        self.assertFalse((self.output / reports.MANIFEST).exists())
        state = state_for({"catalog": self.lanes["catalog"]})
        with self.assertRaises(reports.ReportsError):
            self.publish(self.lanes, state)
        self.assertEqual(list(self.output.glob("*.csv")), [])

    def test_publication_failure_releases_staging_preserves_child_evidence_and_retry_recovers(self):
        previous = self.output / "earlier-run"
        previous.mkdir()
        (previous / reports.MANIFEST).write_text("earlier evidence")
        work = self.output / "w3c/work/core"
        work.mkdir(parents=True)
        diagnostic = work / "stderr.bin"
        diagnostic.write_bytes(b"native exception evidence")
        self.publish()
        original_replace = Path.replace

        def fail_html(path, target):
            if Path(target).name == reports.HTML_REPORT:
                raise OSError("report persistence failed")
            return original_replace(path, target)

        with mock.patch.object(Path, "replace", fail_html):
            with self.assertRaisesRegex(OSError, "persistence failed"):
                self.publish()
        self.assertFalse(any((self.output / name).exists() for name in reports.REPORT_FILES))
        self.assertEqual(list(self.output.glob(".dual-plot-*.tmp")), [])
        self.assertEqual(diagnostic.read_bytes(), b"native exception evidence")
        self.assertEqual((previous / reports.MANIFEST).read_text(), "earlier evidence")
        self.assertEqual(self.publish()["plots"], 6)
        self.assertEqual(self.csv_values("dual-w3c-passed"), [7.0, 6.0])

    def test_plot_ids_and_series_labels_are_stable_across_builds(self):
        self.publish()
        first = [row["csvFileName"] for row in self.manifest()]
        next_state = state_for(self.lanes)
        next_state["build_id"] = "jenkins-example-43"
        self.publish(state=next_state)
        self.assertEqual(first, [row["csvFileName"] for row in self.manifest()])
        self.assertIn("jenkins-example-43", (self.output / reports.HTML_REPORT).read_text())


if __name__ == "__main__":
    unittest.main()
