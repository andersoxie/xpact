"""Check consolidated report meaning and build-owned publication recovery."""

import copy
import csv
import hashlib
from html.parser import HTMLParser
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock


REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts"))
import dual_jenkins_reports as dual
import jenkins_plot_report as reports
from test_dual_jenkins_reports import catalog_report, state_for, w3c_report


class PageStructure(HTMLParser):
    def __init__(self, source):
        super().__init__()
        self.tags = []
        self.links = []
        self.circles = []
        self.lines = []
        self.lanes = []
        self.feed(source)

    def handle_starttag(self, tag, attributes):
        attributes = dict(attributes)
        self.tags.append(tag)
        if tag == "a":
            self.links.append(attributes.get("href"))
        elif tag == "circle":
            self.circles.append(attributes)
        elif tag == "line":
            self.lines.append(attributes)
        elif tag == "section" and attributes.get("class") == "lane":
            self.lanes.append(attributes["id"])


def table(path, rows, delimiter="\t"):
    stream = io.StringIO(newline="")
    writer = csv.writer(stream, delimiter=delimiter, lineterminator="\n")
    writer.writerows(rows)
    path.write_text(stream.getvalue(), encoding="utf-8-sig")


class JenkinsPlotReportTests(unittest.TestCase):
    def setUp(self):
        root = REPO / "build/jenkins-plot-report-tests"
        root.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="report-", dir=root)
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.inputs = self.directory / "snapshots"
        self.inputs.mkdir()
        self.page = self.directory / "all-benchmark-plots.html"
        self.build_id = "xpact-42"
        self.workload = 'catalog <100> & "items"'
        self.engine = 'xpact <script>alert("engine")</script>'

    def source(self, lane):
        directory = self.directory / lane
        directory.mkdir(exist_ok=True)
        return directory

    def generic_inputs(self, lane="windows"):
        source = self.source(lane)
        raw = [["Benchmark", "CorpusId", "Engine", "ElapsedMs", "Iterations", "DocumentBytes", "Notes"]]
        for engine, samples in ((self.engine, (1, 2, 50, 100)), ("reference", (10, 20, 30))):
            for value in samples:
                raw.append([self.workload if lane != "large" else "", self.workload if lane == "large" else "",
                            engine, value, 1000, 2611, 'note <tag> & "quoted"'])
        table(source / reports.RESULTS[lane], raw)
        csv_path = source / "current.csv"
        table(csv_path, [[self.engine, "reference"], [2, 20]], delimiter=",")
        manifest = source / "plots.tsv"
        table(manifest, [["sourceFile", "csvFileName", "group", "title", "yaxis"],
                         [csv_path.as_posix(), "stable.csv", "Elapsed", self.workload + " median elapsed time", "Median elapsed ms"]])
        table(source / "benchmark-history.tsv", [["Build", "Benchmark", "Engine", "MedianElapsedMs"],
              [40, self.workload, self.engine, 0], [41, self.workload, self.engine, 1],
              [42, self.workload, self.engine, 2]])
        return source, manifest

    def capture_generic(self, lane="windows"):
        source, manifest = self.generic_inputs(lane)
        return reports.capture(lane, self.build_id, source, self.inputs / (lane + ".json"), manifest)

    def capture_dual(self):
        source = self.source("dual")
        lanes = {"catalog": catalog_report(), "w3c": w3c_report()}
        state = state_for(lanes)
        state["build_id"] = self.build_id
        for lane, report in lanes.items():
            target = source / lane / "report.json"
            target.parent.mkdir()
            data = json.dumps(report).encode("utf-8")
            target.write_bytes(data)
            state["lanes"][lane]["report_sha256"] = hashlib.sha256(data).hexdigest()
        state["publication"] = dual.publish_reports(source, state, lanes)
        (source / "run.json").write_text(json.dumps(state), encoding="utf-8")
        return reports.capture("dual", self.build_id, source, self.inputs / "dual.json")

    def render(self, **kwargs):
        reports.render(self.build_id, self.inputs, self.page, **kwargs)
        return self.page.read_text(encoding="utf-8")

    def test_all_four_families_render_in_one_document_with_escaped_labels_and_evidence_links(self):
        self.capture_dual()
        for lane in ("windows", "wsl", "large"):
            packet = self.capture_generic(lane)
            self.assertEqual(packet["charts"][0]["values"], [2.0, 20.0])
        page = self.render(build_url="https://jenkins.invalid/job/xpact/42/")
        structure = PageStructure(page)
        self.assertEqual(structure.tags.count("html"), 1)
        self.assertEqual(structure.tags.count("h1"), 1)
        self.assertEqual(structure.lanes, ["dual", "windows", "wsl", "large"])
        self.assertEqual(structure.tags.count("svg"), 12)  # Six dual, three current and three history.
        self.assertNotIn("script", structure.tags)
        self.assertNotIn("tag", structure.tags)
        self.assertIn("&lt;script&gt;", page)
        self.assertIn("note &lt;tag&gt; &amp; &quot;quoted&quot;", page)
        self.assertIn("lower of the two middle observations", page)
        self.assertIn("compilation and the outer Windows-to-WSL launch are excluded", page)
        self.assertIn("already decompressed XML file", page)
        self.assertIn("Passed + wrong verdicts + process errors + exclusions", page)
        evidence_links = [link for link in structure.links if not link.startswith("#")]
        self.assertTrue(evidence_links)
        self.assertTrue(all(link.startswith("https://jenkins.invalid/job/xpact/42/artifact/") for link in evidence_links))
        self.assertTrue(any(link.endswith("/dual/catalog/report.json") for link in evidence_links))

    def test_even_repetitions_preserve_lower_middle_csv_value_and_reject_average(self):
        packet = self.capture_generic()
        self.assertEqual(packet["charts"][0]["values"], [2.0, 20.0])
        self.assertEqual([row["ElapsedMs"] for row in packet["charts"][0]["observations"]
                          if row["Engine"] == self.engine], ["1", "2", "50", "100"])
        source = self.source("windows")
        table(source / "current.csv", [[self.engine, "reference"], [26, 20]], delimiter=",")
        with self.assertRaisesRegex(ValueError, "differs from current raw measurements"):
            reports.capture("windows", self.build_id, source, self.inputs / "windows.json", source / "plots.tsv")
        self.assertFalse((self.inputs / "windows.json").exists())

    def test_capture_rejects_manifest_that_omits_a_measured_engine_or_workload(self):
        self.capture_generic()
        source = self.source("windows")
        table(source / "current.csv", [[self.engine], [2]], delimiter=",")
        with self.assertRaisesRegex(ValueError, "omits a measured engine"):
            reports.capture("windows", self.build_id, source, self.inputs / "windows.json", source / "plots.tsv")
        self.assertFalse((self.inputs / "windows.json").exists())

        self.capture_generic()
        raw_path = source / reports.RESULTS["windows"]
        with raw_path.open(encoding="utf-8-sig", newline="") as stream:
            raw = list(csv.reader(stream, delimiter="\t"))
        raw.append(["another measured workload", "", self.engine, 12, 1000, 2611, ""])
        table(raw_path, raw)
        with self.assertRaisesRegex(ValueError, "omits a measured workload"):
            reports.capture("windows", self.build_id, source, self.inputs / "windows.json", source / "plots.tsv")
        self.assertFalse((self.inputs / "windows.json").exists())

    def test_status_rows_keep_unavailable_engines_visible_without_inventing_zero_measurements(self):
        source, manifest = self.generic_inputs()
        raw_path = source / reports.RESULTS["windows"]
        with raw_path.open(encoding="utf-8-sig", newline="") as stream:
            raw = list(csv.DictReader(stream, delimiter="\t"))
        fields = ["Benchmark", "Engine", "Version", "Repetition", "Iterations", "DocumentBytes",
                  "ElapsedMs", "DocsPerSecond", "MiBPerSecond", "Notes"]
        unavailable = {"Benchmark": self.workload, "Engine": "xpact native C ABI WSL unavailable",
                       "Version": "bridge-only", "Repetition": "1", "Iterations": "1000", "DocumentBytes": "2611",
                       "ElapsedMs": "not measured", "DocsPerSecond": "not measured", "MiBPerSecond": "not measured",
                       "Notes": "Eiffel-backed Linux shared object not packaged <yet>"}
        raw.append(unavailable)
        table(raw_path, [fields] + [[row.get(field, "") for field in fields] for row in raw])
        packet = reports.capture("windows", self.build_id, source, self.inputs / "windows.json", manifest)
        chart = packet["charts"][0]
        self.assertEqual(chart["values"], [2.0, 20.0])
        self.assertEqual(chart["labels"], [self.engine, "reference"])
        self.assertEqual(len(chart["observations"]), 7)
        self.assertEqual(packet["unmeasured"], [unavailable])
        page = self.render()
        self.assertIn(unavailable["Engine"], page)
        self.assertIn("Eiffel-backed Linux shared object not packaged &lt;yet&gt;", page)
        current_svg = page.split('<svg class="bars"', 1)[1].split('</svg>', 1)[0]
        self.assertNotIn(unavailable["Engine"], current_svg)
        self.assertNotIn('>0 ms</text>', current_svg)
        self.assertIn('>2 ms</text>', current_svg)
        self.assertIn('>20 ms</text>', current_svg)

    def test_history_keeps_real_zero_and_breaks_lines_at_missing_engine_observations(self):
        chart = {"workload": "catalog"}
        history = [
            {"Build": "1", "Benchmark": "catalog", "Engine": "A", "MedianElapsedMs": 0},
            {"Build": "2", "Benchmark": "catalog", "Engine": "B", "MedianElapsedMs": 5},
            {"Build": "3", "Benchmark": "catalog", "Engine": "A", "MedianElapsedMs": 4},
        ]
        page = reports.history_chart(chart, history)
        structure = PageStructure(page)
        self.assertEqual(len(structure.circles), 3)
        self.assertEqual(len(structure.lines), 0)
        self.assertIn("Build 1: 0 ms", page)
        self.assertIn("#1 0 ms → #3 4 ms", page)
        self.assertNotIn("inf", page)
        self.assertNotIn("nan", page)
        self.assertIn("Missing engine observations are gaps, never zero", page)

    def test_missing_and_disabled_lanes_are_not_zero_measurements(self):
        page = self.render(disabled=("wsl", "large"))
        self.assertEqual(page.count("Disabled or not configured for this build."), 2)
        self.assertEqual(page.count("No captured results for this build."), 2)
        self.assertNotIn("<svg", page)
        self.capture_generic("windows")
        with self.assertRaisesRegex(ValueError, "disabled lane"):
            self.render(disabled=("windows",))
        self.assertFalse(self.page.exists())

    def test_render_rejects_wrong_build_and_duplicate_lane_without_leaving_old_page(self):
        packet = self.capture_generic()
        self.render()
        wrong = copy.deepcopy(packet)
        wrong["build_id"] = "xpact-41"
        snapshot = self.inputs / "windows.json"
        snapshot.write_text(json.dumps(wrong), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "build identity"):
            self.render()
        self.assertFalse(self.page.exists())
        snapshot.write_text(json.dumps(packet), encoding="utf-8")
        self.render()
        (self.inputs / "duplicate.json").write_text(json.dumps(packet), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "duplicate lane"):
            self.render()
        self.assertFalse(self.page.exists())
        (self.inputs / "duplicate.json").unlink()
        self.assertIn("Windows same-machine benchmarks", self.render())

    def test_render_rejects_dual_campaign_from_another_build_inside_current_envelope(self):
        packet = self.capture_dual()
        self.render()
        packet["state"]["build_id"] = "xpact-41"
        self.assertEqual(packet["build_id"], self.build_id)
        (self.inputs / "dual.json").write_text(json.dumps(packet), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "different build identities"):
            self.render()
        self.assertFalse(self.page.exists())

    def test_render_rejects_incomplete_or_duplicated_chart_series(self):
        packet = self.capture_generic()
        mutations = (
            lambda p: p["charts"][0]["values"].pop(),
            lambda p: p["charts"][0]["labels"].__setitem__(1, p["charts"][0]["labels"][0]),
            lambda p: p["charts"].append(copy.deepcopy(p["charts"][0])),
            lambda p: p["charts"].clear(),
        )
        snapshot = self.inputs / "windows.json"
        for mutate in mutations:
            with self.subTest(mutation=mutate):
                snapshot.write_text(json.dumps(packet), encoding="utf-8")
                self.render()
                invalid = copy.deepcopy(packet)
                mutate(invalid)
                snapshot.write_text(json.dumps(invalid), encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "mismatched or duplicate|missing or duplicate"):
                    self.render()
                self.assertFalse(self.page.exists())

    def test_changed_persisted_dual_report_invalidates_snapshot_and_retry_recovers(self):
        self.capture_dual()
        source = self.source("dual")
        raw = source / "catalog/report.json"
        original = raw.read_bytes()
        raw.write_bytes(original + b"\n")
        with self.assertRaisesRegex(ValueError, "persisted campaign evidence"):
            reports.capture("dual", self.build_id, source, self.inputs / "dual.json")
        self.assertFalse((self.inputs / "dual.json").exists())
        self.assertEqual(raw.read_bytes(), original + b"\n")
        raw.write_bytes(original)
        reports.capture("dual", self.build_id, source, self.inputs / "dual.json")
        self.assertEqual(PageStructure(self.render()).tags.count("svg"), 6)

    def test_persistence_failures_remove_stale_output_and_release_staging_before_retry(self):
        packet = self.capture_generic()
        self.render()
        source = self.source("windows")
        raw = source / reports.RESULTS["windows"]
        original_raw = raw.read_bytes()
        earlier = self.directory / "earlier-report.html"
        earlier.write_text("Earlier evidence", encoding="utf-8")
        replace = Path.replace

        def fail_publication(path, target):
            if Path(target) in (self.page, self.inputs / "windows.json"):
                raise OSError("Simulated persistence failure")
            return replace(path, target)

        with mock.patch.object(Path, "replace", fail_publication):
            with self.assertRaisesRegex(OSError, "persistence failure"):
                self.render()
            self.assertFalse(self.page.exists())
            with self.assertRaisesRegex(OSError, "persistence failure"):
                reports.capture("windows", self.build_id, source, self.inputs / "windows.json", source / "plots.tsv")
        self.assertFalse((self.inputs / "windows.json").exists())
        self.assertEqual(list(self.directory.rglob(".dual-plot-*.tmp")), [])
        self.assertEqual(raw.read_bytes(), original_raw)
        self.assertEqual(earlier.read_text(encoding="utf-8"), "Earlier evidence")
        recovered = reports.capture("windows", self.build_id, source, self.inputs / "windows.json", source / "plots.tsv")
        self.assertEqual(recovered, packet)
        self.assertIn("All Benchmark Plots", self.render())


if __name__ == "__main__":
    unittest.main()
