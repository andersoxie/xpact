# SonarQube 2026-11-12: from 196 issues to 0

> **Result:** ✅ 0 open issues · ✅ 0 bugs · ✅ 0 vulnerabilities · ✅ 0 % duplication · 🟡 3 security hotspots to review · 🔴 quality gate fails only on "coverage of new code" (no coverage report is sent yet)
>
> Server: https://sonarqube.bsharp.se/dashboard?id=xpact · project key `xpact` · [#131](https://github.com/andersoxie/xpact/issues/131) (the old HTTP 401) is solved by the student's own token.

## 1. Before and after

| | Scan 1 · 2026-11-12 01:01 | Scan 2 · 2026-11-12 01:54 |
|---|---|---|
| Revision | `incremental-test` @ `7db9612` | branch `fix/331-reduce-complexity` @ `36cbfa3` (= `incremental-test` @ `c7703bd` after merge) |
| Files indexed | 7,928 | 492 |
| Lines of code | 20,597 | 7,219 |
| Open issues | 196 (3 blocker, 104 critical, 56 major, 33 minor; all code smells) | **0** |
| Bugs / vulnerabilities | 0 / 0 | 0 / 0 |
| Duplicated lines | 14 % | **0 %** |
| Security hotspots | 19 | 3 |
| Quality gate | 🔴 21 new issues, 0 % new coverage, 0 % hotspots reviewed | 🔴 0 % new coverage only |

Scan 2 covers less code on purpose: `reports/` and `student/results/` are frozen evidence (#325).

## 2. The eight issues

| # | SonarQube issue | Issues | Fix | PR (merge) | Report |
|---|---|---:|---|---|---|
| [#325](https://github.com/andersoxie/xpact/issues/325) | 1 · scan included frozen evidence | 97 | `sonar.exclusions` += `reports/**`, `student/results/**` | [#333](https://github.com/andersoxie/xpact/pull/333) (`7f42ae8`) | [issue-0325](../issue-0325/report.md) |
| [#326](https://github.com/andersoxie/xpact/issues/326) | 2 · `run_case` "wrong type" | 4 | false positive; typed `lane_variant`, bound loop variables | [#334](https://github.com/andersoxie/xpact/pull/334) (`63e6e9c`) | [issue-0326](../issue-0326/report.md) |
| [#327](https://github.com/andersoxie/xpact/issues/327) | 3 · blocker: always the same return value | 1 | `main() -> None`, exit codes unchanged | [#335](https://github.com/andersoxie/xpact/pull/335) (`33ab3b7`) | [issue-0327](../issue-0327/report.md) |
| [#328](https://github.com/andersoxie/xpact/issues/328) | 4 · website accessibility | 7 | real `figcaption`, screen-reader text, labelled editor section | [#336](https://github.com/andersoxie/xpact/pull/336) (`b6d88da`) | [issue-0328](../issue-0328/report.md) |
| [#329](https://github.com/andersoxie/xpact/issues/329) | 5 · website React code smells | 14 | `Readonly` props, stable keys, lookup tables | [#337](https://github.com/andersoxie/xpact/pull/337) (`ca84697`) | [issue-0329](../issue-0329/report.md) |
| [#330](https://github.com/andersoxie/xpact/issues/330) | 6 · `scripts/` Python code smells | 32 | constants, `overall_status`, explicit XML Char check | [#339](https://github.com/andersoxie/xpact/pull/339) (`d992a09`) | [issue-0330](../issue-0330/report.md) |
| [#331](https://github.com/andersoxie/xpact/issues/331) | 7 · 32 functions too complex | 32 | split into helpers, no behaviour change | [#340](https://github.com/andersoxie/xpact/pull/340) (`c7703bd`) | [issue-0331](../issue-0331/report.md) |
| [#332](https://github.com/andersoxie/xpact/issues/332) | 8 · benchmarks/examples/website scripts | 9 | literals, constants; contributed Eiffel-Loop config excluded | [#338](https://github.com/andersoxie/xpact/pull/338) (`67beb1d`) | [issue-0332](../issue-0332/report.md) |

## 3. Verification (all on the student PC, Windows 11, uv CPython 3.15)

- [x] Python suite: `python -m unittest discover -s tests/python` → Ran 239, OK (baseline before the work: 239, OK)
- [x] Website: `website\scripts\test.ps1` → 42/42 backend tests, `tsc` + `vite build` OK; Home and Validator checked in headless Chromium
- [x] Functions without unit tests compared old vs new under mocks (outputs, call order, exit codes identical): see [issue-0331](../issue-0331/report.md)
- [x] SonarQube rescan: 0 open issues (`api/issues/search?componentKeys=xpact&resolved=false`)

## 4. Still open (not code issues)

| | What | Who |
|---|---|---|
| 🟡 | **3 security hotspots** to review. The student account gets HTTP 403 on `api/hotspots/search` (needs "Administer Security Hotspots"). Seen in SonarQube for IDE and expected to be among them: SHA-1 in `prepare_xpact_core.py` (S4790; it computes git's blob id, required by git), the ECF XML namespace `http://www.eiffel.com/...` in `run_probe.py` (S5332; an identifier, not a connection) | supervisor, or give the student the permission |
| 🔴 | **Quality gate: coverage of new code 0 %** (limit 80 %). No coverage report is sent. Next step: run the Python suite under `coverage.py`, set `sonar.python.coverage.reportPaths` | open; decide whether the gate should count Python coverage |
| ⚪ | Not analysed: Eiffel (no SonarQube analyser), C, PowerShell, the C# backend (needs SonarScanner for .NET) | known limitation |
