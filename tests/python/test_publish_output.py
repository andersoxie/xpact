"""website/scripts/publish.ps1 refuses an -Output that is not a file system folder (#453 review on #459).

The check runs before the DLL check, the frontend build, dotnet publish and the cleanup, so these tests
need no DLLs, npm or dotnet: a refused -Output must stop the script before any of them.
"""
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "website/scripts/publish.ps1"
POWERSHELL = shutil.which("powershell.exe") if os.name == "nt" else None


@unittest.skipUnless(POWERSHELL, "Windows PowerShell is required for publish.ps1")
class PublishOutputProviderTests(unittest.TestCase):
    def run_publish(self, output, cwd):
        return subprocess.run(
            [POWERSHELL, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
             "-File", str(SCRIPT), "-Output", output],
            cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace", timeout=60)

    def test_non_file_system_output_fails_before_build_or_cleanup(self):
        for output in ("Env:Path", "Variable:PWD", "Function:prompt"):
            with self.subTest(output=output), tempfile.TemporaryDirectory(prefix="publish provider ") as work:
                result = self.run_publish(output, work)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn("must be a file system folder", result.stdout)
                self.assertNotIn("== Frontend", result.stdout)
                self.assertNotIn("== API and worker", result.stdout)
                # The old resolver turned "Env:Path" into a local folder named "Path".
                self.assertEqual(list(Path(work).iterdir()), [], "nothing may be created in the working folder")


if __name__ == "__main__":
    unittest.main()
