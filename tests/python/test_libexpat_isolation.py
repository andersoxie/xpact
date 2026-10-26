"""Run the native isolation coordinator against small self-contained C tests.

The fixture deliberately fails, crashes, and hangs. It needs Windows, CMake, and
MSVC, but does not need Eiffel, an Expat checkout, or a network connection.
"""

from __future__ import annotations

import ctypes
from ctypes import wintypes
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import unittest


REPO = Path(__file__).resolve().parents[2]
CMAKE = shutil.which("cmake")
if CMAKE is None:
    fallback = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "CMake/bin/cmake.exe"
    if fallback.is_file():
        CMAKE = str(fallback)
if CMAKE is None and os.name == "nt":
    # Visual Studio ships its own CMake next to the C++ tools.
    vswhere = Path(os.environ.get("ProgramFiles(x86)", "C:/Program Files (x86)")) / "Microsoft Visual Studio/Installer/vswhere.exe"
    if vswhere.is_file():
        found = subprocess.run(
            [str(vswhere), "-latest", "-products", "*", "-requires",
             "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
             "-find", "Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe"],
            capture_output=True, text=True, timeout=15).stdout.splitlines()
        if found:
            CMAKE = found[0].strip()
HARNESS = REPO / "adapters/libexpat/xpact_isolated_runtests.c"

MINICHECK = r"""
#ifndef FIXTURE_MINICHECK_H
#define FIXTURE_MINICHECK_H
typedef void (*tcase_test_function)(void);
typedef void (*tcase_setup_function)(void);
typedef void (*tcase_teardown_function)(void);
typedef struct TCase TCase;
typedef struct Suite Suite;
typedef struct SRunner SRunner;
enum { CK_SILENT, CK_NORMAL, CK_VERBOSE };
struct TCase {
  const char *name;
  tcase_setup_function setup;
  tcase_teardown_function teardown;
  tcase_test_function *tests;
  int ntests;
  int allocated;
  TCase *next_tcase;
};
struct Suite { const char *name; TCase *tests; };
struct SRunner { Suite *suite; int nchecks; int nfailures; };
Suite *suite_create(const char *name);
TCase *tcase_create(const char *name);
void suite_add_tcase(Suite *suite, TCase *tc);
void tcase_add_test(TCase *tc, tcase_test_function test);
SRunner *srunner_create(Suite *suite);
void srunner_free(SRunner *runner);
void _fail(const char *file, int line, const char *message);
void _check_set_test_info(const char *function, const char *filename, int lineno);
void set_subtest(const char *format, ...);
#endif
"""

FIXTURE = r"""
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include "expat_config.h"
#include "expat.h"
#include "minicheck.h"

int g_chunkSize = 0;
XML_Bool g_reparseDeferralEnabledDefault = 0;
static int poisoned = 0;
const XML_LChar *XML_ExpatVersion(void) { return "isolation-fixture"; }
Suite *suite_create(const char *name) {
  Suite *s = calloc(1, sizeof(*s)); s->name = name; return s;
}
TCase *tcase_create(const char *name) {
  TCase *tc = calloc(1, sizeof(*tc)); tc->name = name; return tc;
}
void suite_add_tcase(Suite *s, TCase *tc) {
  tc->next_tcase = s->tests; s->tests = tc;
}
void tcase_add_test(TCase *tc, tcase_test_function fn) {
  tc->tests = realloc(tc->tests, sizeof(*tc->tests) * (tc->ntests + 1));
  tc->tests[tc->ntests++] = fn; tc->allocated = tc->ntests;
}
SRunner *srunner_create(Suite *s) {
  SRunner *r = calloc(1, sizeof(*r)); r->suite = s; return r;
}
void srunner_free(SRunner *r) {
  TCase *tc = r->suite->tests;
  while (tc) { TCase *next = tc->next_tcase; free(tc->tests); free(tc); tc = next; }
  free(r->suite); free(r);
}
void _check_set_test_info(const char *a, const char *b, int c) { (void)a; (void)b; (void)c; }
void set_subtest(const char *format, ...) { (void)format; }

static void fixture_fail(void) {
  poisoned = 1; _fail("fixture.c", 1, "controlled assertion");
}
static void fixture_after_fail(void) {
  if (poisoned) _fail("fixture.c", 2, "another test poisoned this process");
  puts("FOLLOWING_PASS"); fflush(stdout);
}
static void callback(void) { _fail("callback-helper.c", 3, "callback assertion"); }
static void fixture_callback_fail(void) {
  callback(); puts("CALLBACK_RETURNED"); fflush(stdout);
}
static void fixture_crash(void) {
  RaiseException(EXCEPTION_ACCESS_VIOLATION, EXCEPTION_NONCONTINUABLE, 0, NULL);
}
static void fixture_timeout(void) {
  const char *path = getenv("XPACT_ISOLATION_PID_FILE");
  if (path) {
    FILE *f = fopen(path, "w");
    if (f) { fprintf(f, "%lu", (unsigned long)GetCurrentProcessId()); fclose(f); }
  }
  Sleep(INFINITE);
}
static void setup_fail(void) { _fail("setup-helper.c", 4, "setup assertion"); }
static void teardown_fail(void) { _fail("teardown-helper.c", 5, "teardown assertion"); }
static void fixture_setup_fail(void) { puts("SETUP_TEST_RAN"); fflush(stdout); }
static void fixture_teardown_fail(void) { puts("TEARDOWN_TEST_RAN"); fflush(stdout); }

/* Keep the original minicheck function above, then exercise all registration macros. */
#include "xpact_test_registration.h"

void make_basic_test_case(Suite *s) {
  TCase *tc = tcase_create("basic"); suite_add_tcase(s, tc);
  tcase_add_test(tc, fixture_fail);
  xpact_adapter_add_test(tc, fixture_after_fail, "fixture_after_fail", "basic_tests.c");
  tcase_add_test__ifdef_xml_dtd(tc, fixture_callback_fail);
}
void make_namespace_test_case(Suite *s) {
  TCase *setup = tcase_create("setup"); setup->setup = setup_fail; suite_add_tcase(s, setup);
  xpact_adapter_add_test(setup, fixture_setup_fail, "fixture_setup_fail", "ns_tests.c");
  TCase *teardown = tcase_create("teardown"); teardown->teardown = teardown_fail; suite_add_tcase(s, teardown);
  xpact_adapter_add_test(teardown, fixture_teardown_fail, "fixture_teardown_fail", "ns_tests.c");
}
void make_miscellaneous_test_case(Suite *s) {
  TCase *tc = tcase_create("misc"); suite_add_tcase(s, tc);
  tcase_add_test__if_xml_ge(tc, fixture_crash);
  xpact_adapter_add_test(tc, fixture_timeout, "fixture_timeout", "misc_tests.c");
}
void make_alloc_test_case(Suite *s) { (void)s; }
void make_nsalloc_test_case(Suite *s) { (void)s; }
void make_accounting_test_case(Suite *s) { (void)s; }
"""


@unittest.skipUnless(os.name == "nt" and CMAKE, "Windows, CMake, and MSVC are required")
class NativeIsolationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        vswhere = Path(os.environ.get("ProgramFiles(x86)", "C:/Program Files (x86)")) / "Microsoft Visual Studio/Installer/vswhere.exe"
        if not vswhere.is_file():
            raise unittest.SkipTest("Visual Studio C++ tools are not installed")
        version = subprocess.run(
            [str(vswhere), "-latest", "-products", "*", "-requires",
             "Microsoft.VisualStudio.Component.VC.Tools.x86.x64", "-property", "installationVersion"],
            capture_output=True, text=True, timeout=15, check=True).stdout.strip()
        if not version:
            raise unittest.SkipTest("Visual Studio C++ tools are not installed")
        help_text = subprocess.run([CMAKE, "--help"], capture_output=True, text=True, timeout=15, check=True).stdout
        generator = re.search(rf"Visual Studio {re.escape(version.split('.')[0])} \d{{4}}", help_text)
        if generator is None:
            raise unittest.SkipTest("CMake cannot use the installed Visual Studio version")
        (REPO / "build").mkdir(exist_ok=True)
        temporary = tempfile.TemporaryDirectory(prefix="libexpat isolation tests ", dir=REPO / "build")
        cls.root = Path(temporary.name).resolve()
        assert cls.root.is_relative_to((REPO / "build").resolve())
        cls.addClassCleanup(temporary.cleanup)
        source = cls.root / "source"
        source.mkdir()
        headers = {
            "expat_config.h": "#define XML_GE 1\n#define XML_DTD 1\n",
            "expat.h": "#pragma once\ntypedef void *XML_Parser;\ntypedef unsigned char XML_Bool;\ntypedef char XML_LChar;\n#define XML_TRUE 1\n#define XML_FALSE 0\n#define XML_FMT_STR \"s\"\nconst XML_LChar *XML_ExpatVersion(void);\n",
            "internal.h": "#pragma once\n",
            "minicheck.h": MINICHECK,
            "common.h": "#include \"expat.h\"\nextern int g_chunkSize;\nextern XML_Bool g_reparseDeferralEnabledDefault;\n",
        }
        for name, function in (
            ("basic_tests", "basic"), ("ns_tests", "namespace"), ("misc_tests", "miscellaneous"),
            ("alloc_tests", "alloc"), ("nsalloc_tests", "nsalloc"), ("acc_tests", "accounting"),
        ):
            headers[name + ".h"] = f"#include \"minicheck.h\"\nvoid make_{function}_test_case(Suite *suite);\n"
        for name, text in headers.items():
            (source / name).write_text(text, encoding="utf-8")
        # Keep the real registration macros, but bind their quoted includes to
        # this fixture's minimal headers instead of the production native ABI.
        shutil.copy2(REPO / "adapters/libexpat/include/xpact_test_registration.h", source)
        (source / "fixture.c").write_text(FIXTURE, encoding="utf-8")
        (source / "CMakeLists.txt").write_text(
            "cmake_minimum_required(VERSION 3.20)\nproject(isolation_fixture C)\n"
            f'add_executable(isolation_fixture "{HARNESS.as_posix()}" fixture.c)\n'
            f'target_include_directories(isolation_fixture PRIVATE "{source.as_posix()}")\n',
            encoding="utf-8")
        build = cls.root / "compiled"
        for command in (
            [CMAKE, "-S", str(source), "-B", str(build), "-G", generator.group(), "-A", "x64"],
            [CMAKE, "--build", str(build), "--config", "Debug", "--parallel", "2"],
        ):
            result = subprocess.run(command, capture_output=True, text=True, errors="replace", timeout=90)
            if result.returncode:
                raise RuntimeError(result.stdout + result.stderr)
        cls.executable = build / "Debug/isolation_fixture.exe"
        cls.kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        cls.kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        cls.kernel.OpenProcess.restype = wintypes.HANDLE
        cls.kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
        cls.kernel.WaitForSingleObject.restype = wintypes.DWORD
        cls.kernel.TerminateProcess.argtypes = [wintypes.HANDLE, wintypes.UINT]
        cls.kernel.CloseHandle.argtypes = [wintypes.HANDLE]

    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="run ", dir=self.root)
        self.work = Path(temporary.name)
        self.addCleanup(temporary.cleanup)
        self.pidfile = self.work / "child.pid"
        self.addCleanup(self.reap_fixture_child)

    def child_handle(self):
        if not self.pidfile.exists():
            return None
        value = self.pidfile.read_text().strip()
        if not value:
            return None
        return self.kernel.OpenProcess(0x00100001, False, int(value))

    def reap_fixture_child(self):
        handle = self.child_handle()
        if handle:
            try:
                if self.kernel.WaitForSingleObject(handle, 0) == 258:
                    self.kernel.TerminateProcess(handle, 99)
                    self.kernel.WaitForSingleObject(handle, 5000)
            finally:
                self.kernel.CloseHandle(handle)

    def start_suite(self, *arguments):
        return subprocess.Popen(
            [str(self.executable), *arguments], cwd=self.work,
            env={**os.environ, "XPACT_ISOLATION_PID_FILE": str(self.pidfile)},
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace")

    def run_suite(self, *arguments):
        process = self.start_suite(*arguments)
        self.addCleanup(lambda: process.poll() is None and process.kill())
        try:
            output, _ = process.communicate(timeout=20)
        except subprocess.TimeoutExpired:
            process.kill()
            self.reap_fixture_child()
            output, _ = process.communicate(timeout=5)
            self.fail("Isolation coordinator exceeded its deadline:\n" + output)
        return process.returncode, output

    def assert_child_released(self):
        handle = self.child_handle()
        if handle:
            try:
                self.assertEqual(self.kernel.WaitForSingleObject(handle, 5000), 0,
                                 "The test child remained alive after its coordinator stopped")
            finally:
                self.kernel.CloseHandle(handle)

    def test_registration_list_and_successful_selected_test(self):
        code, output = self.run_suite("--list-tests")
        self.assertEqual(code, 0, output)
        self.assertIn("basic_tests.c\tfixture_after_fail", output)
        self.assertIn("misc_tests.c\tfixture_timeout", output)
        code, output = self.run_suite("--test", "fixture_after_fail", "--timeout", "1")
        self.assertEqual(code, 0, output)
        self.assertIn("Checks: 1, Failed: 0", output)

    def test_failures_are_aggregated_and_cannot_poison_following_test(self):
        code, output = self.run_suite("--timeout", "1")
        self.assertEqual(code, 1, output)
        self.assertIn("FOLLOWING_PASS", output)
        self.assertNotIn("another test poisoned this process", output)
        self.assertNotIn("CALLBACK_RETURNED", output)
        self.assertIn("***Exception:", output)
        self.assertIn("***Timeout:", output)
        self.assertIn("Checks: 7, Failed: 6", output)
        self.assert_child_released()

    def test_callback_assertion_stops_child_without_returning_through_callback(self):
        code, output = self.run_suite("--test", "fixture_callback_fail", "--timeout", "1")
        self.assertEqual(code, 1, output)
        self.assertIn("callback assertion", output)
        self.assertNotIn("CALLBACK_RETURNED", output)
        self.assertIn("Checks: 1, Failed: 1", output)

    def test_setup_and_teardown_failures_keep_their_phase(self):
        for name, phase in (("fixture_setup_fail", "during setup"), ("fixture_teardown_fail", "during teardown")):
            with self.subTest(name=name):
                code, output = self.run_suite("--test", name, "--timeout", "1")
                self.assertEqual(code, 1, output)
                self.assertIn(phase, output)
                self.assertIn("Checks: 1, Failed: 1", output)
                if name == "fixture_setup_fail":
                    self.assertNotIn("SETUP_TEST_RAN", output)
                else:
                    self.assertIn("TEARDOWN_TEST_RAN", output)

    def test_crash_and_timeout_have_explicit_markers_and_release_the_child(self):
        for name, marker in (("fixture_crash", "***Exception:"), ("fixture_timeout", "***Timeout:")):
            with self.subTest(name=name):
                code, output = self.run_suite("--test", name, "--timeout", "1")
                self.assertNotEqual(code, 0, output)
                self.assertIn(marker, output)
                self.assertIn("Checks: 1, Failed: 1", output)
                self.assert_child_released()

    def test_cancelled_coordinator_releases_its_running_child(self):
        process = self.start_suite("--test", "fixture_timeout", "--timeout", "30")
        handle = None
        try:
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline and process.poll() is None:
                if self.pidfile.exists() and self.pidfile.read_text().strip():
                    break
                time.sleep(0.02)
            handle = self.child_handle()
            self.assertTrue(handle, "The child did not reach the blocking test")
            process.terminate()
            process.wait(timeout=5)
            self.assertEqual(self.kernel.WaitForSingleObject(handle, 5000), 0,
                             "Cancelling the coordinator leaked its child process")
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=5)
            if handle:
                if self.kernel.WaitForSingleObject(handle, 0) == 258:
                    self.kernel.TerminateProcess(handle, 99)
                    self.kernel.WaitForSingleObject(handle, 5000)
                self.kernel.CloseHandle(handle)
            process.communicate(timeout=5)


if __name__ == "__main__":
    unittest.main()
