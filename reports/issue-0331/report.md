# #331 · SonarQube issue 7: 32 functions too complex (S3776)

| | |
|---|---|
| Status | ✅ fixed; SonarQube rescan 2026-11-12 01:54: **0 open issues** ([summary](../sonarqube-2026-11-12/README.md)) |
| Issue | [#331](https://github.com/andersoxie/xpact/issues/331) |
| Files | 13 Python files: 10 in `scripts/`, `benchmarks/fair_speed/run_matrix.py`, `summarize.py`, `tools/compiler_assertions/run_probe.py` |

- **Problem:** 32 functions above SonarQube's cognitive-complexity limit of 15 (worst: 64), 447 points over in total.
- **Cause:** ✅ confirmed: long functions that validate, run and report in one body.
- **Fix:** each function split into named helpers (one validation, one row, one table, one lane, one engine). Error messages, the order of checks, the order of process calls, file contents and column orders are kept; nothing else changed.
- Also fixed while there (reported by SonarQube for IDE, not by the server scan): two `\s*=\s*(.*)` regexes that can backtrack (S8786) in `build_implementations.makefile_settings` and `run_wsl_benchmarks.record_eiffel_build`, now `\s*=(.*)` + `lstrip()`.

| Function (before) | Score | Function (before) | Score |
|---|---:|---|---:|
| `run_matrix.main` | 64 | `jenkins_plot_report.capture` | 63 |
| `run_dual_regression.run_lane` | 57 | `run_w3c_conformance.main` | 52 |
| `summarize.main` | 47 | `run_dual_w3c.run_lane` | 41 |
| `jenkins_plot_report.render` | 40 | `compare_eiffel_benchmarks.run_comparison` | 34 |
| `run_dual_w3c.comparison_rows` | 32 | `build_implementations.build_one` | 31 |
| `run_probe.investigate` | 30 | `jenkins_xpact_summary._control_suites` | 29 |
| … 20 more between 16 and 28 | | | |

## Verification

| Check | How | Result |
|---|---|---|
| Complexity | `cognitive_complexity` 1.3.0 (SonarSource metric, PyPI) over all 20 Python files in the scan | ✅ 0 functions over 15 |
| Python suite | `python -m unittest discover -s tests/python` (uv CPython 3.15) | ✅ Ran 239, OK |
| `run_dual_regression.run_lane` (no unit test) | old (`HEAD`) vs new under the same mocked builds/traces: 3 build cases × 2 lifecycle cases | ✅ all 69/68 output files identical, same exit codes (1, 1, 2) |
| `run_matrix.main` (no unit test) | old vs new with a fake runner (fast, slow, crash, timeout, measured-round crash); full run, `--only`, resume | ✅ TSV, stdout and the exact process-call sequence identical |
| `summarize.main` | old vs new on `student/results/fair-speed-2026-11-10/results.tsv` and a copy with timeouts and checksum mismatches | ✅ byte-identical |
| `run_probe.investigate` (Linux only) | old vs new with mocked compilers and probe runs, also a compiler that ignores the request | ✅ report, stdout, commands, generated ECF identical |
| regex change | `\s` vs `str.isspace` over all code points; old vs new on 200,000 random lines | ✅ 0 differences |
| SonarQube | rescan of this branch, `api/issues/search` | ✅ 0 open issues |

Not run: the real Jenkins, WSL and Eiffel compiler lanes (no Jenkins; WSL compilers not installed here). The checks above replace them with the unit tests and old-vs-new comparisons.
