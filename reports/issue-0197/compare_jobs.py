"""#197: does test 2 give the same results with --jobs N as with --jobs 1, and how much faster is it?

    python -I reports/issue-0197/compare_jobs.py --dll <xpact.dll> [--jobs 16] [--rounds 3]

Runs reports/issue-0165/tools/run.py alternately with --jobs 1 and --jobs N (rounds × 2 runs, so
neither setting always runs on a warmer or colder PC), compares every output TSV and summary byte
for byte, and writes timings.tsv and result.md next to this script.
"""
import argparse
import hashlib
import statistics
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
RUN = REPO / "reports" / "issue-0165" / "tools" / "run.py"
LOGS = REPO / "reports" / "issue-0165" / "tools" / "logs"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dll", required=True)
    ap.add_argument("--jobs", type=int, default=16)
    ap.add_argument("--rounds", type=int, default=3)
    args = ap.parse_args()

    dll_sha = sha(Path(args.dll))
    rows, outputs = [], {}
    for rnd in range(1, args.rounds + 1):
        for jobs in (1, args.jobs):
            tag = f"j197-r{rnd}-j{jobs}"
            start = time.perf_counter()
            proc = subprocess.run([sys.executable, "-I", str(RUN), "--dll", args.dll, "--tag", tag, "--jobs", str(jobs)],
                                  capture_output=True, text=True)
            seconds = time.perf_counter() - start
            if proc.returncode:
                print(proc.stdout[-2000:], proc.stderr[-2000:])
                return proc.returncode
            tsv, summary = LOGS / f"chunked-{tag}.tsv", LOGS / f"chunked-{tag}-summary.json"
            outputs[tag] = (sha(tsv), sha(summary), summary.read_text(encoding="utf-8"))
            rows.append((rnd, jobs, round(seconds, 1)))
            print(f"round {rnd} jobs {jobs:>2}: {seconds:7.1f} s", flush=True)
            tsv.unlink()
            summary.unlink()

    hashes = {(t, s) for t, s, _ in outputs.values()}
    same = len(hashes) == 1
    seq = [s for _, j, s in rows if j == 1]
    par = [s for _, j, s in rows if j != 1]
    med_seq, med_par = statistics.median(seq), statistics.median(par)
    summary_text = next(iter(outputs.values()))[2].strip()

    (HERE / "timings.tsv").write_text("round\tjobs\tseconds\n" + "".join(f"{r}\t{j}\t{s}\n" for r, j, s in rows),
                                      encoding="utf-8")
    (HERE / "result.md").write_text(f"""# #197: test 2 with --jobs {args.jobs} vs --jobs 1

- DLL: `{args.dll}` SHA-256 `{dll_sha}`
- Runs: {args.rounds} rounds, alternating --jobs 1 and --jobs {args.jobs} ([timings.tsv](timings.tsv))
- **Same results:** {"✅ yes, every TSV and summary is byte-identical" if same else "❌ NO, outputs differ"} ({len(outputs)} runs, {len(hashes)} distinct output)
- **Median time:** --jobs 1 = {med_seq:.1f} s · --jobs {args.jobs} = {med_par:.1f} s · **{med_seq / med_par:.1f}× faster**
- Summary (all runs):

```json
{summary_text}
```
""", encoding="utf-8")
    print(f"same={same} median jobs1={med_seq:.1f}s jobs{args.jobs}={med_par:.1f}s speedup={med_seq / med_par:.1f}x")
    return 0 if same else 1


if __name__ == "__main__":
    sys.exit(main())
