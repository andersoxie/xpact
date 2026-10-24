"""Validate paired benchmark measurements without an installed Eiffel toolchain."""

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[2] / "scripts/compare_eiffel_benchmarks.py"
SPEC = importlib.util.spec_from_file_location("compare_eiffel_benchmarks", SCRIPT)
runner = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = runner
SPEC.loader.exec_module(runner)


class PairedBenchmarkTests(unittest.TestCase):
    def setUp(self):
        scratch = SCRIPT.parents[1] / "build/paired-benchmark-tests"
        scratch.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="run-", dir=str(scratch))
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.baseline = self.directory / "baseline with spaces.exe"
        self.candidate = self.directory / "candidate 'quoted'.exe"
        self.baseline.write_bytes(b"baseline fixture")
        self.candidate.write_bytes(b"candidate fixture")
        self.output = self.directory / "reports"
        self.workloads = [runner.Workload("catalog", None, 2611, 10)]
        self.calls = []

    def arguments(self, *extra):
        return ["--baseline", str(self.baseline), "--candidate", str(self.candidate),
                "--output-dir", str(self.output), "--workload", "catalog",
                "--iterations", "10", "--pairs", "2", "--warmups", "1",
                "--min-sample-seconds", "0"] + list(extra)

    def role(self, executable):
        return "A" if Path(executable) == self.baseline else "B"

    def sample(self, executable, iterations, workload, phase, output_dir):
        self.calls.append((self.role(executable), iterations, phase))
        return 0.2 if self.role(executable) == "A" else 0.1

    def invoke(self, sample=None, *extra):
        with mock.patch.object(runner, "prepare_workloads", side_effect=lambda args: self.workloads), \
                mock.patch.object(runner, "run_sample", side_effect=sample or self.sample), \
                contextlib.redirect_stdout(io.StringIO()), \
                contextlib.redirect_stderr(io.StringIO()):
            return runner.main(self.arguments(*extra))

    def report(self):
        return json.loads((self.output / "comparison.json").read_text(encoding="utf-8"))

    def assert_no_reports(self):
        for name in runner.REPORT_NAMES:
            self.assertFalse((self.output / name).exists(), name)

    def assert_collision_rejected_without_mutation(self, extra, inputs):
        files = {path for path in self.output.rglob("*") if path.is_file()}
        preserved = files | {self.baseline, self.candidate} | set(inputs)
        snapshots = {path: path.read_bytes() for path in preserved}
        with mock.patch.object(runner, "run_sample") as sample, \
                mock.patch.object(runner, "prepare_workloads", wraps=runner.prepare_workloads) as prepare, \
                mock.patch.object(runner, "clear_reports", wraps=runner.clear_reports) as clear, \
                mock.patch.object(Path, "mkdir", side_effect=AssertionError("directory creation before collision check")), \
                contextlib.redirect_stdout(io.StringIO()), \
                contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(runner.main(self.arguments(*extra)), 1)
        sample.assert_not_called()
        prepare.assert_not_called()
        clear.assert_not_called()
        self.assertEqual({path for path in self.output.rglob("*") if path.is_file()}, files)
        for path, content in snapshots.items():
            self.assertEqual(path.read_bytes(), content, str(path))

    def test_generated_fixture_collision_preserves_caller_xml_and_previous_reports(self):
        self.assertEqual(self.invoke(), 0)
        fixtures = self.output / "fixtures"
        fixtures.mkdir()
        for workload in ("text", "attributes"):
            with self.subTest(workload=workload):
                caller_xml = fixtures / (workload + ".xml")
                caller_xml.write_bytes(b"<caller>\r\nkeep original &amp; bytes\r\n</caller>")
                self.assert_collision_rejected_without_mutation(
                    ["--workload", workload, "--workload", "files", "--xml-file", str(caller_xml)],
                    [caller_xml])

    def test_report_name_xml_input_is_preserved_before_old_report_cleanup(self):
        self.assertEqual(self.invoke(), 0)
        for report_name in runner.REPORT_NAMES:
            with self.subTest(report=report_name):
                caller_xml = self.output / report_name
                caller_xml.write_bytes(b"<caller>XML files can have a report filename</caller>")
                self.assert_collision_rejected_without_mutation(
                    ["--workload", "files", "--xml-file", str(caller_xml)], [caller_xml])

    def test_executable_collision_with_fixture_or_report_is_preserved(self):
        self.assertEqual(self.invoke(), 0)
        fixtures = self.output / "fixtures"
        fixtures.mkdir()
        destinations = [self.output / name for name in runner.REPORT_NAMES]
        destinations += [fixtures / "text.xml", fixtures / "attributes.xml"]
        for option in ("--baseline", "--candidate"):
            for executable in destinations:
                with self.subTest(option=option, destination=executable.name):
                    executable.write_bytes(b"MZ caller-owned executable fixture")
                    self.assert_collision_rejected_without_mutation(
                        [option, str(executable)], [executable])

    def test_hardlink_input_aliases_cannot_evade_collision_check(self):
        self.assertEqual(self.invoke(), 0)
        fixtures = self.output / "fixtures"
        fixtures.mkdir()
        cases = (("--xml-file", fixtures / "text.xml", "--workload", "text"),
                 ("--candidate", self.output / "comparison.tsv", "--workload", "catalog"),
                 ("--baseline", fixtures / "attributes.xml", "--workload", "catalog"))
        for index, (option, destination, workload_option, workload) in enumerate(cases):
            with self.subTest(option=option, destination=destination.name):
                destination.write_bytes(b"<caller>hard-link input bytes remain untouched</caller>")
                alias = self.directory / ("caller-alias-{}.xml".format(index))
                try:
                    os.link(str(destination), str(alias))
                except (OSError, NotImplementedError) as error:
                    self.skipTest("Hard links are unavailable on this filesystem: {}".format(error))
                extra = [option, str(alias), workload_option, workload]
                if option == "--xml-file":
                    extra += ["--workload", "files"]
                self.assert_collision_rejected_without_mutation(extra, [alias, destination])

    def test_calibration_doubles_one_common_count_until_both_samples_are_long_enough(self):
        calibration = {10: {"A": 0.1, "B": 0.8},
                       20: {"A": 0.8, "B": 0.4},
                       40: {"A": 0.8, "B": 0.9}}

        def sample(executable, iterations, workload, phase, output_dir):
            self.calls.append((self.role(executable), iterations, phase))
            return calibration[iterations][self.role(executable)]

        self.assertEqual(self.invoke(sample, "--min-sample-seconds", "0.5", "--pairs", "1"), 0)
        calibrations = [(role, count) for role, count, phase in self.calls if "calibration" in phase]
        self.assertEqual(calibrations, [("A", 10), ("B", 10), ("A", 20), ("B", 20),
                                        ("A", 40), ("B", 40)])
        self.assertTrue(all(count == 40 for _, count, phase in self.calls if "calibration" not in phase))
        report = self.report()
        self.assertEqual([row["Iterations"] for row in report["calibration"]], [10, 20, 40])
        self.assertEqual(report["results"][0]["Iterations"], 40)
        self.assertEqual(report["summary"][0]["iterations"], 40)

    def test_order_alternates_and_summary_uses_median_of_paired_ratios(self):
        times = {1: {"A": 100.0, "B": 1.0},
                 2: {"A": 2.0, "B": 1.0},
                 3: {"A": 100.0, "B": 100.0}}

        def sample(executable, iterations, workload, phase, output_dir):
            role = self.role(executable)
            self.calls.append((role, iterations, phase))
            if "warmup" in phase:
                return 0.4
            pair = int(phase.split("-pair-")[1].split("-")[0])
            return times[pair][role]

        self.assertEqual(self.invoke(sample, "--warmups", "2", "--pairs", "3"), 0)
        warmups = [role for role, _, phase in self.calls if "warmup" in phase]
        pairs = [role for role, _, phase in self.calls if "-pair-" in phase]
        self.assertEqual(warmups, ["A", "B", "B", "A"])
        self.assertEqual(pairs, ["A", "B", "B", "A", "A", "B"])
        report = self.report()
        self.assertEqual([row["Order"] for row in report["results"]], ["AB", "BA", "AB"])
        self.assertEqual([row["CandidateSpeedRatio"] for row in report["results"]], [100.0, 2.0, 1.0])
        summary = report["summary"][0]
        self.assertEqual(summary["median_candidate_speed_ratio"], 2.0)
        # Dividing the unpaired medians would incorrectly report 100 rather than 2.
        self.assertEqual(summary["median_baseline_ms"] / summary["median_candidate_ms"], 100.0)
        self.assertEqual(summary["min_candidate_speed_ratio"], 1.0)
        self.assertEqual(summary["max_candidate_speed_ratio"], 100.0)
        self.assertEqual(summary["pairs"], 3)

    def test_success_midpair_failure_then_recovery_cannot_publish_stale_or_partial_pairs(self):
        self.assertEqual(self.invoke(), 0)
        self.assertEqual(len(self.report()["results"]), 2)

        def fail_second_pair(executable, iterations, workload, phase, output_dir):
            value = self.sample(executable, iterations, workload, phase, output_dir)
            if phase == "catalog-pair-2-A":
                raise runner.BenchmarkError("deliberate parse failure after the candidate sample")
            return value

        self.calls.clear()
        self.assertEqual(self.invoke(fail_second_pair), 1)
        self.assertTrue(any(phase == "catalog-pair-1-B" for _, _, phase in self.calls))
        self.assertTrue(any(phase == "catalog-pair-2-B" for _, _, phase in self.calls))
        self.assert_no_reports()
        self.workloads = [runner.Workload("catalog", None, 2611, 20)]
        self.assertEqual(self.invoke(), 0)
        self.assertEqual([row["Iterations"] for row in self.report()["results"]], [20, 20])

    def test_missing_executable_after_success_removes_old_reports_before_sampling(self):
        self.assertEqual(self.invoke(), 0)
        self.candidate.unlink()
        self.calls.clear()
        self.assertEqual(self.invoke(), 1)
        self.assertEqual(self.calls, [])
        self.assert_no_reports()

    def test_second_report_replace_failure_clears_published_report_and_staging_files(self):
        self.assertEqual(self.invoke(), 0)
        original_replace = Path.replace
        replacements = []

        def fail_second(path, destination):
            replacements.append(Path(destination).name)
            if len(replacements) == 2:
                raise OSError("deliberate report persistence failure")
            return original_replace(path, destination)

        with mock.patch.object(Path, "replace", fail_second):
            self.assertEqual(self.invoke(), 1)
        self.assertEqual(len(replacements), 2)
        self.assert_no_reports()
        self.assertEqual(list(self.output.glob(".comparison-*")), [])

    def test_real_sample_rejects_nonzero_exit_wrong_count_or_extra_output(self):
        valid = "xpact benchmark harness parsed 10 documents.\n"
        cases = ((1, valid, "nonzero-exit"),
                 (0, "xpact benchmark harness parsed 9 documents.\n", "wrong-count"),
                 (0, "unverified output\n" + valid, "extra-output"))
        for exit_code, stdout, phase in cases:
            with self.subTest(phase=phase), \
                    mock.patch.object(runner.subprocess, "run", return_value=subprocess.CompletedProcess(
                        [str(self.baseline)], exit_code, stdout=stdout, stderr="fixture diagnostic")), \
                    mock.patch.object(runner.time, "perf_counter", side_effect=[100.0, 100.25]):
                with self.assertRaises(runner.BenchmarkError):
                    runner.run_sample(self.baseline, 10, self.workloads[0], phase, self.output)
                self.assertTrue((self.output / "logs" / (phase + ".log")).is_file())
        with mock.patch.object(runner.subprocess, "run", return_value=subprocess.CompletedProcess(
                [str(self.baseline)], 0, stdout=valid, stderr="")) as execute, \
                mock.patch.object(runner.time, "perf_counter", side_effect=[100.0, 100.25]):
            self.assertEqual(runner.run_sample(self.baseline, 10, self.workloads[0], "valid", self.output), 0.25)
        self.assertEqual(execute.call_args[0][0], [str(self.baseline), "--iterations", "10"])


if __name__ == "__main__":
    unittest.main()
