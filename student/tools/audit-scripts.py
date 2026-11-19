"""Audit the repository's scripts for risky or hidden actions (parallel, stdlib only).

    python -I student/tools/audit-scripts.py [--all] [--json out.json]

Scans the tracked .ps1/.py/.sh/.bat/.cmd files, Jenkinsfiles and GitHub workflows for patterns that
delete, overwrite, push, download-and-run, elevate, kill processes, rebuild the DLL, or hide output.
By default only ACTIVE scripts are reported; frozen evidence under reports/ and student/results/ is
counted but not listed (--all lists it too). Every hit is a line to read, not a verdict.
"""
import argparse
import json
import re
import subprocess
import sys
from collections import Counter
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
EVIDENCE = ("reports/", "student/results/", "examples/")

RULES = {
    "delete": r"Remove-Item\b[^\n]*-Recurse|\brm\s+-[a-z]*r[a-z]*f|\brmdir\s+/s|\bdel\s+/[sq]|shutil\.rmtree|os\.remove\(|\.unlink\(",
    "git-write": r"\bgit\s+(push|reset\s+--hard|clean\s+-[a-z]*f|checkout\s+--\s|branch\s+-D|tag\s+-d)|--force\b|\bgh\s+(pr\s+merge|release\s+(create|delete)|repo\s+delete)",
    "download-run": r"Invoke-Expression|\biex\b|DownloadString|curl[^\n|]*\|\s*(sh|bash)|Invoke-WebRequest|urllib\.request\.urlopen|requests\.get",
    "elevate": r"-Verb\s+RunAs|Set-ExecutionPolicy|\bsudo\b|runas\s",
    "kill": r"Stop-Process|taskkill|os\.kill|killpg|\.kill\(\)",
    "registry-system": r"HKLM:|HKCU:|reg\s+(add|delete)|Set-ItemProperty\s+-Path\s+HK|netsh\s|bcdedit|schtasks",
    "dll-rebuild": r"build-dll\.ps1|\bec(\.exe)?\s+-(batch|finalize|config)|finish_freezing|nmake\b",
    "hidden-output": r"\*>\s*\$null|Out-Null|>\s*/dev/null\s+2>&1|-WindowStyle\s+Hidden|SilentlyContinue",
    "secrets": r"(?i)(password|passwd|secret|api[_-]?key|token)\s*[:=]\s*['\"][^'\"$]{6,}['\"]",
    "abs-user-path": r"(?i)C:[\\/]+Users[\\/]+[a-z]",
}
COMPILED = {k: re.compile(v) for k, v in RULES.items()}
PATTERNS = ("*.ps1", "*.py", "*.sh", "*.bat", "*.cmd", "*Jenkinsfile*", ".github/workflows/*.yml")


def tracked_files():
    out = subprocess.run(["git", "ls-files", *PATTERNS], cwd=REPO, capture_output=True, text=True, check=True).stdout
    return [f for f in out.splitlines() if "node_modules" not in f]


def scan(rel):
    hits = []
    try:
        text = (REPO / rel).read_text(encoding="utf-8", errors="replace")
    except OSError as e:
        return rel, [("unreadable", 0, str(e))]
    for no, line in enumerate(text.splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith(("#", "//", "REM ", "::")) and "Remove-Item" not in stripped:
            continue  # comments: only real commands count
        for rule, rx in COMPILED.items():
            if rx.search(line):
                hits.append((rule, no, stripped[:140]))
    return rel, hits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--all", action="store_true", help="also list frozen evidence scripts")
    ap.add_argument("--json", help="write every hit to this JSON file")
    args = ap.parse_args()

    files = tracked_files()
    with ProcessPoolExecutor() as pool:
        results = dict(pool.map(scan, files, chunksize=8))

    active = {f: h for f, h in results.items() if not f.startswith(EVIDENCE)}
    evidence = {f: h for f, h in results.items() if f.startswith(EVIDENCE)}
    print(f"scripts: {len(files)} ({len(active)} active, {len(evidence)} frozen evidence)")
    for name, group in (("active", active), ("evidence", evidence)):
        counts = Counter(rule for hits in group.values() for rule, _, _ in hits)
        print(f"{name:8} hits by rule: " + ", ".join(f"{k}={v}" for k, v in sorted(counts.items())) or "none")

    for f in sorted(active if not args.all else results):
        for rule, no, text in results[f]:
            print(f"{rule:14} {f}:{no}  {text}")
    if args.json:
        Path(args.json).write_text(json.dumps(results, indent=1), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
