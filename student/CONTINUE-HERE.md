# Continue here

> Short and current: state on **2026-11-14** (week 9). Hand-in: **27 November 2026**.
> Start with `git fetch --all`, then read this file, [the full to-do list](notes/left-to-do-2026-11-11.md)
> and [PLAN.md](PLAN.md) ("Next"). Rules: the repo's `CLAUDE.md` and [VERSIONING.md](VERSIONING.md) (box at the top).

## 1. Branches

- Work branch: **`incremental-test`** on andersoxie/xpact (`origin`). Not `student-Mass` (deleted), not CodTanium/mass-xpact.
- `main` = `incremental-test` (0 ahead / 0 behind) since 2026-11-12: PR #344, then PR #350 and a fast-forward of `main` to `fff0d2d`. Claude asks before touching `main` again.
- Every PR merges with a **merge commit**, never squash. Claude merges its own verified PRs into `incremental-test`, pulls, rechecks on the merged commit, then closes the issue.

## 2. State

| Area | State |
|---|---|
| Parser (Eiffel) | ✅ unchanged since the full rerun 2026-11-08 ([results](results/AlotOfTests-2026-11-08/README.md)); the DLL bridge changed (#273, #274) and was fully retested |
| DLL | ✅ `xpact.dll` `ADAE03D2…`, `xpact_assertions.dll` `75F43A5B…` (from `2935a8a`; same source up to `c33cade`) |
| [#273](https://github.com/andersoxie/xpact/issues/273) exception in a DLL call | ✅ fixed: error code instead of a crash without trace ([report](../reports/issue-0273/report.md)) |
| [#274](https://github.com/andersoxie/xpact/issues/274) threads | ✅ safe from many threads (calls take turns, no single-thread cost) · 🟡 parallel parsing: question [#304](https://github.com/andersoxie/xpact/issues/304) ([report](../reports/issue-0274/report.md)) |
| [#275](https://github.com/andersoxie/xpact/issues/275) fair speed test vs Expat 2.8.1 | ✅ merged: median 18× slower, 0 checksum mismatches; after #273/#274 whole documents unchanged, 1-byte pieces 2-4 % ([check](../reports/issue-0276-check/README.md)) |
| [#211](https://github.com/andersoxie/xpact/issues/211) billion laughs | 🟡 right error (code 43) ✅, ~1.5 s vs Expat ~0.1 s: ask Anders ([recheck](../reports/issue-0211/recheck-2026-11-11/README.md)) |
| [#293](https://github.com/andersoxie/xpact/issues/293) entity depth > 32 | 🔴 well-formed documents nested 33+ levels rejected as "syntax error"; Expat accepts: ask Anders (remove limit or own error code) |
| [#272](https://github.com/andersoxie/xpact/issues/272) ISO-8859-1 in pieces | 🔴 quadratic, still present |
| Website security | ✅ **scan 2026-11-14** ([report](../reports/security-scan-2026-11-14/README.md)): WAF/antivirus test, Snyk, Semgrep, CodeQL, nuclei, ZAP, attack battery 27/27 on the final build · ✅ security scan 2026-11-13: 4 findings fixed (#357-#360), battery 27/27, ZAP 0 high/medium/low ([scan](../reports/security-scan-2026-11-13/README.md)) · ✅ review findings 1-7 fixed (#295, #297, #283, #286); ✅ worker with no privileges at Low integrity (#299) ([security.md](../website/docs/security.md)) |
| Website quality | ✅ Lighthouse 100, ZAP 0 medium, W3C HTML 0/0 (#286); 42/42 backend tests; pages show the fair speed result and current limits (#314) |
| Website Docker image | ✅ **`website-2026-11-14-2`** (= `latest`, `sha256:a1ea0cdf…`, from `e0c3eab`, PR #379); hosting checklist in docker.md (#368). Older: `website-2026-11-12-1` (digest digest `sha256:08b77a5b…`) from release `website-2026-11-12-1` (`a840029`: accessibility #328, React #329, same DLLs), PR #348; container smoke and memory-cap tests pass ([report](../reports/issue-0345/report.md)) · ✅ small memory cap crash fixed in the worker: cause was .NET loading types at the cap, not the DLL ([#316](https://github.com/andersoxie/xpact/issues/316), [report](../reports/issue-0316/report.md)) · ✅ 10 MB upload no longer freezes the page ([#352](https://github.com/andersoxie/xpact/issues/352), [#353](https://github.com/andersoxie/xpact/issues/353), [report](../reports/issue-0352/report.md)) · both need the next website release |
| Website proxy | ✅ untrusted proxy logged, `KnownNetworks` (#312); the real proxy setting is chosen at deployment ([docker.md](../website/docs/docker.md#behind-a-reverse-proxy)) |
| Website deployment | 🟡 not online; package for Anders ready: [to-supervisor-2026-11-14.md](notes/to-supervisor-2026-11-14.md) ([#210](https://github.com/andersoxie/xpact/issues/210)) |
| Tooling | ✅ #302 (no silent DLL rebuild), #306 (report logs committed), #308 (Store python alias), [#318](https://github.com/andersoxie/xpact/issues/318) (`fix.ps1` merge commits into `incremental-test`, refuses `main`), [#319](https://github.com/andersoxie/xpact/issues/319) (DLL SHA-256 on every rebuild, `XPACT_FROZEN_DLL=1` blocks rebuilds) |
| SonarQube | ✅ **2026-11-14: first scan with C# (.NET scanner), 76 → 0 issues** (#371, PRs #375-#378); 🟡 9 hotspots: 3 removed, 6 to mark Safe ([#380](https://github.com/andersoxie/xpact/issues/380)) · ✅ scan works with the student's token (2026-11-12); **196 → 0 issues**, duplication 14 % → 0 % (#325-#332, PRs #333-#340) ([summary](../reports/sonarqube-2026-11-12/README.md)) · 🟡 3 hotspots need review rights · 🔴 gate: no coverage report yet · run: `student\tools\sonar\run-sonar.ps1 -Scanner %USERPROFILE%\tools\sonar\sonar-scanner-7.0.2.4839-windows-x64\bin\sonar-scanner.bat` |

## 3. Next (in this order)

- [x] ✅ **Hand-in report** updated to 2026-11-12 (#346): numbers recounted, SonarQube, tooling, `main` sync. Left for the student: the ✏️ reflection sections in your own words, then the demonstration.
- [ ] **Ask Anders in one go:** #304 parallel parsing, #293 depth limit, #211 1.5 s, #171, #13, #210 deployment, licence. See [left-to-do §3](notes/left-to-do-2026-11-11.md#3-questions-for-anders-ask-in-one-go).
- [ ] **#272** ISO-8859-1 in pieces (copy the UTF-16 resume path). 1-2 days
- [ ] Same behaviour as Expat: #123, #126, #176, #170. 1-2 days each
- [ ] Rerun the full fair speed matrix (#275) on an **idle** PC before quoting final numbers. 1-2 h machine time
- [x] ✅ Website build `website-2026-11-12-1` shipped (#345, PR #348). Next build: same steps (see the [#345 report](../reports/issue-0345/report.md)); the student runs `gh release create`.
- [ ] ⏸ Aikido: mark the 14 checksum alerts as false positives (put aside, 2026-11-12).
- [x] ✅ #316 found with WinDbg and fixed in the worker (2026-11-12, [report](../reports/issue-0316/report.md)); #352/#353 10 MB upload fixed (PR #354)
- [x] ✅ Website release with #316 + #352/#353 + #357-#360 + #371/#380/#384: `website-2026-11-14-3` (2026-11-14)
- [ ] Let the Docker memory-cap check require code 1 again
- [x] ✅ Weekly note [week 9](notes/weekly/week-09.md).
- [x] ✅ Website findings 1-2, worker rights; #273; #274; #275 merged; #302, #306, #308 (all 2026-11-11)

## 4. Setup on a new PC

1. Clone `https://github.com/andersoxie/xpact`, `git checkout incremental-test` (or `git pull` if already cloned).
2. Build the DLLs: `.\website\scripts\build-dll.ps1` (EiffelStudio 25.12 + MSVC `msc_vc140`). Write down the SHA-256 of both DLLs and check it again after each test run. Then set `$env:XPACT_FROZEN_DLL = "1"`: any runner that would rebuild them stops instead (#319).
3. Python: if `python` on PATH is the Microsoft Store alias, set `XPACT_PYTHON` to a real `python.exe` (#308). Run the Python suite with that interpreter: `python -m unittest discover -s tests/python`.
4. Website checks: `.\website\scripts\test.ps1` (expect 42/42 + frontend build; 42/42 on 2026-11-11 @ `af7eaf1`); run the site: `.\website\scripts\dev.ps1`,
   or `.\website\scripts\publish.ps1` then `website\dist\Xpact.Api.exe --urls http://localhost:5099`. In Windows PowerShell 5.1 run `publish.ps1` in its own process (an npm notice on stderr stops it otherwise).
5. W3C + benchmarks on the DLL you built: `.\scripts\run_benchmarks.ps1 -EiffelBuild Finalized,FinalizedAssertions -W3cAllCases -SkipWslC -UseExistingNativeDll -NoDocsUpdate -W3cSuiteDirectory <xmlconf>` (#302).
6. C# DLL tests: `dotnet build tests\dotnet\XpactDllTests -c Release -o <dir>`, then `<dir>\XpactDllTests.exe --dll <xpact.dll> --out <dir>` for both DLLs (4,308 cases).
7. Thread and exception probes: `reports\issue-0274\build-thread-tests.ps1` (threads.c, threads2.c), `reports\issue-0273\inprocess.py <dll> 40`.
8. Jenkins Groovy tests: install Apache Groovy (6.0.0 used) + Java 21, then from the repo root
   `groovy tests\jenkins\test_plot_report_publication.groovy` and `groovy tests\jenkins\test_email_notifications.groovy`.
9. Website audit tools (nothing to install in the repo): `npx lighthouse@12 <url>` (set `CHROME_PATH` to Edge or Chrome),
   `npm i vnu-jar` + `java -jar vnu.jar` (HTML/CSS), OWASP ZAP 2.17.0 cross-platform zip from
   `gh release download -R zaproxy/zaproxy`, then `java -jar zap-2.17.0.jar -cmd -quickurl <url> -quickout report.json`.
   How the 2026-11-11 check was done: [reports/issue-0286](../reports/issue-0286/report.md).
10. Windows 11 **Home** cannot run Windows containers: Docker checks run in the GitHub workflow `website-docker.yml`.
11. Skip the 45-minute W3C-in-pieces test unless a fix touches chunked input.
