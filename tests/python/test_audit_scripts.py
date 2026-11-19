"""Tests for student/tools/audit-scripts.py (the risky-pattern audit of the repository's scripts)."""
import contextlib
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("audit_scripts", REPO / "student/tools/audit-scripts.py")
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class ScanTests(unittest.TestCase):
    def scan_text(self, text, name="probe.ps1"):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / name).write_text(text, encoding="utf-8")
            with mock.patch.object(audit, "REPO", Path(tmp)):
                return audit.scan(name)

    def test_each_rule_fires_on_a_typical_line(self):
        lines = {
            "delete": "Remove-Item -Recurse -Force $Dir",
            "git-write": "git push --force origin main",
            "download-run": "iex (New-Object Net.WebClient).DownloadString($u)",
            "elevate": "Start-Process pwsh -Verb RunAs",
            "kill": "taskkill /F /IM x.exe",
            "registry-system": "Set-ItemProperty -Path HKLM:\\Software\\X -Name a -Value 1",
            "dll-rebuild": ".\\website\\scripts\\build-dll.ps1",
            "hidden-output": "& tool.exe *> $null",
            "secrets": "$password = 'hunter22secret'",
            "abs-user-path": "$p = 'C:\\Users\\someone\\file'",
        }
        for rule, line in lines.items():
            with self.subTest(rule=rule):
                _, hits = self.scan_text(line + "\n")
                self.assertIn(rule, {h[0] for h in hits})

    def test_comments_and_harmless_lines_are_ignored(self):
        _, hits = self.scan_text("# git push --force\nWrite-Host 'hello'\n")
        self.assertEqual(hits, [])
        _, hits = self.scan_text("# Remove-Item -Recurse $x\n")
        self.assertEqual([h[0] for h in hits], ["delete"])  # commented deletes are still shown

    def test_hit_has_line_number_and_text(self):
        _, hits = self.scan_text("ok\nshutil.rmtree(p)\n", name="probe.py")
        self.assertEqual(hits, [("delete", 2, "shutil.rmtree(p)")])

    def test_unreadable_file(self):
        with mock.patch.object(audit, "REPO", Path("Z:/does/not/exist")):
            _, hits = audit.scan("missing.ps1")
        self.assertEqual(hits[0][0], "unreadable")


class MainTests(unittest.TestCase):
    def test_main_reports_active_and_evidence(self):
        fake = {"scripts/a.ps1": [("delete", 3, "Remove-Item -Recurse x")], "reports/r/b.py": [("kill", 1, "os.kill(1)")]}

        class FakePool:
            def __init__(self, *a, **k):
                pass

            def __enter__(self):
                return self

            def __exit__(self, *a):
                return False

            def map(self, fn, files, chunksize=1):
                return [(f, fake[f]) for f in files]

        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "hits.json"
            buffer = io.StringIO()
            with mock.patch.object(audit, "tracked_files", return_value=list(fake)), \
                    mock.patch.object(audit, "ProcessPoolExecutor", FakePool), \
                    mock.patch.object(sys, "argv", ["audit-scripts.py", "--json", str(out)]), \
                    contextlib.redirect_stdout(buffer):
                self.assertEqual(audit.main(), 0)
            text = buffer.getvalue()
            self.assertIn("scripts: 2 (1 active, 1 frozen evidence)", text)
            self.assertIn("scripts/a.ps1:3", text)
            self.assertNotIn("reports/r/b.py:1", text)  # evidence is counted, not listed
            self.assertEqual(json.loads(out.read_text(encoding="utf-8"))["scripts/a.ps1"][0][0], "delete")

    def test_tracked_files_lists_this_script(self):
        files = audit.tracked_files()
        self.assertIn("website/scripts/publish.ps1", files)
        self.assertFalse(any("node_modules" in f for f in files))


if __name__ == "__main__":
    unittest.main()
