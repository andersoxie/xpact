# #332 · SonarQube issue 8: `benchmarks/`, `examples/`, `website/scripts` code smells

| | |
|---|---|
| Status | ✅ fixed (2 contributed files excluded, see below); rescan in [sonarqube-2026-11-12](../sonarqube-2026-11-12/README.md) |
| Issue | [#332](https://github.com/andersoxie/xpact/issues/332) |

| Rule | Where | Fix |
|---|---|---|
| S7498 `dict(...)` call | `benchmarks/fair_speed/run_matrix.py` (3×) | dict literals, same keys and values |
| S7500 needless comprehension | `benchmarks/fair_speed/summarize.py:35` | `list(ratios.values())` |
| S1192 repeated literal | `website/scripts/export-data.py` (`"README.md"` 5×, `"summary.json"` 4×) | constants `README_MD`, `SUMMARY_JSON` |
| S2208 wildcard import | `examples/contributed/xpact-incremental-{example,library}/project.py` | **not changed**: contributed Eiffel-Loop build config; `from eiffel_loop.eiffel.dev_environ import *` is how that tool hands over `os` and its settings, and it cannot be run here to test a change. Excluded in `sonar-project.properties` (workaround, not a fix) |

The complexity of `run_matrix.py` / `summarize.py` `main` (S3776) is handled in [#331](../issue-0331/report.md).

## Verification (uv CPython 3.15)

| Command | Result |
|---|---|
| `python website/scripts/export-data.py` | ✅ exit 0; `git diff website/data` empty: output identical to the committed data |
| `summarize.py student/results/fair-speed-2026-11-10/results.tsv <out>` with the old (`HEAD`) and the new script | ✅ byte-identical `summary.md` (median ratio 18.16, 200 cells) |
| `python -m py_compile benchmarks/fair_speed/run_matrix.py` | ✅; not run end to end (needs both DLLs and minutes per cell); the change only swaps `dict(k=v)` for `{"k": v}` |
