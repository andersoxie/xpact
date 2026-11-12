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
        self.omit_gobo_binary = False
        self.gobo_script_mode = "valid"
        self.gobo_layout = ".gobo"
        self.environments = []
        compiler_directory = Path(self.temporary.name) / "compilers"
        compiler_directory.mkdir()
        self.makefile_compiler = compiler_directory / "gcc"
        self.write_executable(self.makefile_compiler)
        self.write_executable(compiler_directory / "clang")
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
            "gec": "/tools/gec", "sh": "/tools/sh",
            "gobo_version": "gec version 26.10.18+test-fixture",
            "gobo_root": "/tools/gobo",
            "gobo_environment": dict(os.environ, GOBO="/tools/gobo",
                                     GOBO_EIFFEL="ge", GOBO_CC="gcc"),
        }

    def read_rows(self):
        with (self.output / "benchmark-results.tsv").open(
                encoding="utf-8", newline="") as stream:
            return list(csv.DictReader(stream, delimiter="\t"))

    def assert_no_reports(self):
        for name in REPORTS:
            self.assertFalse((self.output / name).exists(), name)

    def invoke(self, builds=("Finalized", "FinalizedAssertions"),
               compilers=("EiffelStudio",)):
        arguments = ["--output-dir", str(self.output), "--iterations", "20",
                     "--repetitions", "2"]
        for build in builds:
            arguments += ["--eiffel-build", build]
        if compilers is not None:
            for compiler in compilers:
                arguments += ["--eiffel-compiler", compiler]
        diagnostics = io.StringIO()
        original_resolve = Path.resolve

        def resolve_fixture_library(path, *args, **kwargs):
            # The runner only executes on Linux. Preserve the fake Linux library
            # root while exercising its build orchestration on Windows as well.
            if str(path).replace("\\", "/") == "/usr/lib/libexpat.so.1":
                return path
            return original_resolve(path, *args, **kwargs)

        def compiler_path(name, **kwargs):
            if name == "clang":
                return str(self.makefile_compiler.parent / "clang")
            return str(self.makefile_compiler)

        with mock.patch.object(runner, "check_prerequisites", return_value=self.tools), \
                mock.patch.object(runner, "run_checked", side_effect=self.fake_command), \
                mock.patch.object(runner.shutil, "which", side_effect=compiler_path), \
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
        self.environments.append(env)
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
        if Path(command[0]).name == "gec" and "--cc=no" in command:
            if self.gobo_script_mode != "missing":
                compiler = "clang" if self.gobo_script_mode == "clang" else "gcc"
                script = "#!/bin/sh\n"
                if self.gobo_script_mode != "empty":
                    script += ("{0} -O2 -c xpact_benchmarks1.c\n"
                               "{0} -o xpact_benchmarks xpact_benchmarks1.o -lgc\n").format(compiler)
                layouts = ("", ".gobo") if self.gobo_layout == "ambiguous" else (self.gobo_layout,)
                for layout in layouts:
                    code_directory = Path(cwd) / layout
                    code_directory.mkdir(parents=True, exist_ok=True)
                    (code_directory / "xpact_benchmarks.sh").write_text(script, encoding="utf-8")
        if Path(command[0]).name == "sh" and not self.omit_gobo_binary:
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
            if Path(command[0]).name == "gec":
                return self.tools["gobo_version"]
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
                runner.check_prerequisites()
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

    def test_default_compilers_use_isolated_modes_and_publish_both_versions(self):
        self.assertEqual(self.invoke(compilers=None), 0)
        rows = self.read_rows()
        self.assertEqual(len(rows), 16)
        gobo_rows = [row for row in rows if "Gobo" in row["Engine"]]
        self.assertEqual(len(gobo_rows), 4)
        self.assertEqual({row["Version"] for row in gobo_rows}, {self.tools["gobo_version"]})
        self.assertTrue(all("GC suspended" not in row["Engine"] for row in gobo_rows))
        self.assertTrue(all("GC suspension unavailable" in row["Notes"] for row in gobo_rows))
        gobo_measurements = [command for command, _ in self.commands
                            if "--iterations" in command and "Gobo" in Path(command[0]).parts]
        self.assertTrue(gobo_measurements)
        self.assertTrue(all("--suspend-gc" not in command for command in gobo_measurements))
        ise_measurements = [command for command, _ in self.commands
                            if "--iterations" in command and "EIFGENs" in Path(command[0]).parts]
        self.assertTrue(any("--suspend-gc" in command for command in ise_measurements))
        self.assertEqual({row["DocumentBytes"] for row in rows}, {"2611"})
        generated = [(command, cwd) for command, cwd in self.commands
                     if Path(command[0]).name == "gec" and "--cc=no" in command]
        self.assertEqual(len(generated), 2)
        self.assertEqual({cwd for _, cwd in generated}, {
            self.output / "builds" / "Gobo" / "Finalized",
            self.output / "builds" / "Gobo" / "FinalizedAssertions",
        })
        self.assertEqual({next(arg for arg in command if arg.startswith("--target="))
                          for command, _ in generated}, {
            "--target=xpact_benchmarks", "--target=xpact_benchmarks_assertions",
        })
        for command, _ in generated:
            self.assertIn("--finalize", command)
            self.assertIn("--gc=boehm", command)
            self.assertTrue(command[-1].endswith("xpact_gobo_benchmarks.ecf"))
        compiled = [command for command, _ in self.commands if Path(command[0]).name == "sh"]
        self.assertEqual(len(compiled), 2)
        self.assertTrue(all("-e" in command for command in compiled))
        for command, cwd in self.commands:
            if Path(command[0]).name == "sh":
                self.assertEqual(cwd, Path(command[-1]).parent)
                self.assertEqual(cwd.name, ".gobo")
        metadata = json.loads((self.output / "metadata.json").read_text(encoding="utf-8"))
        self.assertEqual(metadata["eiffel_compilers"], ["EiffelStudio", "Gobo"])
        self.assertEqual(metadata["gobo_version"], self.tools["gobo_version"])
        self.assertEqual(set(metadata["gobo_build_details"]), {"Finalized", "FinalizedAssertions"})
        self.assertIn("-O2", json.dumps(metadata["gobo_build_details"]))

    def test_gobo_report_qualifies_assertions_and_refreshes_version_specific_coverage(self):
        self.assertEqual(self.invoke(builds=("FinalizedAssertions",), compilers=("Gobo",)), 0)
        rows = [row for row in self.read_rows() if "Gobo" in row["Engine"]]
        self.assertTrue(all("xpact assertions requested" in row["Engine"] for row in rows))
        self.assertTrue(all("assertions enabled" not in row["Engine"] for row in rows))
        for row in rows:
            self.assertIn("Base assertions disabled", row["Notes"])
            self.assertIn("does not enforce check instructions", row["Notes"])
            self.assertIn("decreasing loop variants or supplier-only preconditions", row["Notes"])
        metadata = json.loads((self.output / "metadata.json").read_text(encoding="utf-8"))
        details = metadata["gobo_build_details"]["FinalizedAssertions"]
        self.assertTrue(details["assertions_requested"])
        self.assertFalse(details["base_assertions"])

        # A later compiler must not inherit the known 26.10 coverage claims.
        self.tools["gobo_version"] = "gec version 27.01.01+test-fixture"
        self.assertEqual(self.invoke(builds=("FinalizedAssertions",), compilers=("Gobo",)), 0)
        rows = [row for row in self.read_rows() if "Gobo" in row["Engine"]]
        self.assertTrue(all("compiler-dependent" in row["Notes"] for row in rows))
        self.assertTrue(all("does not enforce" not in row["Notes"] for row in rows))
        metadata = json.loads((self.output / "metadata.json").read_text(encoding="utf-8"))
        self.assertNotIn("26.10", metadata["gobo_build_details"]["FinalizedAssertions"]["assertion_coverage"])

        self.assertEqual(self.invoke(builds=("Finalized",), compilers=("Gobo",)), 0)
        rows = [row for row in self.read_rows() if "Gobo" in row["Engine"]]
        self.assertTrue(all("assertions discarded" in row["Engine"] for row in rows))
        metadata = json.loads((self.output / "metadata.json").read_text(encoding="utf-8"))
        self.assertFalse(metadata["gobo_build_details"]["Finalized"]["assertions_requested"])

    def test_gobo_generation_failure_c_failure_and_recovery_invalidate_old_results(self):
        self.assertEqual(self.invoke(compilers=("Gobo",)), 0)
        project = self.output / "builds" / "Gobo" / "Finalized" / ".gobo"
        executable = project / "xpact_benchmarks"
        script = project / "xpact_benchmarks.sh"
        self.assertTrue(executable.is_file())
        self.assertTrue(script.is_file())
        self.failure = lambda command: Path(command[0]).name == "gec" and "--cc=no" in command
        self.assertEqual(self.invoke(compilers=("Gobo",)), 1)
        self.assertFalse(executable.exists())
        self.assertFalse(script.exists())
        self.assert_no_reports()
        self.failure = lambda command: Path(command[0]).name == "sh"
        self.assertEqual(self.invoke(compilers=("Gobo",)), 1)
        self.assertFalse(executable.exists())
        self.assert_no_reports()
        self.failure = None
        self.assertEqual(self.invoke(builds=("FinalizedAssertions",), compilers=("Gobo",)), 0)
        rows = self.read_rows()
        self.assertEqual(len(rows), 6)
        self.assertFalse(any("assertions discarded" in row["Engine"] for row in rows))
        self.assertFalse(any("-project_path" in command for command, _ in self.commands))

    def test_gobo_success_exit_without_new_binary_never_times_previous_binary(self):
        self.assertEqual(self.invoke(compilers=("Gobo",)), 0)
        self.commands.clear()
        self.omit_gobo_binary = True
        self.assertEqual(self.invoke(compilers=("Gobo",)), 1)
        self.assertFalse(any("--iterations" in command for command, _ in self.commands))
        self.assert_no_reports()

    def test_gobo_failed_c_step_releases_partial_binary_before_recovery(self):
        self.assertEqual(self.invoke(builds=("Finalized",), compilers=("Gobo",)), 0)
        executable = self.output / "builds" / "Gobo" / "Finalized" / ".gobo" / "xpact_benchmarks"
        partial_writes = []

        def fail_after_writing_binary(command):
            if Path(command[0]).name == "sh":
                partial = Path(command[-1]).parent / "xpact_benchmarks"
                partial.write_bytes(b"incomplete native binary")
                partial_writes.append(partial)
                return True
            return False

        self.failure = fail_after_writing_binary
        self.assertEqual(self.invoke(builds=("Finalized",), compilers=("Gobo",)), 1)
        self.assertEqual(partial_writes, [executable])
        self.assertFalse(executable.exists())
        self.assert_no_reports()
        self.failure = None
        self.assertEqual(self.invoke(builds=("Finalized",), compilers=("Gobo",)), 0)
        self.assertEqual(executable.read_bytes()[:4], b"\x7fELF")
        self.assertEqual(len(self.read_rows()), 6)

    def test_gobo_missing_script_or_backend_change_cannot_reuse_previous_build(self):
        for mode in ("missing", "empty", "clang"):
            with self.subTest(mode=mode):
                self.gobo_script_mode = "valid"
                self.assertEqual(self.invoke(compilers=("Gobo",)), 0)
                self.commands.clear()
                self.gobo_script_mode = mode
                self.assertEqual(self.invoke(compilers=("Gobo",)), 1)
                self.assertFalse(any("--iterations" in command for command, _ in self.commands))
                self.assertFalse(any(Path(command[0]).name == "sh" for command, _ in self.commands))
                self.assert_no_reports()

    def test_gobo_toolchain_layout_upgrade_invalidates_legacy_artifacts_before_failure(self):
        project = self.output / "builds" / "Gobo" / "Finalized"
        legacy_binary = project / "xpact_benchmarks"
        legacy_script = project / "xpact_benchmarks.sh"
        current_binary = project / ".gobo" / "xpact_benchmarks"
        current_script = project / ".gobo" / "xpact_benchmarks.sh"
        self.gobo_layout = ""
        self.assertEqual(self.invoke(builds=("Finalized",), compilers=("Gobo",)), 0)
        self.assertTrue(legacy_binary.is_file())
        self.assertTrue(legacy_script.is_file())
        self.gobo_layout = ".gobo"
        self.failure = lambda command: Path(command[0]).name == "gec" and "--cc=no" in command
        self.assertEqual(self.invoke(builds=("Finalized",), compilers=("Gobo",)), 1)
        for path in (legacy_binary, legacy_script, current_binary, current_script):
            self.assertFalse(path.exists(), str(path))
        self.assert_no_reports()
        self.failure = None
        self.commands.clear()
        self.assertEqual(self.invoke(builds=("Finalized",), compilers=("Gobo",)), 0)
        self.assertTrue(current_binary.is_file())
        self.assertTrue(current_script.is_file())
        self.assertFalse(legacy_binary.exists())
        self.assertFalse(legacy_script.exists())
        measured = [Path(command[0]) for command, _ in self.commands
                    if "--iterations" in command and "Gobo" in Path(command[0]).parts]
        self.assertTrue(measured)
        self.assertEqual(set(measured), {current_binary})

    def test_gobo_ambiguous_generated_layout_is_rejected_before_c_compilation(self):
        self.assertEqual(self.invoke(builds=("Finalized",), compilers=("Gobo",)), 0)
        self.commands.clear()
        self.gobo_layout = "ambiguous"
        self.assertEqual(self.invoke(builds=("Finalized",), compilers=("Gobo",)), 1)
        self.assertFalse(any(Path(command[0]).name == "sh" for command, _ in self.commands))
        self.assertFalse(any("--iterations" in command for command, _ in self.commands))
        project = self.output / "builds" / "Gobo" / "Finalized"
        for directory in (project, project / ".gobo"):
            self.assertFalse((directory / "xpact_benchmarks").exists())
        self.assert_no_reports()

    def test_late_gobo_measurement_failure_discards_completed_eiffelstudio_rows(self):
        self.assertEqual(self.invoke(compilers=None), 0)
        self.commands.clear()
        self.failure = lambda command: ("--iterations" in command and
                                        "Gobo" in Path(command[0]).parts and
                                        "FinalizedAssertions" in Path(command[0]).parts)
        self.assertEqual(self.invoke(compilers=None), 1)
        completed_ise = [command for command, _ in self.commands
                         if "--iterations" in command and "EIFGENs" in Path(command[0]).parts]
        self.assertGreater(len(completed_ise), 4)
        self.assert_no_reports()

    def test_gobo_publication_failure_removes_reports_and_temporary_files_then_recovers(self):
        self.assertEqual(self.invoke(compilers=("Gobo",)), 0)
        original_replace = Path.replace
        published = []

        def fail_second_replace(path, destination):
            published.append(Path(destination).name)
            if len(published) == 2:
                raise OSError("deliberate Gobo report persistence failure")
            return original_replace(path, destination)

        with mock.patch.object(Path, "replace", fail_second_replace):
            self.assertEqual(self.invoke(compilers=("Gobo",)), 1)
        self.assertEqual(len(published), 2)
        self.assert_no_reports()
        self.assertEqual(list(self.output.glob(".xpact-report-*")), [])
        self.assertEqual(self.invoke(compilers=("Gobo",)), 0)
        self.assertEqual(len(self.read_rows()), 8)

    def test_gobo_only_prerequisites_ignore_ise_and_pin_gcc_gc_environment(self):
        tool_root = Path(self.temporary.name) / "native tools"
        tool_root.mkdir()
        for name in ("gcc", "ldd", "make", "gec", "sh"):
            self.write_executable(tool_root / name)
        gobo_root = Path(self.temporary.name) / "Gobo installation"
        base = gobo_root / "library" / "free_elks" / "library_ge.ecf"
        base.parent.mkdir(parents=True)
        base.write_text("fixture", encoding="utf-8")
        found = []

        def find_tool(name, **kwargs):
            found.append(name)
            path = tool_root / name
            return str(path) if path.is_file() else None

        injected = {"GOBO": str(gobo_root), "GOBO_CC": "zig", "GOBO_EIFFEL": "ise",
                    "GOBO_CLI_GEC": "--gc=no --setting=executable_name=wrong",
                    "GOBO_DEFAULT_SETTING": "all_assertions=true",
                    "BOEHM_GC": "/fixture/other-gc",
                    "GOBO_CLI_GECC": "--thread=9", "ISE_PLATFORM": "win64",
                    "ISE_EIFFEL": r"C:\Windows Eiffel", "ISE_C_COMPILER": "msc_vc140"}
        with mock.patch.object(runner.sys, "platform", "linux"), \
                mock.patch.dict(runner.os.environ, injected), \
                mock.patch.object(runner.shutil, "which", side_effect=find_tool), \
                mock.patch.object(runner, "run_checked", side_effect=self.fake_command):
            tools = runner.check_prerequisites(("Gobo",))
        self.assertNotIn("ec", found)
        self.assertNotIn("finish_freezing", found)
        self.assertNotIn("eiffel_version", tools)
        self.assertEqual(tools["gobo_version"], self.tools["gobo_version"])
        environment = tools["gobo_environment"]
        self.assertEqual(environment["GOBO_CC"], "gcc")
        self.assertEqual(environment["GOBO_EIFFEL"], "ge")
        self.assertEqual(environment["ISE_PLATFORM"], "linux-x86-64")
        self.assertFalse(any(name.startswith(("GOBO_CLI_", "GOBO_DEFAULT_")) for name in environment))
        self.assertNotIn("BOEHM_GC", environment)

    def test_missing_selected_gobo_compiler_fails_instead_of_silently_skipping_it(self):
        self.assertEqual(self.invoke(compilers=None), 0)
        executable = self.makefile_compiler

        def find_tool(name, **kwargs):
            return None if name == "gec" else str(executable)

        with mock.patch.object(runner.sys, "platform", "linux"), \
                mock.patch.object(runner.shutil, "which", side_effect=find_tool), \
                mock.patch.object(runner, "run_checked") as execute, \
                contextlib.redirect_stdout(io.StringIO()), \
                contextlib.redirect_stderr(io.StringIO()) as diagnostics:
            result = runner.main(["--output-dir", str(self.output),
                                  "--eiffel-compiler", "Gobo"])
        self.assertEqual(result, 1)
        self.assertIn("gec", diagnostics.getvalue())
        execute.assert_not_called()
        self.assert_no_reports()

    def test_gobo_workbench_failure_invalidates_reports_before_prerequisites_then_recovers(self):
        self.assertEqual(self.invoke(compilers=("Gobo",)), 0)
        with mock.patch.object(runner.subprocess, "run") as execute, \
                mock.patch.object(runner, "check_prerequisites") as prerequisites, \
                contextlib.redirect_stdout(io.StringIO()), \
                contextlib.redirect_stderr(io.StringIO()) as diagnostics:
            result = runner.main(["--output-dir", str(self.output),
                                  "--eiffel-compiler", "Gobo", "--eiffel-build", "Workbench"])
        self.assertEqual(result, 1)
        self.assertIn("Workbench", diagnostics.getvalue())
        execute.assert_not_called()
        prerequisites.assert_not_called()
        self.assert_no_reports()
        self.assertEqual(self.invoke(compilers=("Gobo",)), 0)
        self.assertEqual(len(self.read_rows()), 8)


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

    def test_eiffelstudio_workbench_and_repeated_compiler_selection(self):
        arguments = runner.parse_args(["--eiffel-compiler", "EiffelStudio",
                                       "--eiffel-compiler", "EiffelStudio",
                                       "--eiffel-build", "Workbench"])
        self.assertEqual(arguments.eiffel_compiler, ["EiffelStudio"])
        self.assertEqual(arguments.eiffel_build, ["Workbench"])


if __name__ == "__main__":
    unittest.main()
