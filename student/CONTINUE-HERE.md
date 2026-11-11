# Continue here

> Short and current: state on **2026-11-11, evening** (week 8 of 8). Handover from PC1 to **PC2**.
> Start with `git fetch --all`, then read this file, [the full to-do list](notes/left-to-do-2026-11-11.md)
> and [PLAN.md](PLAN.md) ("Next"). Rules: the repo's `CLAUDE.md` and [VERSIONING.md](VERSIONING.md).

## 1. Branches

- Work branch: **`incremental-test`** on andersoxie/xpact (`origin`). Not `student-Mass` (deleted), not CodTanium/mass-xpact.
- `main` and `incremental-test` were equal on 2026-11-11 (`75600aa`, 0 / 0): PR #291 brought `main` in, then `main`
  was fast-forwarded (student approved this one merge into `main`). After this handover PR, `incremental-test` is ahead
  again; Claude asks before touching `main`.
- Every PR merges with a **merge commit**, never squash.

## 2. State

| Area | State |
|---|---|
| Parser | unchanged since the full test rerun 2026-11-08 ✅ ([results](results/AlotOfTests-2026-11-08/README.md)) |
| Website quality check 2026-11-11 | ✅ Lighthouse accessibility 100 (light + dark), speed 98-100; ZAP 0 medium; W3C HTML 0/0; 27/27 backend tests ([PLAN](PLAN.md#-website-quality-check-2026-11-11)) |
| Website security review 2026-11-11 | ✅ findings 3-7 fixed (PR #288, #287); 🟡 finding 2 open; finding 1 fixed (#295) ([security.md](../website/docs/security.md#findings-from-the-code-review-2026-11-11)) |
| Website Docker checklist | ✅ 5/5 on GitHub windows-2022 (PR #285) |
| Website deployment | 🟡 not online; HTTPS, domain, `AllowedHosts` = Anders (#210) |
| Jenkins Groovy tests (Anders, PR #280) | ✅ run locally 2026-11-11: plots 16/16, email 19/19; `validate_declarative` needs Jenkins jars |
| [#272](https://github.com/andersoxie/xpact/issues/272) ISO-8859-1 in pieces slow | 🔴 still present |
| [#273](https://github.com/andersoxie/xpact/issues/273) DLL crash without trace | 🔴 still present |
| [#274](https://github.com/andersoxie/xpact/issues/274) not thread-safe | 🔴 not fixed |
| [#211](https://github.com/andersoxie/xpact/issues/211) billion laughs | 🟡 rechecked 2026-11-11 on a fresh DLL: right error (code 43) ✅, still ~1.5 s vs Expat ~0.1 s ([recheck](../reports/issue-0211/recheck-2026-11-11/README.md)) |
| [#293](https://github.com/andersoxie/xpact/issues/293) entity depth > 32 (found in the #211 recheck) | 🔴 well-formed documents nested 33+ levels rejected as "syntax error"; Expat accepts |
| SonarQube #131 | 🔴 token gives HTTP 401; needs a new `squ_` token (log in at sonarqube.bsharp.se → My Account → Security) |

## 3. Next (in this order)

- [x] ✅ **Website finding 1:** memory cap fails closed (#295, 28/28 tests).
- [x] ✅ **#211:** rerun on the current DLL (2026-11-11): code 43 ✅, but ~1.5 s (not "well under a second"), so left open. Ask Anders whether 1.5 s is acceptable.
- [ ] **Website finding 2:** worker slot wait with timeout (503) and a queue cap. ~4-6 h
- [ ] **#273:** exception guard on every exported DLL function. ~1 day
- [ ] Aikido: mark the 14 checksum alerts as false positives (student, dashboard). 15 min
- [ ] PR #276 (fair speed test, #275): review and merge, run it on an idle PC.
- [ ] Before 27 Nov: refresh `report/ActualReport.md` and `ActualReportShorter.md` with the work after 2026-11-10.
- Everything else, with times: [notes/left-to-do-2026-11-11.md](notes/left-to-do-2026-11-11.md).

## 4. Setup on PC2

1. Clone `https://github.com/andersoxie/xpact`, `git checkout incremental-test` (or `git pull` if already cloned).
2. Build the DLLs: `.\website\scripts\build-dll.ps1` (EiffelStudio 25.12 + MSVC `msc_vc140`).
3. Website checks: `.\website\scripts\test.ps1` (expect 27/27 + frontend build); run the site: `.\website\scripts\dev.ps1`,
   or `.\website\scripts\publish.ps1` then `website\dist\Xpact.Api.exe --urls http://localhost:5099`.
4. Jenkins Groovy tests: install Apache Groovy (6.0.0 used) + Java 21, then from the repo root
   `groovy tests\jenkins\test_plot_report_publication.groovy` and `groovy tests\jenkins\test_email_notifications.groovy`.
5. Website audit tools (nothing to install in the repo): `npx lighthouse@12 <url>` (set `CHROME_PATH` to Edge or Chrome),
   `npm i vnu-jar` + `java -jar vnu.jar` (HTML/CSS), OWASP ZAP 2.17.0 cross-platform zip from
   `gh release download -R zaproxy/zaproxy`, then `java -jar zap-2.17.0.jar -cmd -quickurl <url> -quickout report.json`.
   How the 2026-11-11 check was done: [reports/issue-0286](../reports/issue-0286/report.md).
6. Windows 11 **Home** cannot run Windows containers: Docker checks run in the GitHub workflow `website-docker.yml`.
7. Skip the 45-minute W3C-in-pieces test unless a fix touches chunked input.
