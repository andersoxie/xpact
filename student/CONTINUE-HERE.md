# Continue here

> **The only live status page.** State on **2026-11-19** (week 10) · **Version 0.10.0** (milestone, [CHANGELOG](../CHANGELOG.md#0100--2026-11-19)). Hand-in: **27 November 2026**.
> - **Map of everything** (planning, history, testing, technical docs, decisions): [PROJECT-KNOWLEDGE.md](../docs/PROJECT-KNOWLEDGE.md) · numbers: [overview](../docs/Comprehensive-Overview-Summary-of-the-Project.md) · [decision log](../docs/decision-log.md)
> - **Current state** = this file. Update it in the same PR as the change it describes.
> - **To-do** = the [open GitHub issues](https://github.com/andersoxie/xpact/issues). Summary with time estimates: [HANDOVER.md](HANDOVER.md).
> - **Plan and history** = [PLAN.md](PLAN.md) (10-week plan, solved problems, older "Next" lists). Frozen older to-do lists: [archive/](archive/).
>
> Start with `git fetch --all` and `git pull`, then read this file. Rules: the repo's `CLAUDE.md` and [VERSIONING.md](VERSIONING.md) (box at the top).

## 1. Branches

- Work branch: **`incremental-test`** on andersoxie/xpact (`origin`). Not `student-Mass` (deleted), not CodTanium/mass-xpact.
- `main` ≠ `incremental-test` (2026-11-19: `main` 8 ahead / 74 behind; decided 2026-11-19 to stay on `incremental-test` and not merge `main`, see the [decision log](../docs/decision-log.md)). `main` has the supervisor's Gobo work (PR #366, #367) and the 14 Nov sync (PR #387); everything after that is on `incremental-test` only. Claude asks before touching `main`.
- Every PR merges with a **merge commit**, never squash. Claude merges its own verified PRs into `incremental-test`, pulls, rechecks on the merged commit, then closes the issue.

## 2. State

| Area | State |
|---|---|
| Parser (Eiffel) | ✅ changed 2026-11-16: 4 allocation changes, DLL median 1.07× faster, W3C 0 failed in both builds, test 2 identical ([#407](https://github.com/andersoxie/xpact/issues/407), [report](../reports/perf-allocations/README.md)); Gobo include fix in `src` ([#409](https://github.com/andersoxie/xpact/issues/409), PR #417) |
| DLL | ✅ `xpact.dll` `32171ECD…`, `xpact_assertions.dll` `4B224D0A…` (built 2026-11-16 from `0c7e114`; smoke ok, website 48/48) · earlier: `ADAE03D2…` / `75F43A5B…` (from `2935a8a`) |
| DLL blockers | ✅ exception → error code ([#273](https://github.com/andersoxie/xpact/issues/273)); ✅ safe from many threads, calls take turns ([#274](https://github.com/andersoxie/xpact/issues/274)) · 🟡 parallel parsing: question [#304](https://github.com/andersoxie/xpact/issues/304) | · ✅ Gobo build parallel ([#418](https://github.com/andersoxie/xpact/issues/418))
| Gobo XML parser | ✅ compared on every suite: W3C 1,974/1,974 vs Gobo 1,910; fuzzing 99.996 % vs 97.6 % same as Expat; 3.4-8.6× faster; Gobo wins only on huge/deep input (⏸️ paused (by student), [#293](https://github.com/andersoxie/xpact/issues/293)) ([#442](https://github.com/andersoxie/xpact/issues/442), [report](../reports/gobo-xml-2026-11-18/README.md)) |
| Threads / Gobo | ✅ EiffelStudio's runtime does not scale threads; ✅ under Gobo the parser scales and W3C is identical ([#408](https://github.com/andersoxie/xpact/issues/408), [report](../reports/gobo-2026-11-16/README.md)); ✅ `xpact.dll` built with Gobo + msc: identical results, any thread, 0.92× EiffelStudio speed after the callback fix ([#414](https://github.com/andersoxie/xpact/issues/414), [report](../reports/gobo-dll/README.md)) · ✅ Gobo DLL without the global lock: 4 threads 0.40 s vs 0.61 s ES ([#418](https://github.com/andersoxie/xpact/issues/418)); callbacks fixed, 0.92× ES on one thread ([#428](https://github.com/andersoxie/xpact/issues/428)). Gobo in `%USERPROFILE%\tools\gobo-26.11.14` |
| Speed vs Expat | ✅ fair test: median ~17-18× slower, 0 checksum mismatches ([#275](https://github.com/andersoxie/xpact/issues/275)) · 🔴 ISO-8859-1 in pieces quadratic ([#272](https://github.com/andersoxie/xpact/issues/272)) |
| Same behaviour as Expat | 🔴 [#123](https://github.com/andersoxie/xpact/issues/123), [#126](https://github.com/andersoxie/xpact/issues/126), [#170](https://github.com/andersoxie/xpact/issues/170), [#171](https://github.com/andersoxie/xpact/issues/171), [#176](https://github.com/andersoxie/xpact/issues/176) · 🟡 [#211](https://github.com/andersoxie/xpact/issues/211) billion laughs: right error, ~1.5 s vs ~0.1 s · 🔴 [#293](https://github.com/andersoxie/xpact/issues/293) entity depth > 32 |
| Website security | ✅ 3 rounds: code review (11 Nov), scan (13 Nov, #357-#360), hosting check (14 Nov, #368-#384); attack battery 27/27; no real findings from ZAP, nuclei, Semgrep, CodeQL, Snyk, Trivy ([report](../reports/security-scan-2026-11-14/README.md), [security.md](../website/docs/security.md)) |
| Website build | ✅ image **`website-2026-11-14-3`** (= `latest`) with every fix above; hosting checklist in [docker.md](../website/docs/docker.md#hosting-on-the-internet-safely) · local build 2026-11-16 from `0c7e114`: backend 48/48 |
| Website deployment | 🟡 not online: server, domain, HTTPS, `AllowedHosts` are the supervisor's ([#210](https://github.com/andersoxie/xpact/issues/210), [package](notes/to-supervisor-2026-11-14.md)) |
| Code quality | ✅ SonarQube quality gate passes: 0 issues, 0 hotspots, new-code coverage 81.8 % ([#397](https://github.com/andersoxie/xpact/issues/397)); run `reports\security-scan-2026-11-14\sonar-net.ps1` · CodeQL on every PR |
| Dependencies | ✅ all 9 Dependabot PRs from 14 Nov merged by the supervisor (#388-#396, 16 Nov); website tests not rerun locally after #393-#396 · 🟡 grouping per ecosystem ([#420](https://github.com/andersoxie/xpact/issues/420), PR #421) works only once it is on `main` |
| Tooling | ✅ no silent DLL rebuild, `XPACT_FROZEN_DLL=1` (#302, #319); `fix.ps1` merge commits (#318); script audit (#401); #404-#406; test 2 `--jobs 16` (#197) · 🔴 [#415](https://github.com/andersoxie/xpact/issues/415) `-OutputDir` still writes `.obj` into `build\native-eiffel` |
| Hand-in | 🟡 drafts merged (PR #419): [short report](report/ActualReportShorter.md) at 16 Nov, ✏️ reflection, [demonstration](report/demonstration.md), [week 10](notes/weekly/week-10.md), [handover](HANDOVER.md): all to be rewritten by the student |

## 3. Next (in this order)

- [ ] ✏️ Rewrite the reflection sections in your own words; rehearse the [demonstration](report/demonstration.md).
- [ ] Ask Anders in one go: #304, #293, #211, #171, #13, #210 deployment, licence, assertions timeout, 10 MB limit.
- [ ] Rerun `website\scripts\test.ps1` after the Dependabot test-package updates (#393-#396).
- [x] ✅ [#418](https://github.com/andersoxie/xpact/issues/418) Gobo DLL without the global lock; thread test rerun with msc: 4 threads 0.40 s vs 0.61 s ES ([report](../reports/gobo-dll/README.md)).
- [ ] Gobo DLL: profile namespaces cells (0.74×) and 256 B-64 KB pieces; full 204-cell run.
- [ ] [#431](https://github.com/andersoxie/xpact/issues/431) thread scaling stops at 4 threads, 16 slower than 8 · [#432](https://github.com/andersoxie/xpact/issues/432) one parse = one core (question for Anders).
- [ ] [#272](https://github.com/andersoxie/xpact/issues/272) ISO-8859-1 in pieces; then #123/#176, #126, #170.
- [ ] [#415](https://github.com/andersoxie/xpact/issues/415) build script `.obj` files.
- [ ] Rerun the fair speed matrix (#275) on an **idle** PC before quoting final numbers.
- [ ] Let the Docker memory-cap check require code 1 again. ⏸ Aikido: 14 checksum alerts (put aside).

## 4. Setup on a new PC

1. Clone `https://github.com/andersoxie/xpact`, `git checkout incremental-test` (or `git pull` if already cloned).
2. Build the DLLs: `.\website\scripts\build-dll.ps1` (EiffelStudio 25.12 + MSVC `msc_vc140`). Write down the SHA-256 of both DLLs and check it again after each test run. Then set `$env:XPACT_FROZEN_DLL = "1"`: any runner that would rebuild them stops instead (#319).
3. Python: if `python` on PATH is the Microsoft Store alias, set `XPACT_PYTHON` to a real `python.exe` (#308). Run the Python suite with that interpreter: `python -m unittest discover -s tests/python`.
4. Website checks: `.\website\scripts\test.ps1` (expect 48/48 + frontend build; 48/48 on 2026-11-16 @ `0c7e114`); run the site: `.\website\scripts\dev.ps1`,
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
