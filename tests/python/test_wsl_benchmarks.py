"""Exercise Linux benchmark orchestration without installed Eiffel or GCC.

The fake toolchain creates build artifacts but never executes them, so these
state-transition checks run on Windows and Linux with only the standard library.
"""

import contextlib
import csv
import importlib.util
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[2] / "scripts/run_wsl_benchmarks.py"
SPEC = importlib.util.spec_from_file_location("run_wsl_benchmarks", SCRIPT)
runner = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = runner
SPEC.loader.exec_module(runner)


REPORTS = ("benchmark-results.tsv", "summary.md", "metadata.json")


class BenchmarkLifecycleTests(unittest.TestCase):
    def setUp(self):
        scratch = SCRIPT.parents[1] / "build" / "wsl-benchmark-tests"
        scratch.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="run-", dir=str(scratch))
        self.addCleanup(self.temporary.cleanup)
        # Exercise argument boundaries without invoking a shell.
        self.output = Path(self.temporary.name) / "reports with spaces and 'quotes'"
        self.commands = []
        self.failure = None
        self.omit_eiffel_binary = False
        compiler_directory = Path(self.temporary.name) / "compilers"
        compiler_directory.mkdir()
        self.makefile_compiler = compiler_directory / "gcc"
        self.write_executable(self.makefile_compiler)
        self.makefile_mode = "valid"
        self.expat_library = "/usr/lib/libexpat.so.1"
        self.expat_version = "expat_2.7.1"
        self.tools = {
            "ec": "/tools/ec", "gcc": "/tools/gcc",
            "finish_freezing": "/tools/finish_freezing", "ldd": "/tools/ldd",
            "eiffel_version": "ISE EiffelStudio 25.02 - linux-x86-64",
            "gcc_version": "gcc (test fixture) 12.3.0",
            "ise_platform": "linux-x86-64", "ise_eiffel": "/tools/eiffel",
            "environment": dict(os.environ, CC="/tools/gcc"),
        }

    def read_rows(self):
        with (self.output / "benchmark-results.tsv").open(
                encoding="utf-8", newline="") as stream:
            return list(csv.DictReader(stream, delimiter="\t"))

    def assert_no_reports(self):
        for name in REPORTS:
            self.assertFalse((self.output / name).exists(), name)

    def invoke(self, builds=("Finalized", "FinalizedAssertions")):
        arguments = ["--output-dir", str(self.output), "--iterations", "20",
                     "--repetitions", "2"]
        for build in builds:
            arguments += ["--eiffel-build", build]
        diagnostics = io.StringIO()
        original_resolve = Path.resolve

        def resolve_fixture_library(path, *args, **kwargs):
            # The runner only executes on Linux. Preserve the fake Linux library
            # root while exercising its build orchestration on Windows as well.
            if str(path).replace("\\", "/") == "/usr/lib/libexpat.so.1":
                return path
            return original_resolve(path, *args, **kwargs)

        with mock.patch.object(runner, "check_prerequisites", return_value=self.tools), \
                mock.patch.object(runner, "run_checked", side_effect=self.fake_command), \
                mock.patch.object(runner.shutil, "which", return_value=str(self.makefile_compiler)), \
                mock.patch.object(Path, "resolve", resolve_fixture_library), \
                contextlib.redirect_stdout(diagnostics), \
                contextlib.redirect_stderr(diagnostics):
            result = runner.main(arguments)
        self.last_diagnostics = diagnostics.getvalue()
        return result

    @staticmethod
    def write_executable(path):
        path.write_bytes(b"\x7fELF" + b"\x00" * 60)
        path.chmod(0o755)

    def fake_command(self, command, cwd=None, env=None, log_path=None):
        command = [str(value) for value in command]
        self.commands.append((command, Path(cwd) if cwd is not None else None))
        if self.failure and self.failure(command):
            raise runner.BenchmarkError("deliberate toolchain failure")
        if "-project_path" in command:
            project = Path(command[command.index("-project_path") + 1])
            target = command[command.index("-target") + 1]
            code = project / "EIFGENs" / target / (
                "F_code" if "-finalize" in command else "W_code")
            code.mkdir(parents=True, exist_ok=True)
            (code / "Makefile.SH").write_text("fake makefile", encoding="utf-8")
            makefile = code / "Makefile"
            if makefile.exists():
                makefile.unlink()
            if self.makefile_mode != "missing":
                compiler_assignment = {
                    "valid": 'CC = "{}"\n'.format(self.makefile_compiler.as_posix()),
                    "missing-cc": "", "empty-cc": "CC = \n",
                }[self.makefile_mode]
                makefile.write_text(compiler_assignment +
                                    "CFLAGS = -O3 -fno-strict-aliasing\nLDFLAGS = -lm\n",
                                    encoding="utf-8")
            if "-c_compile" in command:
                self.write_executable(code / "xpact_benchmarks")
        if Path(command[0]).name == "finish_freezing" and not self.omit_eiffel_binary:
            self.write_executable(Path(cwd) / "xpact_benchmarks")
        if "-o" in command:
            executable = Path(command[command.index("-o") + 1])
            executable.parent.mkdir(parents=True, exist_ok=True)
            self.write_executable(executable)
        if Path(command[0]).name == "ldd":
            return "libexpat.so.1 => {} (0x1234)\n".format(self.expat_library)
        if "--version" in command:
            if Path(command[0]).name == "gcc":
                return self.tools["gcc_version"]
            if Path(command[0]).name == "clang":
                return "clang version 18.1.0"
            return self.expat_version + "\n"
        return "benchmark parsed documents.\n"

    def test_success_c_compile_failure_then_recovery_does_not_reuse_report(self):
        self.assertEqual(self.invoke(), 0)
        previous_rows = self.read_rows()
        self.assertEqual(len(previous_rows), 12)
        self.failure = lambda command: Path(command[0]).name == "gcc" and "-o" in command
        self.assertEqual(self.invoke(), 1)
        self.assert_no_reports()
        self.failure = None
        self.assertEqual(self.invoke(("Workbench",)), 0)
        rows = self.read_rows()
        self.assertEqual(len(rows), 8)
        self.assertTrue(all("finalized" not in row["Engine"].lower() for row in rows))
        self.assertTrue(all(int(row["DocumentBytes"]) == 2611 for row in rows))
        metadata = json.loads((self.output / "metadata.json").read_text(encoding="utf-8"))
        self.assertIn("gcc (test fixture) 12.3.0", json.dumps(metadata))

    def test_missing_prerequisites_after_success_remove_previous_verdict(self):
        self.assertEqual(self.invoke(), 0)
        arguments = ["--output-dir", str(self.output)]
        with mock.patch.object(runner, "check_prerequisites",
                               side_effect=runner.BenchmarkError("Linux EiffelStudio missing")), \
                contextlib.redirect_stdout(io.StringIO()), \
                contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(runner.main(arguments), 1)
        self.assert_no_reports()

    def test_late_benchmark_failure_does_not_publish_partial_numeric_rows(self):
        self.assertEqual(self.invoke(), 0)
        completed_commands = []

        def fail_after_other_engines(command):
            if "--iterations" in command:
                completed_commands.append(command)
            return "--mode" in command and "tokenizer" in command and "20" in command

        self.failure = fail_after_other_engines
        self.assertEqual(self.invoke(), 1)
        self.assertGreater(len(completed_commands), 4)
        self.assert_no_reports()

    def test_modes_are_isolated_and_assertions_survive_finalization(self):
        self.assertEqual(self.invoke(("Finalized", "FinalizedAssertions", "Workbench")), 0)
        generated = [command for command, _ in self.commands if "-project_path" in command]
        self.assertEqual(len(generated), 3)
        projects = [Path(command[command.index("-project_path") + 1]) for command in generated]
        self.assertEqual(len(set(projects)), 3)
        self.assertTrue(all(path.is_relative_to(self.output) if hasattr(path, "is_relative_to")
                            else self.output in path.parents for path in projects))
        self.assertIn("-finalize", generated[0])
        self.assertNotIn("-keep", generated[0])
        self.assertIn("-finalize", generated[1])
        self.assertIn("-keep", generated[1])
        self.assertNotIn("-finalize", generated[2])
        finalized = [path for path in projects[0].rglob("xpact_benchmarks") if path.is_file()]
        assertions = [path for path in projects[1].rglob("xpact_benchmarks") if path.is_file()]
        self.assertEqual(len(finalized), 1)
        self.assertEqual(len(assertions), 1)
        self.assertEqual(self.invoke(("Workbench",)), 0)
        self.assertTrue(finalized[0].is_file())
        self.assertTrue(assertions[0].is_file())

    def test_failed_eiffel_rebuild_invalidates_its_old_binary(self):
        self.assertEqual(self.invoke(("Finalized",)), 0)
        executable = next(path for path in (self.output / "builds" / "Finalized").rglob(
            "xpact_benchmarks") if path.is_file())
        self.failure = lambda command: "-project_path" in command
        self.assertEqual(self.invoke(("Finalized",)), 1)
        self.assertFalse(executable.exists())
        self.assert_no_reports()

    def test_success_exit_without_new_eiffel_binary_cannot_time_old_build(self):
        self.assertEqual(self.invoke(("Finalized",)), 0)
        self.omit_eiffel_binary = True
        self.assertEqual(self.invoke(("Finalized",)), 1)
        self.assert_no_reports()

    def test_second_report_replace_failure_removes_all_reports_and_temporary_files(self):
        self.assertEqual(self.invoke(), 0)
        original_replace = Path.replace
        published = []

        def fail_second_replace(path, destination):
            published.append(Path(destination).name)
            if len(published) == 2:
                raise OSError("deliberate report persistence failure")
            return original_replace(path, destination)

        with mock.patch.object(Path, "replace", fail_second_replace):
            self.assertEqual(self.invoke(), 1)
        self.assertEqual(len(published), 2)
        self.assert_no_reports()
        self.assertEqual(list(self.output.glob(".xpact-report-*")), [])

    def test_library_substitution_rejects_run_instead_of_labelling_xpact_as_expat(self):
        for attribute, replacement in (
                ("expat_library", "/tmp/adapter/libexpat.so.1"),
                ("expat_version", "expat_2.8.1-xpact-eiffel-bridge")):
            with self.subTest(attribute=attribute):
                original = getattr(self, attribute)
                setattr(self, attribute, replacement)
                self.assertEqual(self.invoke(), 1)
                self.assert_no_reports()
                setattr(self, attribute, original)

    def test_windows_compiler_environment_and_executable_are_rejected(self):
        with mock.patch.object(runner.sys, "platform", "linux"), \
                mock.patch.dict(runner.os.environ, {"ISE_PLATFORM": "win64"}):
            with self.assertRaisesRegex(runner.BenchmarkError, "ISE_PLATFORM"):
                runner.check_prerequisites(SCRIPT.parents[1])
        self.output.mkdir(parents=True, exist_ok=True)
        windows_compiler = self.output / "ec.exe"
        windows_compiler.write_bytes(b"MZ" + b"\x00" * 62)
        windows_compiler.chmod(0o755)
        with self.assertRaisesRegex(runner.BenchmarkError, "native Linux"):
            runner.require_linux_executable(windows_compiler, "ec", elf=True)

    def test_loader_and_include_overrides_do_not_cross_into_benchmarks(self):
        injected = {name: "/fixture/xpact" for name in (
            "LD_LIBRARY_PATH", "LD_PRELOAD", "LIBRARY_PATH", "CPATH", "C_INCLUDE_PATH")}
        injected["XPACT_FIXTURE_UNRELATED"] = "preserve"
        with mock.patch.dict(runner.os.environ, injected):
            environment = runner.clean_environment()
        for name in injected:
            if name != "XPACT_FIXTURE_UNRELATED":
                self.assertNotIn(name, environment)
        self.assertEqual(environment["XPACT_FIXTURE_UNRELATED"], "preserve")

    def test_generated_compiler_and_flags_are_recorded_and_clang_rebuild_is_rejected(self):
        compiler_directory = Path(self.temporary.name) / "compilers"
        gcc = compiler_directory / "gcc"
        clang = compiler_directory / "clang"
        for path in (gcc, clang):
            self.write_executable(path)

        self.makefile_compiler = gcc
        self.assertEqual(self.invoke(("Finalized",)), 0)
        metadata = json.loads((self.output / "metadata.json").read_text(encoding="utf-8"))
        details = metadata["eiffel_build_details"]["Finalized"]
        self.assertEqual(details["compiler_path"], str(gcc.resolve()))
        self.assertEqual(details["compiler_version"], self.tools["gcc_version"])
        self.assertEqual(details["makefile_assignments"]["CFLAGS"], "-O3 -fno-strict-aliasing")
        self.commands.clear()
        self.makefile_compiler = clang
        self.assertEqual(self.invoke(("Finalized",)), 1)
        self.assertIn("other than GCC", self.last_diagnostics)
        self.assertFalse(any("--iterations" in command for command, _ in self.commands))
        self.assert_no_reports()

    def test_unidentified_generated_compiler_cannot_publish_gcc_results(self):
        for mode in ("missing", "missing-cc", "empty-cc"):
            with self.subTest(makefile=mode):
                self.makefile_mode = "valid"
                self.assertEqual(self.invoke(("Finalized",)), 0)
                self.commands.clear()
                self.makefile_mode = mode
                self.assertEqual(self.invoke(("Finalized",)), 1)
                self.assertFalse(any("--iterations" in command for command, _ in self.commands))
                self.assert_no_reports()


class TimingTests(unittest.TestCase):
    def test_iteration_overflow_is_rejected_before_starting_a_subprocess(self):
        with mock.patch.object(runner.subprocess, "run") as execute, \
                mock.patch.object(runner, "check_prerequisites") as prerequisites, \
                contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as failure:
                runner.main(["--iterations", "2147483648"])
        self.assertEqual(failure.exception.code, 2)
        execute.assert_not_called()
        prerequisites.assert_not_called()

    def test_warmup_is_untimed_and_rows_use_linux_process_elapsed_time(self):
        engine = runner.Engine("fixture", Path("/fixture/parser"), ["--mode", "tokenizer"],
                               "1.0", "fixture notes")
        with mock.patch.object(runner, "run_checked", return_value="parsed") as execute, \
                mock.patch.object(runner.time, "perf_counter", side_effect=[10.0, 10.25, 20.0, 20.5]) as timer:
            rows = runner.measure_engine(engine, iterations=20, repetitions=2)
        self.assertEqual(execute.call_count, 3)
        self.assertEqual(timer.call_count, 4)
        self.assertEqual([row["ElapsedMs"] for row in rows], [250.0, 500.0])
        self.assertEqual([row["DocsPerSecond"] for row in rows], [80.0, 40.0])
        for call in execute.call_args_list:
            self.assertNotIn("wsl.exe", [str(value) for value in call.args[0]])


if __name__ == "__main__":
    unittest.main()
