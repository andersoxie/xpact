"""Exercise the native-suite gate without CMake, Eiffel, or an Expat download.

Small Windows command shims stand in for CMake and CTest, so the complete adapter
still crosses a real native-process exit-code boundary like Jenkins does.
"""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts/run_libexpat_adapter.ps1"
POWERSHELL = shutil.which("powershell.exe") if os.name == "nt" else None
SOURCES = (
    "acc_tests.c", "alloc_tests.c", "basic_tests.c", "chardata.c", "common.c",
    "dummy.c", "handlers.c", "memcheck.c", "minicheck.c", "misc_tests.c",
    "ns_tests.c", "nsalloc_tests.c", "runtests.c", "structdata.c",
)


@unittest.skipUnless(POWERSHELL, "Windows PowerShell is required for the adapter")
class NativeSuiteGateTests(unittest.TestCase):
    def setUp(self):
        (REPO / "build").mkdir(exist_ok=True)
        temporary = tempfile.TemporaryDirectory(prefix="libexpat gate tests ", dir=REPO / "build")
        self.root = Path(temporary.name).resolve()
        assert self.root.is_relative_to((REPO / "build").resolve())
        self.addCleanup(temporary.cleanup)
        self.source = self.root / "expat source"
        tests = self.source / "tests"
        tests.mkdir(parents=True)
        for name in SOURCES:
            (tests / name).write_text("/* local fixture */\n", encoding="utf-8")
        (tests / "alloc_tests.c").write_text("START_TEST(test_alloc_known)\n", encoding="utf-8")
        (tests / "basic_tests.c").write_text("START_TEST(test_fresh_failure)\n", encoding="utf-8")
        self.expected = self.root / "expected.tsv"
        self.set_expected(True)
        self.parity = self.root / "parity.tsv"
        self.parity.write_text(
            "status\tsource\tname\tevidence\n"
            "green\tbasic_tests.c\ttest_fresh_failure\tfixture\n"
            "red\talloc_tests.c\ttest_alloc_*\tfixture\n", encoding="utf-8")
        self.library = self.root / "runtime/xpact.lib"
        self.library.parent.mkdir()
        self.library.write_bytes(b"fixture")
        self.output = self.root / "adapter reports"
        self.log = self.output / "libexpat-native-suite.log"
        self.ctest_output = self.root / "ctest-output.txt"
        tools = self.root / "tools"
        tools.mkdir()
        (tools / "cmake.cmd").write_text(
            '@echo off\n'
            'if "%~1"=="--build" if "%XPACT_GATE_BUILD_FAIL%"=="1" exit /b 3\n'
            'exit /b 0\n', encoding="ascii")
        (tools / "ctest.cmd").write_text(
            '@echo off\n'
            'type "%XPACT_GATE_CTEST_OUTPUT%"\n'
            'if "%XPACT_GATE_REJECT_LOG_WRITE%"=="1" "%XPACT_GATE_PYTHON%" -c '
            '"import os; from pathlib import Path; p=Path(os.environ[\'XPACT_GATE_NATIVE_LOG\']); '
            'assert p.resolve().is_relative_to(Path(os.environ[\'XPACT_GATE_ROOT\']).resolve()); '
            'p.unlink(); p.mkdir()"\n'
            'if not "%XPACT_GATE_CTEST_EXIT%"=="0" echo Errors while running CTest 1>&2\n'
            'exit /b %XPACT_GATE_CTEST_EXIT%\n', encoding="ascii")
        self.environment = {
            **os.environ,
            "Path": str(tools) + os.pathsep + os.environ.get("Path", ""),
            "XPACT_GATE_SCRIPT": str(SCRIPT),
            "XPACT_GATE_SOURCE": str(self.source),
            "XPACT_GATE_OUTPUT": str(self.output),
            "XPACT_GATE_LIBRARY": str(self.library),
            "XPACT_GATE_EXPECTED": str(self.expected),
            "XPACT_GATE_PARITY": str(self.parity),
            "XPACT_GATE_CTEST_OUTPUT": str(self.ctest_output),
            "XPACT_GATE_PYTHON": sys.executable,
            "XPACT_GATE_NATIVE_LOG": str(self.log),
            "XPACT_GATE_ROOT": str(self.root),
        }

    def set_expected(self, enabled):
        self.expected.write_text(
            "source\tname\treason\n" + (
                "alloc_tests.c\ttest_alloc_*\tfixture allocator failure\n" if enabled else ""),
            encoding="utf-8")

    def failure(self, *, name="test_alloc_known", source="alloc_tests.c", phase="during actual test"):
        location = self.source / "tests" / source
        return f"FAIL [chunksize=0 deferral=0]: {name} ({phase} at {location}:12)\n"

    def complete(self, failure=None, *, failed=1, checks=2, marker="complete"):
        return (f"run-marker:{marker}\nExpat version: fixture\n" +
                (self.failure() if failure is None and failed else failure or "") +
                f"50%: Checks: {checks}, Failed: {failed}\n")

    def run_adapter(self, output, *, exit_code=8, build_fail=False, reject_log_write=False):
        self.ctest_output.write_text(output, encoding="ascii")
        environment = {**self.environment, "XPACT_GATE_CTEST_EXIT": str(exit_code),
                       "XPACT_GATE_BUILD_FAIL": "1" if build_fail else "0",
                       "XPACT_GATE_REJECT_LOG_WRITE": "1" if reject_log_write else "0"}
        wrapper = r"""
$BeforePath = $env:Path
$ErrorActionPreference = 'Continue'
$Failure = $null
try {
    & $env:XPACT_GATE_SCRIPT -Mode NativeSuite -SkipNativeBuild `
      -ExpatSourceDir $env:XPACT_GATE_SOURCE -OutputDir $env:XPACT_GATE_OUTPUT `
      -XpactLibrary $env:XPACT_GATE_LIBRARY -ExpectedFailuresFile $env:XPACT_GATE_EXPECTED `
      -ParityFile $env:XPACT_GATE_PARITY
    $AdapterExitCode = $LASTEXITCODE
} catch {
    $Failure = $_.Exception.Message
}
if ($env:Path -ne $BeforePath) { Write-Output 'PATH WAS NOT RESTORED'; exit 99 }
if ($ErrorActionPreference -ne 'Continue') { Write-Output 'PREFERENCE WAS NOT RESTORED'; exit 99 }
if ($null -ne $Failure) { Write-Output ('WRAPPER-ERROR: ' + $Failure); exit 1 }
Write-Output ('Wrapper-LASTEXITCODE=' + $AdapterExitCode)
exit $AdapterExitCode
"""
        result = subprocess.run(
            [POWERSHELL, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
             "-Command", wrapper], cwd=self.root, env=environment,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace", timeout=30)
        self.assertNotEqual(result.returncode, 99, result.stdout)
        return result

    def test_expected_failure_has_successful_jenkins_wrapper_exit_and_visible_output(self):
        plain = self.complete()
        for output in (plain, "".join(f"1: {line}\n" for line in plain.splitlines())):
            with self.subTest(verbose_prefix=output.startswith("1: ")):
                result = self.run_adapter(output)
                self.assertEqual(result.returncode, 0, result.stdout)
                self.assertIn("Wrapper-LASTEXITCODE=0", result.stdout)
                self.assertIn("test_alloc_known", result.stdout)
                self.assertIn("run-marker:complete", self.log.read_text(encoding="utf-8-sig"))

    def test_crash_and_unexpected_results_cannot_borrow_expected_failure_status(self):
        cases = {
            "segfault after known failure": (self.failure() + "***Exception: SegFault\n", 8),
            "segfault despite complete-looking output": (self.complete() + "***Exception: SegFault\n", 8),
            "missing summary": (self.failure(), 8),
            "summary count mismatch": (self.complete(failed=2), 8),
            "duplicate summary": (self.complete() + "50%: Checks: 2, Failed: 1\n", 8),
            "empty suite": (self.complete(failed=0, checks=0), 0),
            "unexpected test": (self.complete(self.failure(name="test_fresh_failure", source="basic_tests.c")), 8),
            "unregistered name": (self.complete(self.failure(name="test_missing")), 8),
            "setup failure": (self.complete(self.failure(phase="during setup")), 8),
            "teardown failure": (self.complete(self.failure(phase="during teardown")), 8),
            "ctest infrastructure exit": (self.complete(), 2),
        }
        for label, (output, exit_code) in cases.items():
            with self.subTest(label=label):
                result = self.run_adapter(output, exit_code=exit_code)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn("WRAPPER-ERROR:", result.stdout)

    def test_shared_assertion_helper_uses_declared_test_source_and_rejects_ambiguity(self):
        output = self.complete(self.failure(source="chardata.c"))
        accepted = self.run_adapter(output)
        self.assertEqual(accepted.returncode, 0, accepted.stdout)
        with (self.source / "tests/basic_tests.c").open("a", encoding="utf-8") as stream:
            stream.write("START_TEST(test_alloc_known)\n")
        ambiguous = self.run_adapter(output)
        self.assertNotEqual(ambiguous.returncode, 0, ambiguous.stdout)
        self.assertIn("ambiguous", ambiguous.stdout)

    def test_failure_retry_sequence_replaces_logs_and_preserves_each_verdict(self):
        for output, accepted in (
            (self.complete(marker="first"), True),
            ("run-marker:crash\n" + self.failure() + "***Exception: SegFault\n", False),
            (self.complete(marker="recovered"), True),
            (self.complete(self.failure(name="test_fresh_failure", source="basic_tests.c"), marker="new-failure"), False),
        ):
            with self.subTest(output=output.splitlines()[0]):
                result = self.run_adapter(output)
                self.assertEqual(result.returncode == 0, accepted, result.stdout)
                log = self.log.read_text(encoding="utf-8-sig")
                self.assertEqual([line for line in log.splitlines() if line.startswith("run-marker:")],
                                 [output.splitlines()[0]])
        result = self.run_adapter(self.complete(failed=0), exit_code=0)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("expected failures remain", result.stdout)
        self.set_expected(False)
        passed = "".join(f"1: {line}\n" for line in self.complete(failed=0).splitlines())
        result = self.run_adapter(passed, exit_code=0)
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_build_failure_clears_previous_native_run_log(self):
        first = self.run_adapter(self.complete(marker="obsolete"))
        self.assertEqual(first.returncode, 0, first.stdout)
        failed = self.run_adapter("run-marker:should-not-run\n", build_fail=True)
        self.assertNotEqual(failed.returncode, 0, failed.stdout)
        log = self.log.read_text(encoding="utf-8-sig")
        self.assertNotIn("run-marker:obsolete", log)
        self.assertNotIn("run-marker:should-not-run", log)

    def test_log_persistence_failure_is_fatal_and_restores_process_environment(self):
        failed = self.run_adapter(self.complete(), reject_log_write=True)
        self.assertNotEqual(failed.returncode, 0, failed.stdout)
        self.assertIn("WRAPPER-ERROR:", failed.stdout)
        self.assertTrue(self.log.is_dir(), failed.stdout)


if __name__ == "__main__":
    unittest.main()
