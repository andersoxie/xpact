# Week 9 - Analyse and draft

> **10-16 November 2026, state on 2026-11-14** · work branch `incremental-test` of andersoxie/xpact; `main` is behind `incremental-test` since PR #354/#355 (not touched).
> Week goal (guide): analyse the results and draft the report. Hand-in: 27 November.
> 10-11 November (DLL blockers, website review findings, fair speed test) are in [week 8](week-08.md) under "2026-11-10" and "Next".

## Tried
- [x] **Website, 11 Nov evening:** proxy settings checked and an untrusted proxy logged (#312, PR #313); pages show the fair speed result and current limits (PR #314); Docker image `website-2026-11-11-1` (PR #315, #317).
- [x] **Scripts that did things silently** (all 53 checked): `fix.ps1` squash-merged into the deleted `student-Mass` → merge commits into `incremental-test`, refuses `main` ([#318](https://github.com/andersoxie/xpact/issues/318), PR #321); eight runners rebuilt the tested DLL without saying so → SHA-256 before/after and `XPACT_FROZEN_DLL=1` ([#319](https://github.com/andersoxie/xpact/issues/319), PR #322); text files outside `docs/` brought up to date ([#320](https://github.com/andersoxie/xpact/issues/320), PR #323). CLAUDE.md: no more squash merges (PR #324).
- [x] **SonarQube** ([#131](https://github.com/andersoxie/xpact/issues/131) closed: the student's own token works). 196 issues → **0** in eight PRs (SonarQube issue 1-8 = [#325](https://github.com/andersoxie/xpact/issues/325)-[#332](https://github.com/andersoxie/xpact/issues/332), PRs #333-#340), duplicated code 14 % → 0 %; SHA-1 hotspot resolved ([#342](https://github.com/andersoxie/xpact/issues/342), PR #343). [Summary](../../../reports/sonarqube-2026-11-12/README.md).
- [x] **`main` synced twice:** PR #344 (merge commit), then PR #350 and a fast-forward, so `main` = `incremental-test` (student's explicit request; CLAUDE.md overridden for these two steps only).
- [x] **Website build `website-2026-11-12-1`** with the accessibility and React fixes: release + Docker image `latest` ([#345](https://github.com/andersoxie/xpact/issues/345), PR #348).
- [x] **Hand-in report** updated to 2026-11-12 with recounted numbers ([#346](https://github.com/andersoxie/xpact/issues/346), PR #347, #349).
- [x] ✅ **[#316](https://github.com/andersoxie/xpact/issues/316) fixed** (PR #355): under `cdb` the 3 crashes were all inside .NET (finalizer thread twice, main thread once) when it loaded a type at the cap; only 20-63 KB of stack used. Worker: warm-up, 4 MB reserve, tiered JIT off. [Report](../../../reports/issue-0316/report.md).
- [x] ✅ **10 MB upload** ([#352](https://github.com/andersoxie/xpact/issues/352), [#353](https://github.com/andersoxie/xpact/issues/353), PR #354): the page froze (editor drew 2 rows per line); now a read-only 256 KB preview; a timeout explains the assertions build / small pieces. [Report](../../../reports/issue-0352/report.md).
- [x] #262 and #130 closed (Jenkins dropped). Full to-do list with time estimates: [TOOODOOO.txt](../../../TOOODOOO.txt).

- [x] ✅ **Hosting safety and full scan, 14 Nov** ([report](../../../reports/security-scan-2026-11-14/README.md)):
  - WAF test (OWASP CRS 4.25, stands in for Cloudflare/Azure): it **blocks every pasted XML** and does not stop XML attacks → documented: exclude `/api/validate` if a WAF is used.
  - Antivirus (Defender, ClamAV; stands in for OPSWAT): uploads are never scanned; scanners miss EICAR wrapped in XML. Low risk: XML only, never stored or run.
  - [#368](https://github.com/andersoxie/xpact/issues/368) image was older than the security fixes and `AllowedHosts` was missing from the Docker docs → docker.md "Hosting on the internet safely" (PR #372), releases `website-2026-11-14-1` and **`-2`**, image `ghcr.io/andersoxie/xpact-website:website-2026-11-14-2` = `latest` (PR #379).
  - [#370](https://github.com/andersoxie/xpact/issues/370) 13 of 48 backend tests crashed under code coverage: instrumented `Xpact.Contracts.dll` in the low-integrity worker → `coverage.runsettings` (PR #374).
  - [#371](https://github.com/andersoxie/xpact/issues/371) SonarQube had **never analysed C#**: first .NET scan 76 issues → **0** (PRs #375-#378: worker, Program.cs split, `LibraryImport`, log guard).
  - [#369](https://github.com/andersoxie/xpact/issues/369) CodeQL (security-extended) on every PR + Dependabot weekly (PR #373). Snyk account (CodTanium) set up.
  - [#380](https://github.com/andersoxie/xpact/issues/380) 7 SonarQube hotspots need a project admin (student gets 403).

## What the evidence shows
**Observed, not expected:**

| Check | Observed |
|---|---|
| Python suite | **239 / 239 OK** (before and after the SonarQube refactoring) |
| Website `test.ps1` | **42 / 42** backend tests, frontend build OK; Home and Validator checked in headless Chromium |
| Untested script functions (#331) | old vs new under mocks: identical outputs, call order and exit codes |
| SonarQube rescan | **0 issues**, 0 bugs, 0 vulnerabilities, 0 % duplication, 2 hotspots to review; gate fails only on coverage |
| Docker image `website-2026-11-12-1` | built and tested twice on GitHub (container smoke test, memory cap) |
| #316 before | stack overflow / access violation in 35 of 40 runs below 30 MB; code 1 from 30 MB |
| #316 after (PR #355) | **0 crashes in 50 runs**: below 30 MB `error` (caught out-of-memory), from 30 MB code 1; 10 MiB document +0.17 s total (PC not idle) |
| 10 MB upload (PR #354) | headless Edge: old page frozen (click timed out after 30 s); new loads in 0.75 s, accepted in 4.4 s; invalid 10 MB rejected at line 196,080 |
| Website `test.ps1` after both fixes | **42 / 42** |
| Parser source | unchanged since the 2026-11-08 rerun |
| Website final build `e0c3eab` (14 Nov) | backend **48 / 48** with coverage (C# 93 %), frontend build OK, attack battery **27 / 27** |
| bsharp SonarQube with C# (14 Nov) | **0 issues**, 0 bugs, 0 vulnerabilities, A/A/A; 7 hotspots unreadable (403) |
| Other scanners (14 Nov) | ZAP: only "HTTP only" (local test has no HTTPS); nuclei 0; Semgrep 0; CodeQL 0; Snyk/npm/NuGet/Trivy 0; gitleaks 58 = file checksums |
| WAF (CRS 4.25) | pasted XML 14/14 blocked (403); file upload XXE passes the WAF (the parser still refuses it) |
| Host filter | `Host: xpact.example.com` → 400; with `AllowedHosts` → 200 |

## Blocked
- Website deployment ([#210](https://github.com/andersoxie/xpact/issues/210)): image and checklist are ready (docker.md "Hosting on the internet safely"); the server, domain, HTTPS and `AllowedHosts` are the supervisor's.
- 7 SonarQube hotspots ([#380](https://github.com/andersoxie/xpact/issues/380)): need someone with review rights; the student's token cannot list them. Dependabot alerts and secret scanning: repo admin only.
- Design questions for the supervisor: #304 parallel parsing, #293 entity depth, #211 speed of the billion-laughs stop, #171, #13, the 10 MB limit.
- ~~`gh release create` is blocked for Claude~~: worked on 14 Nov.

## Next week
- [ ] ✏️ Reflection sections of the report in the student's own words; prepare the demonstration.
- [ ] Ask the supervisor the open questions in one message.
- [ ] [#272](https://github.com/andersoxie/xpact/issues/272) ISO-8859-1 in pieces (the last known speed problem).
- [ ] SonarQube: supervisor reviews the 7 hotspots (#380); send a Python coverage report for the gate.
- [x] ✅ Website releases with #316, #352/#353, #357-#360 and #371: `website-2026-11-14-2` (14 Nov).
- [ ] Send the supervisor the hosting package ([to-supervisor-2026-11-14.md](../to-supervisor-2026-11-14.md)).
- [ ] Open issues on andersoxie (13 on 2026-11-13): #342, #304, #293, #272, #211, #210, #197, #176, #171, #170, #126, #123, #13.
