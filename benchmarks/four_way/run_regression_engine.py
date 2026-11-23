"""Run one engine through the dual-regression cases with the official judging rules (four-way comparison).

Reuses scripts/run_dual_regression.py: cases(), chunkings(), trace_case(), judge(), LIFECYCLE.
  python run_regression_engine.py --name gobo --out results.tsv [--lifecycle] -- ENGINE [ARGS...]
"""
import argparse, json, sys, tempfile
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
import run_dual_regression as dr  # noqa: E402


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--name", required=True); p.add_argument("--out", type=Path, required=True)
    p.add_argument("--lifecycle", action="store_true"); p.add_argument("--timeout", type=float, default=30)
    p.add_argument("engine", nargs=argparse.REMAINDER)
    a = p.parse_args()
    engine = [x for x in a.engine if x != "--"]
    exe, extra = engine[0], engine[1:]
    real_run = dr.run_exe
    dr.run_exe = lambda executable, arguments, cwd, timeout: real_run(executable, extra + arguments, cwd, timeout)
    rows = []
    with tempfile.TemporaryDirectory() as work:
        for name, group, data, accepted, expected in dr.cases():
            path = Path(work) / (name.replace("/", "_") + ".xml"); path.write_bytes(data)
            names = dr.chunkings(data)
            traces = dr.trace_case(exe, path, names, work, a.timeout)
            for ch in names:
                verdict, observed, error = traces.get(ch, ("MISSING", "", ""))
                rows.append(dict(case=name, group=group, chunking=ch, result=dr.judge(accepted, expected, verdict, observed), error=error))
        if a.lifecycle:
            code, out, _ = dr.run_exe(exe, ["--lifecycle"], work, a.timeout)
            steps = dr.parse_lines(out, "XPACT_LIFECYCLE")
            for step, accepted, expected in dr.LIFECYCLE:
                verdict, observed, error = steps.get(step, ("MISSING", "", ""))
                rows.append(dict(case=step, group="lifecycle", chunking="reused", result=dr.judge(accepted, expected, verdict, observed), error=error))
    a.out.parent.mkdir(parents=True, exist_ok=True)
    with a.out.open("w", encoding="utf-8", newline="\n") as f:
        f.write("case\tgroup\tchunking\tresult\terror\n")
        for r in rows: f.write("%(case)s\t%(group)s\t%(chunking)s\t%(result)s\t%(error)s\n" % r)
    c = Counter(r["result"] for r in rows)
    summary = dict(engine=a.name, runs=len(rows), **dict(c))
    a.out.with_suffix(".json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary))


if __name__ == "__main__":
    main()