# #330 · SonarQube issue 6: `scripts/` Python code smells

| | |
|---|---|
| Status | ✅ fixed (no behaviour change); rescan in [sonarqube-2026-11-12](../sonarqube-2026-11-12/README.md) |
| Issue | [#330](https://github.com/andersoxie/xpact/issues/330) |
| Files | 10 files in `scripts/`, `tests/python/test_wsl_benchmarks.py` |

| Rule | Count | Fix |
|---|---|---|
| S1192 repeated literal | 21 | module constants (`RUN_JSON`, `REPORT_JSON`, `SUMMARY_MD`, `TABLE_END`, `CHART_DIV`, `DEFAULT_RECOMMENDATION`, `EIFFEL_LOG`, `C_LOG`); expected event lists in `run_dual_regression.py` built with `start_event("r")` / `end_event("r")` (40 literals) |
| S3358 nested conditional | 4 | one helper `dual_jenkins_reports.overall_status(statuses)` used by `dual_jenkins_reports`, `jenkins_plot_report`, `run_dual_jenkins`; `jenkins_xpact_summary` uses `if/elif` |
| S5869 regex class "duplicates" | 2 | the XML-character filter in `run_w3c_conformance.xml_text` and `jenkins_xpact_summary._text` is now an explicit code-point check (`is_xml_char`) |
| S5713 redundant exception | 2 | `SummaryError` is a `ValueError`: removed from the `except` tuples |
| S7519, S1481, S6035, S5890 | 4 | `dict.fromkeys`, unused `err` → `_`, `-(?:c\|o)` → `-[co]`, `Optional[dict]` |
| S1172 unused parameter | 1 | `run_wsl_benchmarks.check_prerequisites(repo_root, …)`: `repo_root` removed (caller and 2 test calls updated) |
| S5886 (SonarQube for IDE, follow-up to #326) | 1 | `lane_variant` returns `cast(Case, replace(…))` |

- **Cause:** ✅ confirmed by reading the code. Complexity (S3776) is [#331](../issue-0331/report.md).

## Verification (uv CPython 3.15)

| Command | Result |
|---|---|
| `python -m unittest discover -s tests/python` | ✅ Ran 239, OK (same count as the baseline before #325-#332) |
| new XML-character check vs the old regex, every code point 0…0x10FFFF, both files | ✅ 0 differences |
| Eiffel tests and Jenkinsfiles that read these scripts' text | ✅ none depend on the changed strings; Jenkins stashes `jenkins_plot_report.py` with `dual_jenkins_reports.py`, which now holds `overall_status` |
