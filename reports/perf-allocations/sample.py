"""Poor man's sampling profiler for the finalized alloc_probe.exe (Windows, cdb from WinDbg).

    python -I reports/perf-allocations/sample.py <input.xml> [--rounds 400] [--samples 60] [--top 15]

1. Relinks EIFGENs/alloc_probe/F_code/alloc_probe.exe with /DEBUG (function names in a .pdb).
2. Starts the probe on <input.xml> for many rounds and takes --samples stack snapshots of its main thread with
   a non-invasive cdb attach (the process is only paused for a moment).
3. Counts the innermost frame and every frame (inclusive) and maps generated names (F83_1856) to Eiffel features
   ({XP_PARSER}.scan_element) from the comments in F_code.
"""
import argparse
import collections
import os
import re
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
FCODE = HERE / "EIFGENs" / "alloc_probe" / "F_code"
EXE = FCODE / "alloc_probe.exe"
CDB = Path(os.environ.get("LOCALAPPDATA", "")) / "Microsoft" / "WindowsApps" / "cdbX64.exe"
FRAME = re.compile(r"(?:alloc_probe|xpact)!([A-Za-z0-9_]+)\+0x[0-9a-f]+")


def relink_with_debug():
    lnk = next(p for p in FCODE.glob("*.lnk") if not p.name.endswith(".dll.lnk"))
    lines = [l for l in lnk.read_text().splitlines() if l.strip()]
    if not any("-DEBUG" in l for l in lines):
        lines.insert(0, "-DEBUG")
    debug_lnk = FCODE / "probe_debug.lnk"
    debug_lnk.write_text("\n".join(lines) + "\n")
    script = (f". '{REPO}\\scripts\\import_msvc_environment.ps1' | Out-Null; Set-Location '{FCODE}'; "
              f"link '@probe_debug.lnk' | Out-Null; exit $LASTEXITCODE")
    subprocess.run(["powershell", "-NoProfile", "-Command", script], check=True)


def feature_names():
    names = {}
    pattern = re.compile(r"/\* (\{[A-Z_0-9]+\}\.[a-z_0-9]+) \*/\s*\n[^\n]*?\b(F\d+_\d+)\s*\(")
    for c in FCODE.rglob("*.c"):
        for m in pattern.finditer(c.read_text(encoding="latin-1")):
            names[m.group(2)] = m.group(1)
    return names


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("--rounds", type=int, default=400)
    ap.add_argument("--samples", type=int, default=60)
    ap.add_argument("--top", type=int, default=15)
    ap.add_argument("--fcode", help="F_code folder of the DLL's Eiffel target (feature names); with --command")
    ap.add_argument("--symbols", help="folder with the DLL's .pdb; with --command")
    ap.add_argument("--command", nargs=argparse.REMAINDER, help="profile this command line instead of the probe")
    args = ap.parse_args()

    global FCODE
    if args.command:
        FCODE = Path(args.fcode)
        names = feature_names()
        symbols = args.symbols
        proc = subprocess.Popen(args.command, stdout=subprocess.PIPE, text=True)
    else:
        relink_with_debug()
        names = feature_names()
        symbols = str(FCODE)
        proc = subprocess.Popen([str(EXE), args.input, str(args.rounds)], stdout=subprocess.PIPE, text=True)
    time.sleep(1.0)
    inner, inclusive, taken = collections.Counter(), collections.Counter(), 0
    for _ in range(args.samples):
        if proc.poll() is not None:
            break
        out = subprocess.run([str(CDB), "-pv", "-p", str(proc.pid), "-y", symbols, "-c", "~0k 40;q"],
                             capture_output=True, text=True, timeout=60).stdout
        frames = [names.get(f, f) for f in FRAME.findall(out)]
        if frames:
            taken += 1
            inner[frames[0]] += 1
            for f in dict.fromkeys(frames):  # count each routine once per sample
                inclusive[f] += 1
    proc.kill()
    print(f"samples: {taken}")
    print("\nInnermost frame (where the time is spent):")
    for f, n in inner.most_common(args.top):
        print(f"  {100 * n / max(taken, 1):5.1f} %  {f}")
    print("\nInclusive (routine or anything it calls):")
    for f, n in inclusive.most_common(args.top):
        print(f"  {100 * n / max(taken, 1):5.1f} %  {f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
