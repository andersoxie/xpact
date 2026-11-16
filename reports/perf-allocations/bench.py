"""Compare probe builds: alternate runs, median of --repeat, per input. Idle PC please.

    python -I reports/perf-allocations/bench.py bin/baseline.exe bin/step1.exe [--rounds 20] [--repeat 3]

Each probe prints "wall N ms"; the table shows the median per input and the speed-up of each build vs the first.
"""
import argparse
import re
import statistics
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
INPUTS = HERE.parents[1] / "build" / "perf-inputs"
NAMES = ["elements-1MB-utf8.xml", "attributes-1MB-utf8.xml", "text-1MB-utf8.xml", "dtd-1MB-utf8.xml",
         "namespaces-1MB-utf8.xml"]


def wall_ms(exe, path, rounds):
    out = subprocess.run([str(exe), str(path), str(rounds)], capture_output=True, text=True, check=True).stdout
    m = re.search(r"ok (\d+) \| wall (\d+) ms", out)
    if not m or int(m.group(1)) != rounds:
        raise RuntimeError(f"{exe.name} on {path.name}: {out.strip()}")
    return int(m.group(2))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("exes", nargs="+")
    ap.add_argument("--rounds", type=int, default=20)
    ap.add_argument("--repeat", type=int, default=3)
    args = ap.parse_args()
    exes = [Path(e) if Path(e).is_absolute() else HERE / e for e in args.exes]
    for e in exes:  # warm-up: first start of a fresh exe is slow
        wall_ms(e, INPUTS / NAMES[2], 1)
    print(f"{'input':26}" + "".join(f"{e.stem:>14}" for e in exes) + "   speed-up")
    for name in NAMES:
        times = {e: [] for e in exes}
        for _ in range(args.repeat):
            for e in exes:  # alternate builds
                times[e].append(wall_ms(e, INPUTS / name, args.rounds))
        med = [statistics.median(times[e]) for e in exes]
        speed = "  ".join(f"{med[0] / m:.2f}x" for m in med[1:])
        print(f"{name:26}" + "".join(f"{m:>11.0f} ms" for m in med) + f"   {speed}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
