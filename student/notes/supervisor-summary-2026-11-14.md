Hi Anders,

Here is a status of the XPact project: the security work on the website, what Jenkins could take over, what I need from you, and what is done and left on the whole project. Every issue, pull request (PR) and report is linked. Hand-in is 27 November.

**Quick links:** [repository (incremental-test)](https://github.com/andersoxie/xpact/tree/incremental-test) · [all issues](https://github.com/andersoxie/xpact/issues) · [security report 14 Nov](https://github.com/andersoxie/xpact/blob/incremental-test/reports/security-scan-2026-11-14/README.md) · [hosting checklist](https://github.com/andersoxie/xpact/blob/incremental-test/website/docs/docker.md#hosting-on-the-internet-safely) · [website security overview](https://github.com/andersoxie/xpact/blob/incremental-test/website/docs/security.md) · [SonarQube](https://sonarqube.bsharp.se/dashboard?id=xpact) · [release website-2026-11-14-3](https://github.com/andersoxie/xpact/releases/tag/website-2026-11-14-3)

---

## 1. Security work on the website

Each row: **why the issue was opened** → **the final fix**, with the PR and the report.

### Round 1: code review (11 Nov)

| Issue | Why it was opened | Final fix | PR · report |
|---|---|---|---|
| [#295](https://github.com/andersoxie/xpact/issues/295) | If the memory cap could not be set, the worker still ran, without any cap | The worker is stopped instead ("fail closed") | [PR #296](https://github.com/andersoxie/xpact/pull/296) · [report](https://github.com/andersoxie/xpact/blob/incremental-test/reports/issue-0295) |
| [#297](https://github.com/andersoxie/xpact/issues/297) | One visitor could keep all 4 workers busy | Max 2 workers per visitor, plus a limit and timeout on the waiting queue | [PR #298](https://github.com/andersoxie/xpact/pull/298) · [report](https://github.com/andersoxie/xpact/blob/incremental-test/reports/issue-0297) |
| [#283](https://github.com/andersoxie/xpact/issues/283) | Error details reached visitors; the worker got all environment variables; any host name was accepted; no HSTS | Generic error text, empty worker environment, host filter, HSTS on HTTPS | [PR #288](https://github.com/andersoxie/xpact/pull/288) |
| [#286](https://github.com/andersoxie/xpact/issues/286) | The page security policy (CSP) still allowed inline styles | Removed; ZAP 0 medium | [PR #287](https://github.com/andersoxie/xpact/pull/287) |
| [#299](https://github.com/andersoxie/xpact/issues/299) | The worker had the same rights as the web server | The worker runs at Low integrity with no privileges and cannot write the server's files | [PR #300](https://github.com/andersoxie/xpact/pull/300) · [report](https://github.com/andersoxie/xpact/blob/incremental-test/reports/issue-0299) |
| [#312](https://github.com/andersoxie/xpact/issues/312) | Behind a wrong proxy setting, all visitors would silently share one rate limit | The log names the untrusted proxy and the setting to change | [PR #313](https://github.com/andersoxie/xpact/pull/313) · [report](https://github.com/andersoxie/xpact/blob/incremental-test/reports/issue-0312) |

### Round 2: security scan (13 Nov): own attack tests, ZAP, SonarQube, Trivy, gitleaks · [report](https://github.com/andersoxie/xpact/blob/incremental-test/reports/security-scan-2026-11-13/README.md)

| Issue | Why it was opened | Final fix | PR · report |
|---|---|---|---|
| [#357](https://github.com/andersoxie/xpact/issues/357) | Many large uploads at once could fill the memory before any limit was checked | Uploads are admitted before they are read (per-visitor limit and memory budget) | [PR #361](https://github.com/andersoxie/xpact/pull/361) · [report](https://github.com/andersoxie/xpact/blob/incremental-test/reports/issue-0357) |
| [#358](https://github.com/andersoxie/xpact/issues/358) | A client sending very slowly could hold a connection for hours | Minimum upload speed and a 120 s request timeout | [PR #362](https://github.com/andersoxie/xpact/pull/362) · [report](https://github.com/andersoxie/xpact/blob/incremental-test/reports/issue-0358) |
| [#359](https://github.com/andersoxie/xpact/issues/359) | Uploaded files over 64 KB were written to the temp folder | Uploads stay in memory only | [PR #363](https://github.com/andersoxie/xpact/pull/363) · [report](https://github.com/andersoxie/xpact/blob/incremental-test/reports/issue-0359) |
| [#360](https://github.com/andersoxie/xpact/issues/360) | Windows could load a planted DLL from the wrong folder | System DLLs are only loaded from System32 | [PR #364](https://github.com/andersoxie/xpact/pull/364) · [report](https://github.com/andersoxie/xpact/blob/incremental-test/reports/issue-0360) |

### Round 3: before hosting (14 Nov): firewall and antivirus test, Snyk, Semgrep, CodeQL, nuclei, ZAP, SonarQube · [report](https://github.com/andersoxie/xpact/blob/incremental-test/reports/security-scan-2026-11-14/README.md)

| Issue | Why it was opened | Final fix | PR |
|---|---|---|---|
| [#368](https://github.com/andersoxie/xpact/issues/368) | The Docker image was older than the fixes above, and the docs did not say `AllowedHosts` is required (without it every visitor gets "400") | New releases and image; [hosting checklist](https://github.com/andersoxie/xpact/blob/incremental-test/website/docs/docker.md#hosting-on-the-internet-safely) | [PR #372](https://github.com/andersoxie/xpact/pull/372), [PR #379](https://github.com/andersoxie/xpact/pull/379) |
| [#369](https://github.com/andersoxie/xpact/issues/369) | No automatic security scanning on GitHub | CodeQL on every PR + weekly Dependabot updates | [PR #373](https://github.com/andersoxie/xpact/pull/373) |
| [#370](https://github.com/andersoxie/xpact/issues/370) | 13 of 48 backend tests crashed when coverage was measured | Coverage no longer touches the files the sandboxed worker loads; 48/48 | [PR #374](https://github.com/andersoxie/xpact/pull/374) |
| [#371](https://github.com/andersoxie/xpact/issues/371) | SonarQube had never scanned the C# backend; the first scan found 76 issues | All fixed: **0 issues, 0 bugs, 0 vulnerabilities, A ratings** | [PR #375](https://github.com/andersoxie/xpact/pull/375), [#376](https://github.com/andersoxie/xpact/pull/376), [#377](https://github.com/andersoxie/xpact/pull/377), [#378](https://github.com/andersoxie/xpact/pull/378) |
| [#380](https://github.com/andersoxie/xpact/issues/380) | SonarQube showed 9 "security hotspots", mostly `unsafe` code | 3 removed; 2 reviewed Safe; 4 are needed to talk to the DLL and were judged safe by an independent second review | [PR #381](https://github.com/andersoxie/xpact/pull/381), [PR #383](https://github.com/andersoxie/xpact/pull/383) |
| [#384](https://github.com/andersoxie/xpact/issues/384) | The second review found 3 robustness points in the worker's event recording (e.g. running out of memory inside a callback could end the worker) | Fixed; same output as before, all tests pass | [PR #385](https://github.com/andersoxie/xpact/pull/385) |

**Also tested, no code change needed:**
- A web firewall (like Cloudflare/Azure) would block every pasted XML and does not stop XML attacks, so the [checklist](https://github.com/andersoxie/xpact/blob/incremental-test/website/docs/docker.md#hosting-on-the-internet-safely) says to exclude `/api/validate`.
- Antivirus scanners do not help for XML-only uploads (accepted risk: files stay in memory and are never run).

**Final results on the release build:** 48/48 backend tests, 27/27 attack tests, and no real findings from ZAP, nuclei, Semgrep, CodeQL, Snyk, Trivy or the npm/NuGet audits.

---

## 2. What Jenkins could take over

GitHub cannot build the DLL (no EiffelStudio), and my PC cannot run Windows containers. Jenkins can do both.

| # | Job | Why |
|---|---|---|
| 1 | **Change the SonarQube stage to the .NET scanner** (`dotnet-sonarscanner`, as in [sonar-net.ps1](https://github.com/andersoxie/xpact/blob/incremental-test/reports/security-scan-2026-11-14/sonar-net.ps1)) | The stage in [Jenkinsfile.all-tests](https://github.com/andersoxie/xpact/blob/incremental-test/ci/Jenkinsfile.all-tests) runs `sonar-scanner.bat`, which skips C#. **One Jenkins run would erase the C# results and coverage from SonarQube** |
| 2 | **Website stage:** build DLL → [`test.ps1 -Coverage`](https://github.com/andersoxie/xpact/blob/incremental-test/website/scripts/test.ps1) → [`publish.ps1`](https://github.com/andersoxie/xpact/blob/incremental-test/website/scripts/publish.ps1) → [attack tests](https://github.com/andersoxie/xpact/blob/incremental-test/reports/security-scan-2026-11-13/attack.py) → keep the zip | Tests the website with a freshly built DLL and makes the release zip automatically (today done by hand on my PC) |
| 3 | **Windows container check** on a Windows Server agent: build the image, run the [checks in docker.md](https://github.com/andersoxie/xpact/blob/incremental-test/website/docs/docker.md#check-after-the-first-run), try `--isolation=hyperv` | The only part never tested on a real server |
| 4 | Keep the nightly parser runs (W3C, Eiffel matrix, Python suite) | Already in [Jenkinsfile.all-tests](https://github.com/andersoxie/xpact/blob/incremental-test/ci/Jenkinsfile.all-tests) |
| 5 | After the site is online: a weekly ZAP + nuclei scan against it | Catches new problems on the live site |

---

## 3. What I need from you

1. **Host the website image** `ghcr.io/andersoxie/xpact-website:website-2026-11-14-3` ([release](https://github.com/andersoxie/xpact/releases/tag/website-2026-11-14-3)) with `-e AllowedHosts=<your domain>` and HTTPS in front (Cloudflare Tunnel or IIS). Steps: [hosting checklist](https://github.com/andersoxie/xpact/blob/incremental-test/website/docs/docker.md#hosting-on-the-internet-safely). Background: [#210](https://github.com/andersoxie/xpact/issues/210).
2. **Turn on Dependabot alerts and Secret scanning** in the [repository security settings](https://github.com/andersoxie/xpact/settings/security_analysis); only an admin can.
3. **Jenkins:** at least item 1 in section 2.
4. **Answers to the design questions** in section 5.

---

## 4. Done on the whole project

- ✅ **Parser:** W3C XML 1.0 test suite, 2,585 cases: 0 failed, 0 errors in both builds (2,283 judged by the W3C verdict, 302 "no crash" cases); full rerun on 8 Nov, parser unchanged since · [results](https://github.com/andersoxie/xpact/blob/incremental-test/student/results/AlotOfTests-2026-11-08/README.md)
- ✅ **DLL:** an error inside a call returns an error code instead of crashing ([#273](https://github.com/andersoxie/xpact/issues/273), [PR #301](https://github.com/andersoxie/xpact/pull/301), [report](https://github.com/andersoxie/xpact/blob/incremental-test/reports/issue-0273/report.md)); safe to call from many threads ([#274](https://github.com/andersoxie/xpact/issues/274), [PR #303](https://github.com/andersoxie/xpact/pull/303), [report](https://github.com/andersoxie/xpact/blob/incremental-test/reports/issue-0274/report.md))
- ✅ **Fair speed test vs Expat 2.8.1:** median 18× slower, same results on every file ([#275](https://github.com/andersoxie/xpact/issues/275), [PR #276](https://github.com/andersoxie/xpact/pull/276), [results](https://github.com/andersoxie/xpact/blob/incremental-test/student/results/fair-speed-2026-11-10/README.md))
- ✅ **Website** ([#210](https://github.com/andersoxie/xpact/issues/210)): upload and test XML, docs, conformance and benchmark pages, Docker image ([docker.md](https://github.com/andersoxie/xpact/blob/incremental-test/website/docs/docker.md)); crash under a small memory cap fixed ([#316](https://github.com/andersoxie/xpact/issues/316), [PR #355](https://github.com/andersoxie/xpact/pull/355), [report](https://github.com/andersoxie/xpact/blob/incremental-test/reports/issue-0316/report.md)); 10 MB uploads no longer freeze the page ([#352](https://github.com/andersoxie/xpact/issues/352), [#353](https://github.com/andersoxie/xpact/issues/353), [PR #354](https://github.com/andersoxie/xpact/pull/354), [report](https://github.com/andersoxie/xpact/blob/incremental-test/reports/issue-0352/report.md))
- ✅ **Code quality:** SonarQube 196 → 0 issues on 12 Nov ([summary](https://github.com/andersoxie/xpact/blob/incremental-test/reports/sonarqube-2026-11-12/README.md)) and 76 → 0 for C# on 14 Nov ([#371](https://github.com/andersoxie/xpact/issues/371)); duplication 0 %
- ✅ **Tooling:** scripts no longer do things silently: merge commits only, no hidden DLL rebuilds, text files up to date ([#318](https://github.com/andersoxie/xpact/issues/318) / [PR #321](https://github.com/andersoxie/xpact/pull/321), [#319](https://github.com/andersoxie/xpact/issues/319) / [PR #322](https://github.com/andersoxie/xpact/pull/322), [#320](https://github.com/andersoxie/xpact/issues/320) / [PR #323](https://github.com/andersoxie/xpact/pull/323))

## 5. Left to do

**Design questions for you:**
- [ ] [#304](https://github.com/andersoxie/xpact/issues/304) Is parallel parsing on several threads needed for 1.0? (needs a multi-threaded Eiffel runtime)
- [ ] [#293](https://github.com/andersoxie/xpact/issues/293) Entities nested more than 32 levels are rejected; Expat accepts them. Remove the limit, or give it its own error code?
- [ ] [#211](https://github.com/andersoxie/xpact/issues/211) The "billion laughs" attack is stopped with the right error, but takes ~1.5 s (Expat ~0.1 s). Acceptable?
- [ ] [#171](https://github.com/andersoxie/xpact/issues/171) Error column 0 instead of the bad token's column, and [#13](https://github.com/andersoxie/xpact/issues/13) an exception swallowed in one GC path: fix or document?
- [ ] The licence, and whether the 10 s timeout for the slower "assertions" build should be raised.

**My next work, in order:**
- [ ] [#272](https://github.com/andersoxie/xpact/issues/272) ISO-8859-1 input fed in small pieces is very slow (the last known speed problem). 1-2 days
- [ ] Behave like Expat in edge cases: [#123](https://github.com/andersoxie/xpact/issues/123), [#126](https://github.com/andersoxie/xpact/issues/126), [#170](https://github.com/andersoxie/xpact/issues/170), [#176](https://github.com/andersoxie/xpact/issues/176). 1-2 days each
- [ ] [#197](https://github.com/andersoxie/xpact/issues/197) Run the "W3C in pieces" test on several cores (faster test runs)
- [ ] Rerun the full speed comparison on an idle PC before quoting final numbers
- [ ] Hand-in report: reflection sections and the demonstration (27 Nov)

Thanks!
Masoud
