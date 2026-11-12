# #306 Evidence logs under reports/ were ignored by git

| | |
|---|---|
| Branch | `fix/306-report-logs` from `incremental-test` @ `c99154b` |
| Command | `python -I reports/issue-0306/check_links.py <out.tsv>` (from the repo root): every relative link in tracked `.md` files |

## Problem and cause
`.gitignore` line 13 `*.log` with an exception only for `student/**/*.log`: logs saved under `reports/` never reached the repo. ✅ Confirmed with `git check-ignore -v`.

## Fix
- `!reports/**/*.log` added.
- The 8 linked logs restored from the old local checkout (`C:\xpact\xpact-student-Mass-old-2026-11-10`), unchanged; scanned for secrets (none).

## Result
| | Broken relative links |
|---|---:|
| Before | 53 (8 `.log`) |
| After | **45** (0 `.log`) |

## Still broken (45): not recoverable here, recorded
Most are links written by the C# DLL test tool into a copied `summary.md` (to `compare.py` / `cases.tsv` next to it, which were not copied). The tool's own output folders have these files; the copies in `reports/` keep only the summary.

| File | Link |
|---|---|
| `reports/issue-0146/findings-before-fixes.md` | `local-changes.diff` |
| `reports/issue-0146/findings-before-fixes.md` | `run.ps1` |
| `reports/issue-0146/findings-before-fixes.md` | `w3c/results.tsv` |
| `reports/issue-0146/findings-before-fixes.md` | `w3c-default-mode/summary.md` |
| `reports/issue-0146/logs/compare-xpact-summary.md` | `compare.py` |
| `reports/issue-0146/logs/compare-xpact-summary.md` | `cases.tsv` |
| `reports/issue-0146/logs/compare-xpact_assertions-summary.md` | `compare.py` |
| `reports/issue-0146/logs/compare-xpact_assertions-summary.md` | `cases.tsv` |
| `reports/issue-0148/compare-xpact-summary.md` | `compare.py` |
| `reports/issue-0148/compare-xpact-summary.md` | `cases.tsv` |
| `reports/issue-0148/compare-xpact_assertions-summary.md` | `compare.py` |
| `reports/issue-0148/compare-xpact_assertions-summary.md` | `cases.tsv` |
| `reports/issue-0154/logs/checks/csharp/xpact/summary.md` | `compare.py` |
| `reports/issue-0154/logs/checks/csharp/xpact/summary.md` | `cases.tsv` |
| `reports/issue-0154/logs/checks/csharp/xpact_assertions/summary.md` | `compare.py` |
| `reports/issue-0154/logs/checks/csharp/xpact_assertions/summary.md` | `cases.tsv` |
| `reports/issue-0156/logs/checks/csharp/xpact/summary.md` | `compare.py` |
| `reports/issue-0156/logs/checks/csharp/xpact/summary.md` | `cases.tsv` |
| `reports/issue-0156/logs/checks/csharp/xpact_assertions/summary.md` | `compare.py` |
| `reports/issue-0156/logs/checks/csharp/xpact_assertions/summary.md` | `cases.tsv` |
| `reports/issue-0157/logs/checks/csharp/xpact/summary.md` | `compare.py` |
| `reports/issue-0157/logs/checks/csharp/xpact/summary.md` | `cases.tsv` |
| `reports/issue-0157/logs/checks/csharp/xpact_assertions/summary.md` | `compare.py` |
| `reports/issue-0157/logs/checks/csharp/xpact_assertions/summary.md` | `cases.tsv` |
| `reports/issue-0158/logs/checks/csharp/xpact/summary.md` | `compare.py` |
| `reports/issue-0158/logs/checks/csharp/xpact/summary.md` | `cases.tsv` |
| `reports/issue-0158/logs/checks/csharp/xpact_assertions/summary.md` | `compare.py` |
| `reports/issue-0158/logs/checks/csharp/xpact_assertions/summary.md` | `cases.tsv` |
| `reports/issue-0159/logs/checks/csharp/xpact/summary.md` | `compare.py` |
| `reports/issue-0159/logs/checks/csharp/xpact/summary.md` | `cases.tsv` |
| `reports/issue-0159/logs/checks/csharp/xpact_assertions/summary.md` | `compare.py` |
| `reports/issue-0159/logs/checks/csharp/xpact_assertions/summary.md` | `cases.tsv` |
| `reports/issue-0165/logs/checks/csharp/xpact/summary.md` | `compare.py` |
| `reports/issue-0165/logs/checks/csharp/xpact/summary.md` | `cases.tsv` |
| `reports/issue-0165/logs/checks/csharp/xpact_assertions/summary.md` | `compare.py` |
| `reports/issue-0165/logs/checks/csharp/xpact_assertions/summary.md` | `cases.tsv` |
| `reports/issue-0165/report.md` | `logs/checks/build-assertions.txt` |
| `reports/latest-2026-10-28/logs/compare-xpact-summary.md` | `compare.py` |
| `reports/latest-2026-10-28/logs/compare-xpact-summary.md` | `cases.tsv` |
| `reports/latest-2026-10-28/logs/compare-xpact_assertions-summary.md` | `compare.py` |
| `reports/latest-2026-10-28/logs/compare-xpact_assertions-summary.md` | `cases.tsv` |
| `student/results/AlotOfTests-2026-10-28/03-fuzzing/README.md` | `findings/` |
| `student/results/AlotOfTests-2026-11-08/repo-suites/benchmarks-single-run.md` | `wsl-benchmarks.md` |
| `student/results/shared-fixtures/dlltests-vs-expat/xpact/summary.md` | `compare.py` |
| `student/results/shared-fixtures/dlltests-vs-expat/xpact_assertions/summary.md` | `compare.py` |
