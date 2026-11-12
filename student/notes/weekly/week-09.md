# Week 9 - Analyse and draft

> **10-16 November 2026, state on 2026-11-12** · work branch `incremental-test` of andersoxie/xpact; `main` = `incremental-test` (0 ahead / 0 behind, 2026-11-12).
> Week goal (guide): analyse the results and draft the report. Hand-in: 27 November.
> 10-11 November (DLL blockers, website review findings, fair speed test) are in [week 8](week-08.md) under "2026-11-10" and "Next".

## Tried
- [x] **Website, 11 Nov evening:** proxy settings checked and an untrusted proxy logged (#312, PR #313); pages show the fair speed result and current limits (PR #314); Docker image `website-2026-11-11-1` (PR #315, #317).
- [x] **Scripts that did things silently** (all 53 checked): `fix.ps1` squash-merged into the deleted `student-Mass` → merge commits into `incremental-test`, refuses `main` ([#318](https://github.com/andersoxie/xpact/issues/318), PR #321); eight runners rebuilt the tested DLL without saying so → SHA-256 before/after and `XPACT_FROZEN_DLL=1` ([#319](https://github.com/andersoxie/xpact/issues/319), PR #322); text files outside `docs/` brought up to date ([#320](https://github.com/andersoxie/xpact/issues/320), PR #323). CLAUDE.md: no more squash merges (PR #324).
- [x] **SonarQube** ([#131](https://github.com/andersoxie/xpact/issues/131) closed: the student's own token works). 196 issues → **0** in eight PRs (SonarQube issue 1-8 = [#325](https://github.com/andersoxie/xpact/issues/325)-[#332](https://github.com/andersoxie/xpact/issues/332), PRs #333-#340), duplicated code 14 % → 0 %; SHA-1 hotspot resolved ([#342](https://github.com/andersoxie/xpact/issues/342), PR #343). [Summary](../../../reports/sonarqube-2026-11-12/README.md).
- [x] **`main` synced twice:** PR #344 (merge commit), then PR #350 and a fast-forward, so `main` = `incremental-test` (student's explicit request; CLAUDE.md overridden for these two steps only).
- [x] **Website build `website-2026-11-12-1`** with the accessibility and React fixes: release + Docker image `latest` ([#345](https://github.com/andersoxie/xpact/issues/345), PR #348).
- [x] **Hand-in report** updated to 2026-11-12 with recounted numbers ([#346](https://github.com/andersoxie/xpact/issues/346), PR #347, #349).
- [x] **[#316](https://github.com/andersoxie/xpact/issues/316) investigated** (not fixed): [report](../../../reports/issue-0316/report.md). WinDbg installed for the next step.

## What the evidence shows
**Observed, not expected:**

| Check | Observed |
|---|---|
| Python suite | **239 / 239 OK** (before and after the SonarQube refactoring) |
| Website `test.ps1` | **42 / 42** backend tests, frontend build OK; Home and Validator checked in headless Chromium |
| Untested script functions (#331) | old vs new under mocks: identical outputs, call order and exit codes |
| SonarQube rescan | **0 issues**, 0 bugs, 0 vulnerabilities, 0 % duplication, 2 hotspots to review; gate fails only on coverage |
| Docker image `website-2026-11-12-1` | built and tested twice on GitHub (container smoke test, memory cap) |
| #316 | a race: the same image gave code 1 in one run and a stack overflow in the other; on the PC a stack overflow at 18-22 MB caps, code 1 from 30 MB; the overflow is in native code |
| Parser source | unchanged since the 2026-11-08 rerun |

## Blocked
- Website deployment ([#210](https://github.com/andersoxie/xpact/issues/210)): HTTPS, domain, `AllowedHosts` (supervisor's server).
- 2 SonarQube hotspots: need someone with review rights to mark them Safe; the student's token cannot list hotspots.
- Design questions for the supervisor: #304 parallel parsing, #293 entity depth, #211 speed of the billion-laughs stop, #171, #13, the 10 MB limit.
- `gh release create` is blocked for Claude: the student runs it.

## Next week
- [ ] ✏️ Reflection sections of the report in the student's own words; prepare the demonstration.
- [ ] Ask the supervisor the open questions in one message.
- [ ] [#272](https://github.com/andersoxie/xpact/issues/272) ISO-8859-1 in pieces (the last known speed problem).
- [ ] SonarQube: mark the 2 hotspots Safe; send a Python coverage report for the gate.
- [ ] [#316](https://github.com/andersoxie/xpact/issues/316) with WinDbg (when picked up again).
- [ ] Open issues on andersoxie (16 on 2026-11-12): #342, #316, #304, #293, #272, #262, #211, #210, #197, #176, #171, #170, #130, #126, #123, #13.
