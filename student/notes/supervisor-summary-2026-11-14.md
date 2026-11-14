# XPact: status for the supervisor (2026-11-14)

Hi Anders, here is a short status: the security work on the website, what Jenkins could take over, and what is done and left on the whole project. Hand-in is 27 November.

---

## 1. Security work on the website

Each line: **why the issue was created** → **what the final fix was**.

### Code review (11 Nov)
| Issue | Why | Final fix |
|---|---|---|
| [#295](https://github.com/andersoxie/xpact/issues/295) | If the memory cap could not be set, the worker still ran, without any cap | The worker is stopped instead ("fail closed") |
| [#297](https://github.com/andersoxie/xpact/issues/297) | One visitor could keep all 4 workers busy | Max 2 workers per visitor, plus a waiting-queue limit and timeout |
| [#283](https://github.com/andersoxie/xpact/issues/283) | Error details reached visitors; the worker got all environment variables; any host name was accepted; no HSTS | Generic error text, empty worker environment, host filter, HSTS on HTTPS |
| [#286](https://github.com/andersoxie/xpact/issues/286) | The page security policy (CSP) still allowed inline styles | Removed; ZAP 0 medium |
| [#299](https://github.com/andersoxie/xpact/issues/299) | The worker had the same rights as the web server | Worker runs at Low integrity with no privileges: it cannot write the server's files |
| [#312](https://github.com/andersoxie/xpact/issues/312) | Behind a wrong proxy setting, all visitors would share one rate limit, silently | The log names the untrusted proxy and the setting to change |

### Security scan (13 Nov): own attack tests, ZAP, SonarQube, Trivy and others
| Issue | Why | Final fix |
|---|---|---|
| [#357](https://github.com/andersoxie/xpact/issues/357) | Many large uploads at once could fill the memory before any limit was checked | Uploads are admitted before they are read (per-visitor and memory budget) |
| [#358](https://github.com/andersoxie/xpact/issues/358) | A client sending very slowly could hold a connection for hours | Minimum upload speed and a 120 s request timeout |
| [#359](https://github.com/andersoxie/xpact/issues/359) | Uploaded files over 64 KB were written to the temp folder | Uploads stay in memory only |
| [#360](https://github.com/andersoxie/xpact/issues/360) | Windows could load a planted DLL from the wrong folder | System DLLs are only loaded from System32 |

### Before hosting (14 Nov): firewall and antivirus test, Snyk, Semgrep, CodeQL, nuclei, SonarQube
| Issue | Why | Final fix |
|---|---|---|
| [#368](https://github.com/andersoxie/xpact/issues/368) | The Docker image was older than the fixes above, and the docs did not say `AllowedHosts` is required (every visitor would get "400") | New releases + image; hosting checklist in [docker.md](https://github.com/andersoxie/xpact/blob/incremental-test/website/docs/docker.md#hosting-on-the-internet-safely) |
| [#369](https://github.com/andersoxie/xpact/issues/369) | No automatic security scanning on GitHub | CodeQL on every PR + weekly Dependabot updates |
| [#370](https://github.com/andersoxie/xpact/issues/370) | 13 of 48 backend tests crashed when coverage was measured | Coverage no longer touches the files the sandboxed worker loads; 48/48 |
| [#371](https://github.com/andersoxie/xpact/issues/371) | SonarQube had never scanned the C# backend; first scan found 76 issues | All fixed: **0 issues, 0 bugs, 0 vulnerabilities, A ratings** |
| [#380](https://github.com/andersoxie/xpact/issues/380) | SonarQube showed 9 "security hotspots" (mostly "unsafe" code) | 3 removed; 2 reviewed Safe; 4 needed for talking to the DLL, judged safe by an independent second review (being marked Safe) |
| *(new, ready to push)* | The second review found 3 robustness points in the worker's event recording | Fixed and tested locally; goes into release `website-2026-11-14-3` |

**Also tested, no change needed:** a web firewall (like Cloudflare/Azure) would block every pasted XML, and it does not stop XML attacks, so the docs say to exclude `/api/validate`. Antivirus scanners do not help for XML-only uploads (accepted risk: files stay in memory and are never run).

**Final results on the release build:** 48/48 backend tests, 27/27 attack tests, and no real findings from ZAP, nuclei, Semgrep, CodeQL, Snyk, Trivy or npm/NuGet audits. Full report: [security-scan-2026-11-14](https://github.com/andersoxie/xpact/blob/incremental-test/reports/security-scan-2026-11-14/README.md).

---

## 2. What Jenkins could take over (suggestions)

GitHub cannot build the DLL (no EiffelStudio), and my PC cannot run Windows containers. Your Jenkins can do both.

| # | Job | Why |
|---|---|---|
| 1 | **Change the SonarQube stage to the .NET scanner** (`dotnet-sonarscanner`; script: [sonar-net.ps1](https://github.com/andersoxie/xpact/blob/incremental-test/reports/security-scan-2026-11-14/sonar-net.ps1)) | Jenkins uses the plain `sonar-scanner.bat`, which skips C#. **One Jenkins run would erase the C# results and coverage from SonarQube** |
| 2 | **Website stage:** build DLL → `website\scripts\test.ps1 -Coverage` → `publish.ps1` → attack tests → keep the zip | Tests the website with the freshly built DLL, and makes the release zip automatically (now done by hand on my PC) |
| 3 | **Windows container check** (on a Windows Server agent): build the image, run the checks in docker.md, try `--isolation=hyperv` | The only part never tested on a real server |
| 4 | Keep the nightly parser runs (W3C, Eiffel matrix, Python suite) | Already in `Jenkinsfile.all-tests` |
| 5 | After the site is online: weekly ZAP + nuclei scan against it | Catches new problems on the live site |

---

## 3. What I need from you

1. **Host the image** `ghcr.io/andersoxie/xpact-website:website-2026-11-14-3` (after my next push; `-2` works too), with `-e AllowedHosts=<your domain>` and HTTPS in front (Cloudflare Tunnel or IIS). Steps: [docker.md](https://github.com/andersoxie/xpact/blob/incremental-test/website/docs/docker.md#hosting-on-the-internet-safely).
2. **GitHub:** turn on Dependabot alerts and Secret scanning ([settings](https://github.com/andersoxie/xpact/settings/security_analysis)); only an admin can.
3. **Jenkins:** at least item 1 above.
4. **Answers to the design questions** below (section 5).

---

## 4. Done on the whole project (short)

- ✅ **Parser:** W3C XML 1.0 test suite, 2,585 cases: 0 failed, 0 errors in both builds (2,283 judged by the W3C verdict, 302 "no crash" cases); full rerun on 8 Nov, parser unchanged since.
- ✅ **DLL:** errors inside a call return an error code instead of crashing ([#273](https://github.com/andersoxie/xpact/issues/273)); safe to call from many threads ([#274](https://github.com/andersoxie/xpact/issues/274)).
- ✅ **Fair speed test vs Expat 2.8.1** ([#275](https://github.com/andersoxie/xpact/issues/275)): median 18× slower, same results on every file.
- ✅ **Website** ([#210](https://github.com/andersoxie/xpact/issues/210)): upload and test XML, docs, conformance and benchmark pages; Docker image; crash under a small memory cap fixed ([#316](https://github.com/andersoxie/xpact/issues/316)); 10 MB uploads no longer freeze the page ([#352](https://github.com/andersoxie/xpact/issues/352), [#353](https://github.com/andersoxie/xpact/issues/353)).
- ✅ **Code quality:** SonarQube 196 → 0 issues (Python, 12 Nov) and 76 → 0 (C#, 14 Nov); duplication 0 %.
- ✅ **Tooling:** scripts no longer do things silently: merge commits only, no hidden DLL rebuilds ([#318](https://github.com/andersoxie/xpact/issues/318), [#319](https://github.com/andersoxie/xpact/issues/319), [#320](https://github.com/andersoxie/xpact/issues/320)).

## 5. Left to do

**Questions for you (design decisions):**
- [ ] [#304](https://github.com/andersoxie/xpact/issues/304) Is parallel parsing on several threads needed for 1.0? (needs a multi-threaded Eiffel runtime)
- [ ] [#293](https://github.com/andersoxie/xpact/issues/293) Entities nested more than 32 levels are rejected; Expat accepts. Remove the limit, or give it its own error code?
- [ ] [#211](https://github.com/andersoxie/xpact/issues/211) The "billion laughs" attack is stopped with the right error, but takes ~1.5 s (Expat ~0.1 s). Acceptable?
- [ ] [#171](https://github.com/andersoxie/xpact/issues/171) Error column 0 instead of the bad token's column; [#13](https://github.com/andersoxie/xpact/issues/13) an exception swallowed in one GC path. Fix or document?
- [ ] Licence, and whether the 10 s timeout for the slower "assertions" build should be raised.

**My work (in order):**
- [ ] [#272](https://github.com/andersoxie/xpact/issues/272) ISO-8859-1 input fed in small pieces is very slow (the last known speed problem). 1-2 days
- [ ] Behave like Expat in edge cases: [#123](https://github.com/andersoxie/xpact/issues/123), [#126](https://github.com/andersoxie/xpact/issues/126), [#170](https://github.com/andersoxie/xpact/issues/170), [#176](https://github.com/andersoxie/xpact/issues/176). 1-2 days each
- [ ] [#197](https://github.com/andersoxie/xpact/issues/197) Run the "W3C in pieces" test on several cores (faster test runs)
- [ ] Rerun the full speed comparison on an idle PC before quoting final numbers
- [ ] Hand-in report: reflection sections in my own words, and prepare the demonstration (27 Nov)

Thanks!
