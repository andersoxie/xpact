Hi Anders,

A short update on top of my earlier message today, followed by the full status. Everything is linked.

## Latest (since my last message)

- ✅ **New website image, `website-2026-11-14-3`** (= `latest`): `ghcr.io/andersoxie/xpact-website:website-2026-11-14-3` · [release](https://github.com/andersoxie/xpact/releases/tag/website-2026-11-14-3) · built and smoke-tested on Windows Server 2022 by GitHub Actions. This is the one to host.
- ✅ **SonarQube is fully green:** quality gate **passed**, 0 issues, 0 bugs, 0 vulnerabilities, 0 security hotspots left to review, A ratings · [dashboard](https://sonarqube.bsharp.se/dashboard?id=xpact)
  - Hotspots ([#380](https://github.com/andersoxie/xpact/issues/380), closed): 9 found; 3 `unsafe` uses removed ([PR #381](https://github.com/andersoxie/xpact/pull/381), [PR #383](https://github.com/andersoxie/xpact/pull/383)); the other 6 reviewed as safe after an independent second review ([details](https://github.com/andersoxie/xpact/blob/incremental-test/reports/security-scan-2026-11-14/README.md#part-4-the-unsafe-hotspots-380-and-a-second-opinion)).
  - The second review found 3 robustness points in the worker; fixed ([#384](https://github.com/andersoxie/xpact/issues/384), [PR #385](https://github.com/andersoxie/xpact/pull/385)).
  - Quality gate ([#397](https://github.com/andersoxie/xpact/issues/397), closed): it failed only on coverage of new code (30 %), because Python coverage was never sent. Now the scan sends it, and 12 new tests cover three untested scripts → **81.4 %** ([PR #399](https://github.com/andersoxie/xpact/pull/399)). Python tests 251/251, C# tests 48/48.
- ✅ **Housekeeping:** finished items ticked in the docs and in issues ([PR #398](https://github.com/andersoxie/xpact/pull/398)); 23 merged branches deleted. Kept: `codex/gobo-nightly-verification` (yours, has unmerged commits), `fix/197-parallel-test2` (not merged) and the Dependabot branches.
- 📬 **9 Dependabot update PRs are open** ([#388](https://github.com/andersoxie/xpact/pull/388)–[#396](https://github.com/andersoxie/xpact/pull/396): GitHub Actions, Vite, test packages). I will test and merge them one by one unless you want to review them first.
- ℹ️ `main` was updated with `incremental-test` this morning ([PR #387](https://github.com/andersoxie/xpact/pull/387)); the later work today is on `incremental-test` only.

---

## 1. Security work on the website

Each row: **why the issue was opened** → **the final fix**. Full reports: [13 Nov](https://github.com/andersoxie/xpact/blob/incremental-test/reports/security-scan-2026-11-13/README.md) · [14 Nov](https://github.com/andersoxie/xpact/blob/incremental-test/reports/security-scan-2026-11-14/README.md) · [overview](https://github.com/andersoxie/xpact/blob/incremental-test/website/docs/security.md)

### Round 1: code review (11 Nov)

| Issue | Why it was opened | Final fix | PR |
|---|---|---|---|
| [#295](https://github.com/andersoxie/xpact/issues/295) | If the memory cap could not be set, the worker still ran without a cap | The worker is stopped instead ("fail closed") | [#296](https://github.com/andersoxie/xpact/pull/296) |
| [#297](https://github.com/andersoxie/xpact/issues/297) | One visitor could keep all 4 workers busy | Max 2 workers per visitor, plus a limit and timeout on the queue | [#298](https://github.com/andersoxie/xpact/pull/298) |
| [#283](https://github.com/andersoxie/xpact/issues/283) | Error details reached visitors; worker got all environment variables; any host name accepted; no HSTS | Generic errors, empty worker environment, host filter, HSTS | [#288](https://github.com/andersoxie/xpact/pull/288) |
| [#286](https://github.com/andersoxie/xpact/issues/286) | The page security policy allowed inline styles | Removed; ZAP 0 medium | [#287](https://github.com/andersoxie/xpact/pull/287) |
| [#299](https://github.com/andersoxie/xpact/issues/299) | The worker had the same rights as the web server | Low integrity, no privileges: cannot write the server's files | [#300](https://github.com/andersoxie/xpact/pull/300) |
| [#312](https://github.com/andersoxie/xpact/issues/312) | A wrong proxy setting would silently give all visitors one rate limit | The log names the untrusted proxy and the setting to change | [#313](https://github.com/andersoxie/xpact/pull/313) |

### Round 2: security scan (13 Nov)

| Issue | Why it was opened | Final fix | PR |
|---|---|---|---|
| [#357](https://github.com/andersoxie/xpact/issues/357) | Many large uploads could fill the memory before any limit was checked | Uploads are admitted before they are read | [#361](https://github.com/andersoxie/xpact/pull/361) |
| [#358](https://github.com/andersoxie/xpact/issues/358) | A very slow client could hold a connection for hours | Minimum upload speed, 120 s request timeout | [#362](https://github.com/andersoxie/xpact/pull/362) |
| [#359](https://github.com/andersoxie/xpact/issues/359) | Uploads over 64 KB were written to the temp folder | Uploads stay in memory only | [#363](https://github.com/andersoxie/xpact/pull/363) |
| [#360](https://github.com/andersoxie/xpact/issues/360) | Windows could load a planted DLL from the wrong folder | System DLLs only from System32 | [#364](https://github.com/andersoxie/xpact/pull/364) |

### Round 3: before hosting (14 Nov)

| Issue | Why it was opened | Final fix | PR |
|---|---|---|---|
| [#368](https://github.com/andersoxie/xpact/issues/368) | Image older than the fixes; docs did not say `AllowedHosts` is required (else every visitor gets "400") | New releases and image; [hosting checklist](https://github.com/andersoxie/xpact/blob/incremental-test/website/docs/docker.md#hosting-on-the-internet-safely) | [#372](https://github.com/andersoxie/xpact/pull/372), [#379](https://github.com/andersoxie/xpact/pull/379), [#386](https://github.com/andersoxie/xpact/pull/386) |
| [#369](https://github.com/andersoxie/xpact/issues/369) | No automatic security scanning on GitHub | CodeQL on every PR, weekly Dependabot | [#373](https://github.com/andersoxie/xpact/pull/373) |
| [#370](https://github.com/andersoxie/xpact/issues/370) | 13 of 48 tests crashed when coverage was measured | Coverage no longer touches the sandboxed worker's files | [#374](https://github.com/andersoxie/xpact/pull/374) |
| [#371](https://github.com/andersoxie/xpact/issues/371) | SonarQube had never scanned the C# backend (76 issues) | All fixed: 0 issues | [#375](https://github.com/andersoxie/xpact/pull/375)–[#378](https://github.com/andersoxie/xpact/pull/378) |
| [#380](https://github.com/andersoxie/xpact/issues/380) | 9 security hotspots, mostly `unsafe` code | 3 removed, 6 reviewed safe (second review); 0 left | [#381](https://github.com/andersoxie/xpact/pull/381), [#383](https://github.com/andersoxie/xpact/pull/383) |
| [#384](https://github.com/andersoxie/xpact/issues/384) | Second review: running out of memory inside a callback could end the worker, and other small points | Fixed; same output, all tests pass | [#385](https://github.com/andersoxie/xpact/pull/385) |
| [#397](https://github.com/andersoxie/xpact/issues/397) | Quality gate failed on new-code coverage (no Python coverage sent) | Python coverage sent + 12 new tests: 81.4 %, gate passes | [#399](https://github.com/andersoxie/xpact/pull/399) |

**Also tested, no code change needed:** a web firewall (Cloudflare/Azure style) would block every pasted XML and does not stop XML attacks, so the checklist says to exclude `/api/validate`. Antivirus scanning does not help for XML-only uploads (files stay in memory and are never run).

**Final results on the release build:** 48/48 backend tests, 27/27 attack tests, no real findings from ZAP, nuclei, Semgrep, CodeQL, Snyk, Trivy or the npm/NuGet audits.

---

## 2. What Jenkins could take over

| # | Job | Why |
|---|---|---|
| 1 | **Change the SonarQube stage to [sonar-net.ps1](https://github.com/andersoxie/xpact/blob/incremental-test/reports/security-scan-2026-11-14/sonar-net.ps1)** (`dotnet-sonarscanner` + C# and Python coverage; needs `coverage` installed in Python) | The stage in [Jenkinsfile.all-tests](https://github.com/andersoxie/xpact/blob/incremental-test/ci/Jenkinsfile.all-tests) runs `sonar-scanner.bat`, which skips C# and sends no coverage. **One Jenkins run would turn the quality gate red again** |
| 2 | **Website stage:** build DLL → [`test.ps1 -Coverage`](https://github.com/andersoxie/xpact/blob/incremental-test/website/scripts/test.ps1) → [`publish.ps1`](https://github.com/andersoxie/xpact/blob/incremental-test/website/scripts/publish.ps1) → [attack tests](https://github.com/andersoxie/xpact/blob/incremental-test/reports/security-scan-2026-11-13/attack.py) → keep the zip | Tests the site with a fresh DLL and makes the release zip automatically |
| 3 | **Windows container check** on a Windows Server agent: build the image, run the [checks in docker.md](https://github.com/andersoxie/xpact/blob/incremental-test/website/docs/docker.md#check-after-the-first-run), try `--isolation=hyperv` | The only part never tested on a real server |
| 4 | Keep the nightly parser runs | Already in [Jenkinsfile.all-tests](https://github.com/andersoxie/xpact/blob/incremental-test/ci/Jenkinsfile.all-tests) |
| 5 | After the site is online: weekly ZAP + nuclei against it | Catches new problems on the live site |

---

## 3. What I need from you

1. **Host the image** `ghcr.io/andersoxie/xpact-website:website-2026-11-14-3` with `-e AllowedHosts=<your domain>` and HTTPS in front (Cloudflare Tunnel or IIS): [hosting checklist](https://github.com/andersoxie/xpact/blob/incremental-test/website/docs/docker.md#hosting-on-the-internet-safely) · [#210](https://github.com/andersoxie/xpact/issues/210)
2. **Turn on Dependabot alerts and Secret scanning** in the [repository security settings](https://github.com/andersoxie/xpact/settings/security_analysis) (admin only).
3. **Jenkins:** at least item 1 above.
4. **Dependabot PRs** [#388](https://github.com/andersoxie/xpact/pull/388)–[#396](https://github.com/andersoxie/xpact/pull/396): OK if I test and merge them?
5. **Answers to the design questions** in section 5.

---

## 4. Done on the whole project

- ✅ **Parser:** W3C XML 1.0 suite, 2,585 cases: 0 failed, 0 errors in both builds (2,283 by W3C verdict, 302 "no crash"); full rerun 8 Nov, parser unchanged since · [results](https://github.com/andersoxie/xpact/blob/incremental-test/student/results/AlotOfTests-2026-11-08/README.md)
- ✅ **DLL:** errors return an error code instead of crashing ([#273](https://github.com/andersoxie/xpact/issues/273), [PR #301](https://github.com/andersoxie/xpact/pull/301)); safe from many threads ([#274](https://github.com/andersoxie/xpact/issues/274), [PR #303](https://github.com/andersoxie/xpact/pull/303))
- ✅ **Fair speed test vs Expat 2.8.1:** median 18× slower, same results on every file ([#275](https://github.com/andersoxie/xpact/issues/275), [PR #276](https://github.com/andersoxie/xpact/pull/276), [results](https://github.com/andersoxie/xpact/blob/incremental-test/student/results/fair-speed-2026-11-10/README.md))
- ✅ **Website** ([#210](https://github.com/andersoxie/xpact/issues/210)): upload and test XML, docs, conformance and benchmark pages, Docker image; memory-cap crash fixed ([#316](https://github.com/andersoxie/xpact/issues/316), [PR #355](https://github.com/andersoxie/xpact/pull/355)); 10 MB uploads no longer freeze the page ([#352](https://github.com/andersoxie/xpact/issues/352), [#353](https://github.com/andersoxie/xpact/issues/353), [PR #354](https://github.com/andersoxie/xpact/pull/354))
- ✅ **Code quality:** SonarQube 196 → 0 (Python, 12 Nov, [summary](https://github.com/andersoxie/xpact/blob/incremental-test/reports/sonarqube-2026-11-12/README.md)), 76 → 0 (C#, 14 Nov), quality gate passes (14 Nov)
- ✅ **Tooling:** no silent script actions ([#318](https://github.com/andersoxie/xpact/issues/318), [#319](https://github.com/andersoxie/xpact/issues/319), [#320](https://github.com/andersoxie/xpact/issues/320)); CodeQL + Dependabot ([#369](https://github.com/andersoxie/xpact/issues/369))

## 5. Left to do

**Design questions for you:**
- [ ] [#304](https://github.com/andersoxie/xpact/issues/304) Is parallel parsing on several threads needed for 1.0? (needs a multi-threaded Eiffel runtime)
- [ ] [#293](https://github.com/andersoxie/xpact/issues/293) Entities nested more than 32 levels are rejected; Expat accepts them. Remove the limit, or own error code?
- [ ] [#211](https://github.com/andersoxie/xpact/issues/211) "Billion laughs" is stopped with the right error, but takes ~1.5 s (Expat ~0.1 s). Acceptable?
- [ ] [#171](https://github.com/andersoxie/xpact/issues/171) Error column 0 instead of the bad token; [#13](https://github.com/andersoxie/xpact/issues/13) an exception swallowed in one GC path: fix or document?
- [ ] The licence, and whether the 10 s timeout for the "assertions" build should be raised.

**My next work, in order:**
- [ ] [#272](https://github.com/andersoxie/xpact/issues/272) ISO-8859-1 input fed in small pieces is very slow (last known speed problem). 1-2 days
- [ ] Behave like Expat in edge cases: [#123](https://github.com/andersoxie/xpact/issues/123), [#126](https://github.com/andersoxie/xpact/issues/126), [#170](https://github.com/andersoxie/xpact/issues/170), [#176](https://github.com/andersoxie/xpact/issues/176). 1-2 days each
- [ ] [#197](https://github.com/andersoxie/xpact/issues/197) Run the "W3C in pieces" test on several cores
- [ ] Test and merge the Dependabot updates
- [ ] Rerun the full speed comparison on an idle PC before quoting final numbers
- [ ] Hand-in report: reflection sections and the demonstration (27 Nov)

Thanks!
Masoud
