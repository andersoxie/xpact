import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import run_dual_jenkins as runner


class CampaignLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.calls = []
        self.catalog_status = "complete"
        self.w3c_status = "complete"
        self.fail_lane = None
        self.missing_report = None
        self.subject_status = None
        summary_patch = patch.object(runner.subject, "publish_summary", self.subject_summary)
        summary_patch.start()
        self.addCleanup(summary_patch.stop)

    def subject_summary(self, output, lane_reports, lane_states, **options):
        status = self.subject_status or (
            "failed" if any(row["status"] == "failed" for row in lane_states.values()) else "complete")
        (output / "xpact-junit.xml").write_text('<testsuites/>')
        summary = {"implementation": "xpact", "status": status,
                   "junit": "xpact-junit.xml", "summary": "xpact-summary.json"}
        runner.builds.write_json_atomic(output / "xpact-summary.json", summary)
        return summary

    def fake_lane(self, name, destination, options):
        destination = Path(destination)
        self.calls.append((name, destination, options))
        destination.mkdir()
        (destination / "raw.log").write_text("original " + name + " diagnostics")
        if self.fail_lane == name:
            raise runner.CampaignError(name + " build failed")
        report = {"status": self.catalog_status if name == "catalog" else self.w3c_status,
                  "lane": name, "observed": [name]}
        if self.missing_report != name:
            runner.builds.write_json_atomic(destination / "report.json", report)
        return report

    def catalog(self, repo, destination, **options):
        self.assertEqual(Path(repo), self.repo)
        return self.fake_lane("catalog", destination, options)

    def w3c(self, repo, destination, **options):
        self.assertEqual(Path(repo), self.repo)
        return self.fake_lane("w3c", destination, options)

    def publish(self, output, state, lane_reports):
        self.published_state = json.loads(json.dumps(state))
        self.published_lanes = json.loads(json.dumps(lane_reports))
        (output / "plots.tsv").write_text("new owned plots")
        return {"manifest": "plots.tsv", "html": "dual-implementation-plots.html", "plots": len(lane_reports)}

    def clear(self, output):
        (Path(output) / "plots.tsv").unlink(missing_ok=True)

    def campaign(self, output, **options):
        self.campaign_stdout, self.campaign_stderr = io.StringIO(), io.StringIO()
        with patch.object(runner.catalog, "run_lane", self.catalog), \
                patch.object(runner.w3c, "run_lane", self.w3c), \
                patch.object(runner.reports, "publish_reports", self.publish), \
                patch.object(runner.reports, "clear_reports", self.clear), \
                contextlib.redirect_stdout(self.campaign_stdout), contextlib.redirect_stderr(self.campaign_stderr):
            return runner.run_campaign(self.repo, output, build_id="jenkins-xpact-73", **options)

    def test_both_lanes_have_independent_directories_and_build_owned_results(self):
        output = self.root / "first"
        result = self.campaign(output, offline=True, timeout_seconds=3, iterations=250, pairs=2,
                          warmups=1, min_sample_seconds=0, sample_timeout_seconds=12)
        self.assertEqual(result["status"], "complete")
        self.assertEqual(result["build_id"], "jenkins-xpact-73")
        self.assertEqual([call[0] for call in self.calls], ["catalog", "w3c"])
        self.assertEqual([call[1] for call in self.calls], [output / "catalog", output / "w3c"])
        self.assertEqual(self.calls[0][2], {"offline": True, "iterations": 250, "pairs": 2,
                                         "warmups": 1, "min_sample_seconds": 0,
                                         "sample_timeout_seconds": 12})
        self.assertEqual(self.calls[1][2], {"offline": True, "suite_dir": None, "timeout_seconds": 3})
        self.assertEqual(set(self.published_lanes), {"catalog", "w3c"})
        self.assertEqual(self.published_state["status"], "complete")
        self.assertEqual(json.loads((output / "run.json").read_text()), result)
        for name in ("catalog", "w3c"):
            row = result["lanes"][name]
            self.assertEqual(row["report"], name + "/report.json")
            self.assertEqual(row["report_sha256"], runner.builds.file_sha256(output / row["report"]))

    def test_completed_red_w3c_campaign_keeps_both_reports_and_red_status(self):
        self.w3c_status = "complete_with_failures"
        result = self.campaign(self.root / "red")
        self.assertEqual(result["status"], "complete_with_failures")
        self.assertEqual(self.published_state["status"], "complete_with_failures")
        self.assertEqual(set(self.published_lanes), {"catalog", "w3c"})
        self.assertEqual(result["lanes"]["w3c"]["status"], "complete_with_failures")
        self.assertEqual(result["subject_summary"]["status"], "complete")

    def test_own_failure_stays_red_separately_from_the_comparison_status(self):
        self.w3c_status = "complete_with_failures"
        self.subject_status = "complete_with_failures"
        result = self.campaign(self.root / "own-red")
        self.assertEqual(result["status"], "complete_with_failures")
        self.assertEqual(result["subject_summary"]["status"], "complete_with_failures")

    def test_handled_reference_error_does_not_escape_through_native_stderr(self):
        self.fail_lane = "catalog"
        self.subject_status = "complete"
        result = self.campaign(self.root / "reference-error")
        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["subject_summary"]["status"], "complete")
        self.assertIn("catalog recorded an error", self.campaign_stdout.getvalue())
        self.assertEqual(self.campaign_stderr.getvalue(), "")

    def test_foreign_summary_identity_cannot_publish_or_decide_a_green_build(self):
        output = self.root / "foreign-summary"
        with patch.object(runner.subject, "publish_summary", return_value={
                "implementation": "xpact-core", "status": "complete", "junit": "xpact-junit.xml"}):
            with self.assertRaisesRegex(runner.CampaignError, "identity"):
                self.campaign(output)
        state = json.loads((output / "run.json").read_text())
        self.assertEqual(state["status"], "failed")
        self.assertNotIn("subject_summary", state)
        self.assertFalse((output / "plots.tsv").exists())

    def test_failed_catalog_does_not_hide_w3c_and_fresh_retry_preserves_old_evidence(self):
        self.fail_lane = "catalog"
        first = self.root / "failed"
        result = self.campaign(first)
        before = (first / "run.json").read_bytes()
        self.assertEqual(result["status"], "failed")
        self.assertIn("catalog build failed", result["lanes"]["catalog"]["error"])
        self.assertEqual(set(self.published_lanes), {"w3c"})
        self.assertEqual([call[0] for call in self.calls], ["catalog", "w3c"])
        self.assertEqual((first / "catalog/raw.log").read_text(), "original catalog diagnostics")
        self.fail_lane = None
        retry = self.campaign(self.root / "retry")
        self.assertEqual(retry["status"], "complete")
        self.assertEqual((first / "run.json").read_bytes(), before)

    def test_failed_w3c_keeps_catalog_plot_data_without_fabricating_w3c_values(self):
        self.fail_lane = "w3c"
        result = self.campaign(self.root / "partial")
        self.assertEqual(result["status"], "failed")
        self.assertEqual(self.published_state["status"], "failed")
        self.assertEqual(set(self.published_lanes), {"catalog"})
        self.assertEqual(result["lanes"]["catalog"]["status"], "complete")
        self.assertEqual(result["lanes"]["w3c"]["status"], "failed")

    def test_both_infrastructure_failures_publish_only_diagnostic_state(self):
        output = self.root / "both-failed"
        def fail_lane(repo, destination, **options):
            destination.mkdir()
            (destination / "raw.log").write_text("build evidence")
            raise OSError("compiler unavailable")
        with patch.object(runner.catalog, "run_lane", fail_lane), \
                patch.object(runner.w3c, "run_lane", fail_lane), \
                patch.object(runner.reports, "publish_reports", self.publish), \
                contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            result = runner.run_campaign(self.repo, output, build_id="jenkins-xpact-74")
        self.assertEqual(result["status"], "failed")
        self.assertEqual(self.published_lanes, {})
        self.assertTrue((output / "catalog/raw.log").is_file())
        self.assertTrue((output / "w3c/raw.log").is_file())
        self.assertEqual(result["publication"]["plots"], 0)

    def test_incomplete_return_or_missing_persisted_child_report_cannot_be_published(self):
        self.catalog_status = "running"
        result = self.campaign(self.root / "incomplete")
        self.assertEqual(result["status"], "failed")
        self.assertEqual(set(self.published_lanes), {"w3c"})
        self.catalog_status = "complete"
        self.missing_report = "catalog"
        result = self.campaign(self.root / "missing")
        self.assertEqual(result["status"], "failed")
        self.assertEqual(set(self.published_lanes), {"w3c"})
        self.assertIn("FileNotFoundError", result["lanes"]["catalog"]["error"])

    def test_publication_failure_clears_only_new_plot_outputs_and_retains_child_evidence(self):
        old = self.root / "old"
        self.campaign(old)
        old_bytes = (old / "run.json").read_bytes()
        output = self.root / "new"
        def fail_publication(root, state, lanes):
            (root / "plots.tsv").write_text("partially written")
            raise OSError("cannot persist HTML")
        with patch.object(runner.catalog, "run_lane", self.catalog), \
                patch.object(runner.w3c, "run_lane", self.w3c), \
                patch.object(runner.reports, "publish_reports", fail_publication), \
                patch.object(runner.reports, "clear_reports", self.clear), \
                contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(OSError, "persist HTML"):
                runner.run_campaign(self.repo, output, build_id="jenkins-xpact-74")
        self.assertFalse((output / "plots.tsv").exists())
        self.assertTrue((output / "catalog/raw.log").is_file())
        self.assertTrue((output / "w3c/report.json").is_file())
        state = json.loads((output / "run.json").read_text())
        self.assertEqual(state["status"], "failed")
        self.assertNotIn("publication", state)
        self.assertNotIn("subject_summary", state)
        self.assertFalse((output / "xpact-junit.xml").exists())
        self.assertIn("persist HTML", state["error"])
        self.assertEqual((old / "run.json").read_bytes(), old_bytes)
        self.assertEqual(self.campaign(self.root / "retry")["status"], "complete")

    def test_final_state_persistence_failure_clears_published_plots_before_failed_state(self):
        output = self.root / "failure"
        original_write = runner.builds.write_json_atomic
        def fail_final_write(path, value):
            if Path(path) == output / "run.json" and value.get("publication"):
                raise OSError("final owner state persistence failed")
            return original_write(path, value)
        with patch.object(runner.builds, "write_json_atomic", fail_final_write):
            with self.assertRaisesRegex(OSError, "final owner state"):
                self.campaign(output)
        state = json.loads((output / "run.json").read_text())
        self.assertEqual(state["status"], "failed")
        self.assertNotIn("publication", state)
        self.assertNotIn("subject_summary", state)
        self.assertFalse((output / "xpact-summary.json").exists())
        self.assertFalse((output / "plots.tsv").exists())
        self.assertTrue((output / "catalog/report.json").is_file())
        self.assertTrue((output / "w3c/report.json").is_file())

    def test_cleanup_failure_is_recorded_and_cannot_leave_publishable_campaign_state(self):
        output = self.root / "locked-report"
        def fail_publication(root, state, lanes):
            raise OSError("cannot persist HTML")
        with patch.object(runner.catalog, "run_lane", self.catalog), \
                patch.object(runner.w3c, "run_lane", self.w3c), \
                patch.object(runner.reports, "publish_reports", fail_publication), \
                patch.object(runner.reports, "clear_reports", side_effect=OSError("plot file locked")), \
                contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(OSError, "persist HTML"):
                runner.run_campaign(self.repo, output, build_id="jenkins-xpact-75")
        state = json.loads((output / "run.json").read_text())
        self.assertEqual(state["status"], "failed")
        self.assertNotIn("publication", state)
        self.assertIn("persist HTML", state["error"])
        self.assertIn("plot file locked", state["cleanup_error"])

    def test_occupied_output_cannot_replace_previous_owner_or_start_lanes(self):
        output = self.root / "occupied"
        self.campaign(output)
        previous = (output / "run.json").read_bytes()
        self.calls.clear()
        with self.assertRaises(FileExistsError):
            self.campaign(output)
        self.assertFalse(self.calls)
        self.assertEqual((output / "run.json").read_bytes(), previous)

    def test_input_output_overlap_and_invalid_options_are_rejected_before_mutation(self):
        suite = self.root / "suite"
        suite.mkdir()
        fixture = suite / "fixture.xml"
        fixture.write_bytes(b"<r/>")
        for output, options in ((suite / "output", {"suite_dir": suite}),
                                (self.root / "parent", {"suite_dir": self.root / "parent/suite"}),
                                (self.root / "invalid", {"timeout_seconds": float("nan")}),
                                (self.root / "invalid", {"iterations": 0})):
            with self.subTest(options=options), self.assertRaises(runner.CampaignError):
                self.campaign(output, **options)
            self.assertFalse(output.exists())
        self.assertEqual(fixture.read_bytes(), b"<r/>")
        self.assertFalse(self.calls)

    def test_interruption_records_failed_owner_and_does_not_start_more_work(self):
        output = self.root / "interrupted"
        with patch.object(runner.catalog, "run_lane", side_effect=KeyboardInterrupt), \
                patch.object(runner.w3c, "run_lane") as other, \
                patch.object(runner.reports, "clear_reports", self.clear), \
                contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(KeyboardInterrupt):
                runner.run_campaign(self.repo, output, build_id="jenkins-xpact-75")
        other.assert_not_called()
        state = json.loads((output / "run.json").read_text())
        self.assertEqual(state["status"], "failed")
        self.assertIn("KeyboardInterrupt", state["error"])
        self.assertNotIn("publication", state)


class CampaignCliTests(unittest.TestCase):
    def test_distinct_exit_codes_and_owner_arguments(self):
        scenarios = (("complete", "complete", 0),
                     ("complete_with_failures", "complete", 0),
                     ("complete_with_failures", "complete_with_failures", 1),
                     ("failed", "failed", 2))
        for comparison_status, status, expected in scenarios:
            with self.subTest(comparison=comparison_status, subject=status), \
                    patch.object(runner, "run_campaign", return_value={
                        "status": comparison_status, "subject_summary": {"status": status}}) as campaign, \
                    contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(runner.main(["--output-dir", "build/fresh", "--build-id", "jenkins-76",
                                             "--offline", "--suite-dir", "fixtures"]), expected)
                self.assertEqual(campaign.call_args.kwargs["build_id"], "jenkins-76")
                self.assertEqual(campaign.call_args.kwargs["suite_dir"], Path("fixtures"))
                self.assertTrue(campaign.call_args.kwargs["offline"])
        with patch.object(runner, "run_campaign", side_effect=OSError("disk full")), \
                contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(runner.main(["--output-dir", "build/fresh", "--build-id", "jenkins-77"]), 2)


if __name__ == "__main__":
    unittest.main()
