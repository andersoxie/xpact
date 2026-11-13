"""A04 (#168): run each test, benchmark and example runner under loadwatch.py and check which library it loads.

Every DLL named xpact*.dll or libexpat*.dll that a process loads is identified by its
SHA-256, against the builds that exist right after that runner (runners may rebuild):

  normal       build\\native-eiffel\\xpact.dll             (Eiffel-backed, assertions off)
  assertions   build\\native-eiffel\\xpact_assertions.dll  (Eiffel-backed, assertions on)
  bridge-only  build\\native\\xpact.dll                    (C bridge without Eiffel, error 44)
  expat-2.8.1  ..\\xpactGit\\build\\libexpat-R_2_8_1\\build\\libexpat.dll
  unknown      any other file: a stale copy or another build

A runner passes when the set of libraries it loads is exactly the expected set.

Usage: python -I run_a04.py [--only id ...] [--list]
Output: build/a04/<id>/ (raw watch.json and console, not in git); runs/<id>/loads.txt and
console.txt (or console-tail.txt when the log is over 300 KB); results.tsv, results.json
"""
from __future__ import annotations

import argparse
import csv
import fnmatch
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
PY = sys.executable
PS = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File"]
LIBRARIES = {
    "normal": REPO / "build" / "native-eiffel" / "xpact.dll",
    "assertions": REPO / "build" / "native-eiffel" / "xpact_assertions.dll",
    "bridge-only": REPO / "build" / "native" / "xpact.dll",
    "expat-2.8.1": REPO.parent / "xpactGit" / "build" / "libexpat-R_2_8_1" / "build" / "libexpat.dll",
}
EXPAT_SOURCE = REPO.parent / "xpactGit" / "build" / "libexpat-R_2_8_1" / "libexpat-R_2_8_1" / "expat"
CSHARP = REPO / "build" / "dotnet" / "XpactDllTests" / "bin" / "Release" / "net10.0" / "XpactDllTests.exe"
SMALL_XML = REPO / "build" / "validation-corpora" / "w3c-xml-20130923" / "xmlconf" / "xmltest" / "valid" / "sa" / "001.xml"
OUT = REPO / "build" / "a04"


def ps(script, *args):
    return PS + [str(REPO / "scripts" / script), *map(str, args)]


# id, what is run, configuration, expected libraries, command
RUNNERS = [
    ("dll-build-production", "DLL build + C DLL smoke test (`build_native_eiffel.ps1`)", "Production tier",
     {"normal"}, ps("build_native_eiffel.ps1", "-BuildTier", "Production")),
    ("dll-build-assertions", "DLL build + C DLL smoke test (`build_native_eiffel.ps1`)", "Assertions tier",
     {"assertions"}, ps("build_native_eiffel.ps1", "-BuildTier", "Assertions")),
    ("csharp-normal", "C# P/Invoke DLL tests (`XpactDllTests.exe`)", "`--dll build\\native-eiffel\\xpact.dll`",
     {"normal"}, [str(CSHARP), "--dll", str(LIBRARIES["normal"]), "--out", str(OUT / "csharp-normal")]),
    ("csharp-default", "C# P/Invoke DLL tests (`XpactDllTests.exe`)", "no `--dll` (default)",
     {"assertions"}, [str(CSHARP), "--out", str(OUT / "csharp-default")]),
    ("abi-windows", "Native ABI smoke tests (`run_native_abi_tests.ps1`)", "`-Target Windows`",
     {"bridge-only"}, ps("run_native_abi_tests.ps1", "-Target", "Windows", "-OutputDir", "build\\a04\\abi")),
    ("chunked-crc", "Chunked CRC harness (`run_chunked_crc_harness.ps1`)", "`-Target Xpact -Repeat 1`",
     {"normal"}, ps("run_chunked_crc_harness.ps1", "-Target", "Xpact", "-Repeat", "1", "-OutputDir", "build\\a04\\crc")),
    ("shim-audit", "Incremental shim audit (`run_incremental_shim_audit.ps1`)", "default",
     {"normal"}, ps("run_incremental_shim_audit.ps1", "-OutputDir", "build\\a04\\shim")),
    ("libexpat-adapter-jenkins", "Expat's C tests against xpact (`run_libexpat_adapter.ps1 -Mode NativeSuite`)",
     "`-XpactLibrary build\\native-eiffel\\xpact.lib`, as Jenkins",
     {"normal"}, ps("run_libexpat_adapter.ps1", "-Mode", "NativeSuite", "-ExpatSourceDir", EXPAT_SOURCE,
                    "-OutputDir", "build\\a04\\adapter-jenkins", "-XpactLibrary", "build\\native-eiffel\\xpact.lib",
                    "-SkipNativeBuild")),
    ("libexpat-adapter-default", "Expat's C tests against xpact (`run_libexpat_adapter.ps1 -Mode NativeSuite`)",
     "no `-XpactLibrary` (default), after the ABI tests",
     {"normal"}, ps("run_libexpat_adapter.ps1", "-Mode", "NativeSuite", "-ExpatSourceDir", EXPAT_SOURCE,
                    "-OutputDir", "build\\a04\\adapter-default", "-SkipNativeBuild")),
    ("jenkins-benchmarks", "Jenkins Benchmarks stage (`run_benchmarks.ps1 -W3cAllCases`)",
     "default `-EiffelBuild` (Finalized, FinalizedAssertions, as Jenkins) `-SkipBuild -SkipWslC`, 1 iteration, "
     "2 repetitions (1 fails, see the README)",
     {"normal", "assertions"}, ps("run_benchmarks.ps1", "-Iterations", "1", "-Repetitions", "2", "-SkipBuild",
                                  "-SkipWslC", "-W3cAllCases",
                                  "-OutputDir", "build\\a04\\benchmarks")),
    ("large-xml", "Large XML benchmarks (`run_large_xml_benchmarks.ps1`)", "one small file, `-SkipBuild -SkipWslC`",
     {"normal"}, ps("run_large_xml_benchmarks.ps1", "-XmlFile", SMALL_XML, "-Iterations", "1", "-Repetitions", "1",
                    "-SkipBuild", "-SkipWslC", "-NoPublishDocs", "-OutputDir", "build\\a04\\large")),
    ("contributed-examples", "Contributed examples (`run_contributed_examples.ps1`)", "default",
     set(), ps("run_contributed_examples.ps1", "-OutputDir", "build\\a04\\examples")),
    ("package", "Windows release package (`package_windows_release.ps1`)", "`-SkipBuild`",
     set(), ps("package_windows_release.ps1", "-SkipBuild", "-OutputDir", "build\\a04\\dist")),
    ("python-suite", "Python test suite (`unittest discover tests/python`)", "default",
     None, [PY, "-m", "unittest", "discover", "-s", "tests/python", "-p", "test_*.py"]),
    ("eiffel-matrix", "Eiffel test matrix (`run_eiffel_test_matrix.ps1`)", "all build modes, assertions off and on",
     set(), ps("run_eiffel_test_matrix.ps1")),
    ("student-test1", "Student tool: W3C output test (`reports/issue-0154/tools/run.py`)", "default `--dll`",
     {"normal"}, [PY, "-I", str(REPO / "reports" / "issue-0154" / "tools" / "run.py"), "--out", str(OUT / "test1")]),
]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


def evaluate(watch, expected):
    known = {sha(p): name for name, p in LIBRARIES.items() if sha(p)}
    loads = []  # (process image, dll path, class, sha)
    for proc in watch["processes"]:
        for dll in proc["dlls"]:
            base = Path(dll).name.lower()
            # native library names only: XpactDllTests.dll is the C# program's own managed assembly
            if base in ("xpact.dll", "xpact_assertions.dll") or fnmatch.fnmatch(base, "libexpat*.dll"):
                digest = watch["files"].get(dll, {}).get("sha256")
                loads.append((proc["image"], dll, known.get(digest, "unknown"), digest))
    observed = {c for _, _, c, _ in loads}
    if expected is None:  # no single expectation: only known builds are allowed
        verdict = "ok" if "unknown" not in observed and "bridge-only" not in observed else "MISMATCH"
    else:
        verdict = "ok" if observed == expected else "MISMATCH"
    return verdict, observed, loads


def short(path):
    p = Path(path or "?")
    return str(p.relative_to(REPO)) if p.is_relative_to(REPO) else str(p)


def load_line(image, dll, kind, digest):
    return f"{Path(image or '?').name} -> {short(dll)} [{kind}, {(digest or '')[:16]}]"


def keep_evidence(rid, command, watch, loads, raw, run_dir):
    """The committed evidence: which process loaded which library, how often; the console log."""
    counts = {}
    for img, d, c, s in loads:
        counts[load_line(img, d, c, s)] = counts.get(load_line(img, d, c, s), 0) + 1
    images = {}
    for proc in watch["processes"]:
        info = watch["files"].get(proc["image"], {})
        key = f"{short(proc['image'])}" + (f" [{info['sha256'][:16]}]" if "sha256" in info else "")
        images[key] = images.get(key, 0) + 1
    lines = [f"# A04 {rid}: {' '.join(command)}",
             f"# {len(watch['processes'])} processes, {watch['seconds']} s, exit {watch['exit_code']}, "
             f"timed out: {watch['timed_out']}", "", "## xpact / Expat libraries loaded (process -> file [build, sha256])"]
    lines += [f"{n:6} x {k}" for k, n in sorted(counts.items())] or ["     none"]
    lines += ["", "## processes started (image [sha256 when under the repository])"]
    lines += [f"{n:6} x {k}" for k, n in sorted(images.items(), key=lambda kv: -kv[1])]
    (run_dir / "loads.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    console = (raw / "console.txt").read_bytes()
    if len(console) <= 300_000:
        (run_dir / "console.txt").write_bytes(console)
    else:
        tail = console[-60_000:].decode("utf-8", "replace")
        (run_dir / "console-tail.txt").write_text(
            f"# last 60 KB of {len(console):,} bytes; full log: build\\a04\\{rid}\\console.txt (not in git)\n" + tail,
            encoding="utf-8")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args()
    if args.list:
        for r in RUNNERS:
            print(r[0], "-", r[1], "-", r[2])
        return 0
    env = dict(os.environ)
    env["PATH"] = (r"C:\Program Files (x86)\Microsoft Visual Studio\Installer;"
                   r"C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;"
                   + env["PATH"])
    env["VSCMD_SKIP_SENDTELEMETRY"] = "1"  # else vctip.exe stays ~15 min and the watch waits for it
    results_file = HERE / "results.json"
    results = json.loads(results_file.read_text(encoding="utf-8")) if results_file.is_file() else {}
    for rid, what, config, expected, command in RUNNERS:
        if args.only and rid not in args.only:
            continue
        raw, run_dir = OUT / rid, HERE / "runs" / rid
        raw.mkdir(parents=True, exist_ok=True)
        run_dir.mkdir(parents=True, exist_ok=True)
        print(f"== {rid}: {' '.join(command)}", flush=True)
        with (raw / "console.txt").open("w", encoding="utf-8", errors="replace") as log:
            done = subprocess.run([PY, "-I", str(HERE / "loadwatch.py"), "--out", str(raw / "watch.json"),
                                   "--timeout", "5400", "--", *command],
                                  cwd=REPO, env=env, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT)
        watch = json.loads((raw / "watch.json").read_text(encoding="utf-8"))
        verdict, observed, loads = evaluate(watch, expected)
        keep_evidence(rid, command, watch, loads, raw, run_dir)
        results[rid] = {
            "what": what, "configuration": config,
            "expected": ["any known build"] if expected is None else sorted(expected) or ["no xpact DLL"],
            "observed": sorted(observed) or ["no xpact DLL"], "verdict": verdict, "exit_code": done.returncode,
            "timed_out": watch["timed_out"], "seconds": watch["seconds"], "processes": len(watch["processes"]),
            "library_hashes": {name: (sha(p) or "")[:16] for name, p in LIBRARIES.items()},
            "loads": sorted({load_line(img, d, c, s) for img, d, c, s in loads}),
        }
        print(f"   {verdict}: expected {results[rid]['expected']}, observed {results[rid]['observed']}, "
              f"exit {done.returncode}, {watch['seconds']} s, {len(watch['processes'])} processes", flush=True)
        results_file.write_text(json.dumps(results, indent=1), encoding="utf-8")
    order = [r[0] for r in RUNNERS]
    with (HERE / "results.tsv").open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["id", "runner", "configuration", "expected", "observed", "verdict", "exit_code", "seconds",
                    "processes"])
        for rid in sorted(results, key=lambda k: order.index(k) if k in order else 99):
            r = results[rid]
            w.writerow([rid, r["what"], r["configuration"], " + ".join(r["expected"]), " + ".join(r["observed"]),
                        r["verdict"], r["exit_code"], r["seconds"], r["processes"]])
    return 0


if __name__ == "__main__":
    sys.exit(main())
