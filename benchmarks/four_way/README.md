# Four-way parser comparison tools

**What:** one command that builds and runs every test suite on xpact, xpact compiled by Gobo, libexpat and xpact-core, and writes one report folder.
**Where:** this folder; results go to `reports\four-way-<date>\`. Last report: [reports/four-way-2026-11-23/REPORT.md](../../reports/four-way-2026-11-23/REPORT.md) · suite list for reviewers: [TEST-SUITES.md](../../reports/four-way-2026-11-23/TEST-SUITES.md).

```powershell
.\benchmarks\four_way\run_four_way.ps1              # everything, ~25 min
.\benchmarks\four_way\run_four_way.ps1 -SkipLinux   # Windows lanes only
.\benchmarks\four_way\run_four_way.ps1 -SkipLarge -LargeXmlMB 5 -SpeedDocs 16000 -SpeedReps 5
```

| File | What it does |
|---|---|
| `run_four_way.ps1` | the orchestrator: every step logs to `logs\NN-name.log` and its exit code to `logs\00-steps.tsv`; a failing step never stops the run |
| `wsl_four_way.sh` | the Linux half (called through WSL): Gobo `gec` builds, Linux EiffelStudio builds, W3C + regression for Gobo and Linux expat, the four-parser speed race |
| `gobo/*.ecf` | Gobo variants of the W3C, regression and catalog harnesses |
| `expat_conformance_engine.py` | expat (pyexpat) speaking the W3C protocol: `XPACT_CONFORMANCE ACCEPT/REJECT`; reads external entities inside the suite only |
| `expat_trace_engine.py` | expat speaking the regression protocol: one event line per start/text/end, whole or chunked |
| `expat_engine.cmd`, `expat_engine.sh` | launch the expat engine on Windows / Linux |
| `run_manifest_engine.py` | runs any engine on the exact W3C case list of a dual-W3C run, same judging rule |
| `run_regression_engine.py` | runs any engine on the dual regression cases (reuses `scripts/run_dual_regression.py`) |
| `summarize_four_way.py` | merges every engine's W3C verdicts into one table (`w3c-four-way.md/.tsv`) |
| `expat_lenient_cases.py` | groups the not-well-formed cases expat accepts by W3C section |
| `make_large_xml.py` | writes a deterministic catalog XML file of N MB |

Needs: EiffelStudio 25.12 + Visual Studio C++ (Windows), Python 3.11+, .NET 10 SDK; for the Linux half a WSL distro with `/opt/Eiffel_25.12`, `/opt/gobo`, gcc, python3 and `libexpat1-dev`.
