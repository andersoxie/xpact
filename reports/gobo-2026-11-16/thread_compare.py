"""Thread scaling of the same parser test built different ways (alternating runs, median of --repeat).

    python -I reports/gobo-2026-11-16/thread_compare.py NAME=EXE[|ENV=VAL,...] ... [--total 16000] [--repeat 3]

Example column with GC tuning: "Gobo-msc-tuned=C:\\...\\mt_parse_test_gobo.exe|GC_FREE_SPACE_DIVISOR=1,GC_MARKERS=8".
A run counts only if it exits 0 and prints the --ok text (default "bad 0"; "wrong 0" for reports/issue-0274/threads.c);
'!' marks a failed run.
"""
import argparse
import os
import statistics
import subprocess
import sys
import time


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("columns", nargs="+")
    ap.add_argument("--total", type=int, default=16000)
    ap.add_argument("--repeat", type=int, default=3)
    ap.add_argument("--threads", default="1,2,4,8,16")
    ap.add_argument("--ok", default="bad 0")
    a = ap.parse_args()
    cols = []
    for c in a.columns:
        name, rest = c.split("=", 1)
        exe, _, envs = rest.partition("|")
        env = dict(os.environ)
        for kv in filter(None, envs.split(",")):
            k, v = kv.split("=", 1)
            env[k] = v
        cols.append((name, exe, env))
        subprocess.run([exe, "1", "10"], capture_output=True, env=env)  # warm-up
    print("threads " + "".join(f"{n:>18}" for n, _, _ in cols) + f"   ({a.total:,} parses, median of {a.repeat})")
    for n in map(int, a.threads.split(",")):
        times = {name: [] for name, _, _ in cols}
        bad = {name: 0 for name, _, _ in cols}
        for _ in range(a.repeat):
            for name, exe, env in cols:
                start = time.perf_counter()
                p = subprocess.run([exe, str(n), str(a.total // n)], capture_output=True, text=True, env=env)
                d = time.perf_counter() - start
                if p.returncode or a.ok not in p.stdout:
                    bad[name] += 1
                else:
                    times[name].append(d)
        cells = [f"{(statistics.median(times[c]) if times[c] else float('nan')):>15.2f} s{'!' * bad[c]:<1}" for c, _, _ in cols]
        print(f"{n:>7} " + "".join(cells), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
