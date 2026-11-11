# Continue here

> Short and current: state on **2026-11-11, night** (week 8 of 8). Hand-in: **27 November 2026**.
> Start with `git fetch --all`, then read this file, [the full to-do list](notes/left-to-do-2026-11-11.md)
> and [PLAN.md](PLAN.md) ("Next"). Rules: the repo's `CLAUDE.md` and [VERSIONING.md](VERSIONING.md) (box at the top).

## 1. Branches

- Work branch: **`incremental-test`** on andersoxie/xpact (`origin`). Not `student-Mass` (deleted), not CodTanium/mass-xpact.
- `main` was last synced with `incremental-test` on 2026-11-11 (`75600aa`); `incremental-test` is ahead since. Claude asks before touching `main`.
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
| Website security | ✅ review findings 1-7 fixed (#295, #297, #283, #286); ✅ worker with no privileges at Low integrity (#299) ([security.md](../website/docs/security.md)) |
| Website quality | ✅ Lighthouse 100, ZAP 0 medium, W3C HTML 0/0 (#286); 42/42 backend tests; pages show the fair speed result and current limits (#314) |
| Website Docker image | ✅ `ghcr.io/andersoxie/xpact-website:website-2026-11-11-1` (= `latest`, digest `sha256:60dec845…`) from release `website-2026-11-11-1` (incremental-test @ `95f140b`), PR #315; container checks pass, Low-integrity worker works in the container · 🟡 under a 40 MB cap the container worker dies of a stack overflow instead of reporting out of memory ([#316](https://github.com/andersoxie/xpact/issues/316), low impact) |
| Website proxy | ✅ untrusted proxy logged, `KnownNetworks` (#312); the real proxy setting is chosen at deployment ([docker.md](../website/docs/docker.md#behind-a-reverse-proxy)) |
| Website deployment | 🟡 not online: HTTPS, domain, `AllowedHosts` = Anders ([#210](https://github.com/andersoxie/xpact/issues/210)) |
| Tooling | ✅ #302 (no silent DLL rebuild), #306 (report logs committed), #308 (Store python alias) · 🔴 SonarQube #131 needs a new `squ_` token |

## 3. Next (in this order)

- [ ] **Hand-in report** (before 27 Nov): refresh `report/ActualReport.md` and `ActualReportShorter.md` with 2026-11-11 (website 1-2 + worker rights, #273, #274, #275, #211/#293, tooling). 2-3 h
- [ ] **Ask Anders in one go:** #304 parallel parsing, #293 depth limit, #211 1.5 s, #171, #13, #210 deployment, licence. See [left-to-do §3](notes/left-to-do-2026-11-11.md#3-questions-for-anders-ask-in-one-go).
- [ ] **#272** ISO-8859-1 in pieces (copy the UTF-16 resume path). 1-2 days
- [ ] Same behaviour as Expat: #123, #126, #176, #170. 1-2 days each
- [ ] Rerun the full fair speed matrix (#275) on an **idle** PC before quoting final numbers. 1-2 h machine time
- [ ] Next website build: rebuild + test, zip `website\dist` with `BUILD-INFO.txt`, create release `website-<date>-<n>` (`--prerelease`, full 40-character `--target`), set `WEBSITE_RELEASE` in `.github/workflows/website-docker.yml` (see docker.md)
- [ ] Aikido: mark the 14 checksum alerts as false positives (student, dashboard). 15 min
- [x] ✅ Website findings 1-2, worker rights; #273; #274; #275 merged; #302, #306, #308 (all 2026-11-11)

## 4. Setup on a new PC

1. Clone `https://github.com/andersoxie/xpact`, `git checkout incremental-test` (or `git pull` if already cloned).
2. Build the DLLs: `.\website\scripts\build-dll.ps1` (EiffelStudio 25.12 + MSVC `msc_vc140`). Write down the SHA-256 of both DLLs and check it again after each test run.
3. Python: if `python` on PATH is the Microsoft Store alias, set `XPACT_PYTHON` to a real `python.exe` (#308). Run the Python suite with that interpreter: `python -m unittest discover -s tests/python`.
4. Website checks: `.\website\scripts\test.ps1` (expect 37/37 + frontend build); run the site: `.\website\scripts\dev.ps1`,
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
