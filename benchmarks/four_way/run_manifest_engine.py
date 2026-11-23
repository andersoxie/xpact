"""Run one conformance engine on the exact case list of a dual-W3C run (four-way comparison).

Uses the same protocol and judging rule as scripts/run_w3c_conformance.py:
  <engine...> --conformance-file CASE --suite-root ROOT [--namespaces]
  exactly one line `XPACT_CONFORMANCE\t<ACCEPT|REJECT>` and exit 0 (ACCEPT) / 1 (REJECT), else an error.
Cases with a skip_reason in the manifest are excluded, exactly as in the dual run.

  python run_manifest_engine.py --manifest suite-manifest.json --suite-root SUITE/xmlconf \
      --name expat --out results.tsv --jobs 8 -- ENGINE [ARGS...]
"""
import argparse, json, subprocess, sys, time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path


def run_case(case, engine, root, timeout):
    if case["skip_reason"]:
        return dict(status="excluded", actual="", exit="", note=case["skip_reason"])
    path = root / case["path"].replace("\\", "/")
    cmd = engine + ["--conformance-file", str(path), "--suite-root", str(root)] + (["--namespaces"] if case["namespaces"] else [])
    try:
        done = subprocess.run(cmd, capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return dict(status="error", actual="", exit="", note="timeout")
    lines = [l for l in done.stdout.decode("utf-8", "replace").splitlines() if l.startswith("XPACT_CONFORMANCE\t")]
    actual = ""
    if lines == ["XPACT_CONFORMANCE\tACCEPT"] and done.returncode == 0: actual = "ACCEPT"
    elif lines == ["XPACT_CONFORMANCE\tREJECT"] and done.returncode == 1: actual = "REJECT"
    if not actual:
        err = done.stderr.decode("utf-8", "replace").strip().splitlines()
        return dict(status="error", actual="", exit=done.returncode, note=(err[-1] if err else "protocol")[:200])
    return dict(status="passed" if actual == case["expected"] else "failed", actual=actual, exit=done.returncode, note="")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--manifest", type=Path, required=True); p.add_argument("--suite-root", type=Path, required=True)
    p.add_argument("--name", required=True); p.add_argument("--out", type=Path, required=True)
    p.add_argument("--jobs", type=int, default=8); p.add_argument("--timeout", type=float, default=10)
    p.add_argument("engine", nargs=argparse.REMAINDER)
    a = p.parse_args()
    engine = [x for x in a.engine if x != "--"]
    cases = json.loads(a.manifest.read_text(encoding="utf-8"))["cases"]
    t0 = time.time()
    with ThreadPoolExecutor(a.jobs) as pool:
        results = list(pool.map(lambda c: run_case(c, engine, a.suite_root, a.timeout), cases))
    a.out.parent.mkdir(parents=True, exist_ok=True)
    with a.out.open("w", encoding="utf-8", newline="\n") as f:
        f.write("case_id\tkind\tnamespaces\texpected\t%s_status\t%s_actual\t%s_exit\t%s_note\n" % ((a.name,) * 4))
        for c, r in zip(cases, results):
            f.write(f'{c["case_id"]}\t{c["kind"]}\t{c["namespaces"]}\t{c["expected"]}\t{r["status"]}\t{r["actual"]}\t{r["exit"]}\t{r["note"]}\n')
    counts = {k: sum(r["status"] == k for r in results) for k in ("passed", "failed", "error", "excluded")}
    summary = dict(engine=a.name, command=engine, cases=len(cases), seconds=round(time.time() - t0, 1), **counts)
    a.out.with_suffix(".json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary))
    return 0


if __name__ == "__main__":
    sys.exit(main())