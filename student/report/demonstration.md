# Demonstration plan (about 20 minutes)

> ✏️ **DRAFT** written by the AI assistant on 2026-11-16. Change the order, the timing and the words to your own before the demonstration.
> Run everything from the repository root in Windows PowerShell, on the commit named in the [short report](ActualReportShorter.md).
> Full command list: [ActualReport.md, Appendix A](ActualReport.md#appendix-a--demonstration-commands).

## Before the demonstration (the day before)

- [ ] `git pull` on `incremental-test`; write down the commit.
- [ ] Build both DLLs once: `.\website\scripts\build-dll.ps1`. Write down both SHA-256 values, then `$env:XPACT_FROZEN_DLL = "1"`.
- [ ] Build the website: `.\website\scripts\publish.ps1` (in its own `powershell` process), then `.\website\scripts\test.ps1` (expect 48/48).
- [ ] Keep the long runs out of the live demo: run W3C (step 3) the day before and show its saved result.
- [ ] Open these tabs: the [short report](ActualReportShorter.md), [PLAN.md](../PLAN.md), the [GitHub issue list](https://github.com/andersoxie/xpact/issues?q=is%3Aissue), the SonarQube dashboard, the [Gobo DLL report](../../reports/gobo-dll/README.md).

## Running order

| # | Time | Show | Command or link | What to say |
|---|---|---|---|---|
| 1 | 2 min | The question and the answer | [short report](ActualReportShorter.md), "At a glance" | "Does xpact handle valid and invalid XML consistently with assertions on? Yes, here is the evidence." |
| 2 | 2 min | The bug that started it: assertions turned 1,360 W3C cases into crashes | report 4.1; the 9-byte CR file | Contracts found a real bug that assertions-off builds hid |
| 3 | 2 min | W3C suite, both builds, 0 failed | saved result from the day before ([latest-2026-10-28](../../reports/latest-2026-10-28/README.md) or a fresh run) | `.\scripts\run_benchmarks.ps1 -Iterations 1 -Repetitions 1 -SkipWslC -W3cAllCases -UseExistingNativeDll -NoDocsUpdate` |
| 4 | 2 min | A failing test really fails (B02) | `$env:XPACT_META_FAIL = "assert"; .\scripts\run_eiffel_test_matrix.ps1; Remove-Item Env:\XPACT_META_FAIL` | Before B01/B02, CI was green on failures |
| 5 | 2 min | xpact next to Expat on one fix | `python -I reports\issue-0172\tools\probe.py <xpact dll> <libexpat dll>` | Same events before an error, 7 of 7 |
| 6 | 3 min | **The website, live** | `website\dist\Xpact.Api.exe --urls http://localhost:5099` → paste valid XML, then broken XML, then a billion-laughs document | Results, error position, the attack is stopped (code 43) |
| 7 | 2 min | Security and quality | [security scan 14 Nov](../../reports/security-scan-2026-11-14/README.md), SonarQube dashboard | 3 rounds, 27/27 attacks stopped, 0 SonarQube issues, gate green |
| 8 | 2 min | Speed: 50 min → 106 ms, and the fair test vs Expat | [fair speed results](../results/fair-speed-2026-11-10/README.md) | Honest number: median 18× slower than Expat |
| 9 | 2 min | Gobo: same results, threads | [Gobo DLL report](../../reports/gobo-dll/README.md) | Identical results; next step is the global lock (#418) |
| 10 | 1 min | How it was done: issue → branch → report → PR | one closed issue, e.g. [#172](https://github.com/andersoxie/xpact/issues/172) and its PR | Every change traceable and revertable |
| 11 | 2 min | What is left, and questions | [handover list](../HANDOVER.md) | The design questions for 1.0 |

## If something goes wrong live

- The website does not start: show the Docker image release `website-2026-11-14-3` and the [container smoke test](../../reports/issue-0345/report.md) instead.
- A probe needs the Expat DLL: its path is in the probe's report; or show the saved output in the report folder.
- Never rebuild during the demonstration (it takes minutes and can change the DLL).
