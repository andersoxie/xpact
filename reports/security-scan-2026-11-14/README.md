# Security scan 2026-11-14: WAF, antivirus and isolation (security0.8.0.txt)

**Revision:** incremental-test @ 9e3cb7a · site built once with `publish.ps1` · `native/xpact.dll` SHA-256 `adae03d2…a8a5` · build `production` · Windows 11, local only.

## What was tested

| security0.8.0.txt suggests | Local stand-in used | Status |
|---|---|---|
| Cloudflare WAF / Azure WAF (both use OWASP CRS-style managed rules) | Caddy 2.11.9 + Coraza WAF + **OWASP CRS 4.25**, paranoia level 1, blocking, in front of the site (port 5097 → 5098) | ✅ run |
| OPSWAT MetaDefender (antivirus scan of uploads) | Microsoft Defender (`MpCmdRun`) + EICAR test file | ✅ run |
| Worker isolation, limits, monitoring | Read config/code, checked logs | ✅ checked |
| Cloudflare / Azure / OPSWAT cloud services themselves | – | ⛔ need an account, a domain or an API key |
| Extra AV engine + web scanner | WSL installed, Docker 29.9.3: `clamav/clamav:1.4.3` (fresh signatures), `projectdiscovery/nuclei:v3.11.1` (7,246 templates, severity low+) | ✅ run |

## Results (expected vs observed)

| # | Check | Expected | Observed |
|---|---|---|---|
| 1 | Normal XML pasted as text (JSON) through WAF | allowed | ❌ **all 14 blocked (403)**, even `<note>…</note>`: rule 941100 "XSS via libinjection" sees `<tag>` in JSON |
| 2 | Normal XML raw (`application/xml`) through WAF | allowed | ⚠️ 4 of 15 blocked: CDATA with SQL/JS (403), RSS + UTF-16 (400, WAF's own XML parser fails, rule 200002) |
| 3 | Normal XML as file upload through WAF | allowed | ✅ 15/15 allowed |
| 4 | XXE / SSRF / parameter-entity as file upload or raw | blocked by WAF | ❌ passed the WAF (CRS does not read file contents). Parser is still safe (2026-11-13 battery) |
| 5 | EICAR inside XML, uploaded | flagged by some scanner | ❌ site accepts it (`accepted`); no scan of uploads |
| 6 | Defender on disk: plain EICAR / EICAR wrapped in XML | detected | ✅ plain detected · ⚠️ wrapped not detected (normal: EICAR must start the file) |
| 6b | ClamAV: EICAR in XML, EICAR in CDATA, XXE file | – | all three `OK` (not detected), same as Defender |
| 6c | nuclei scan of the site (port 5098) | no findings | ✅ 0 matches in 2 min |
| 7 | Defender real-time during uploads | – | 0 detections: uploads stay in memory, never on disk |
| 8 | Worker isolation | limits on | ✅ Job Object 512 MB, low integrity, 10 s timeout, max 4 workers / 2 per client |
| 9 | Logging of suspicious uploads | client + reason logged | ⚠️ console only; "Parsed … accepted" line has no client IP; DTD/external-entity attempts not flagged |

Files: `waf-run.txt` (every request), `waf-results.json`, `waf-rules-fired.txt`, `Caddyfile`, `waf_test.py`.

## Limitations
- Coraza + CRS imitates Cloudflare/Azure managed rules; their real rule sets differ in detail.
- Requests came from `127.0.0.1`, so rule 920350 (numeric Host) added 3 points to every request; rule 941100 alone (5) already reaches the block threshold.
- Defender is one engine; OPSWAT uses many. Not tested against real malware.

## Part 2: before handing the Docker image to the supervisor

| Tool | Scope | Result |
|---|---|---|
| bsharp SonarQube 25.9, **SonarScanner for .NET 12.1** (first scan that includes C#: the plain scanner skipped it) + coverage | whole repo, website = 4,265 lines | ✅ 0 vulnerabilities, security A · 58.3 % coverage · 4 bugs (S3903: types outside a namespace) · 72 code smells (33 are SYSLIB1054 "use LibraryImport") · 4 hotspots (not readable: 403) |
| Snyk Open Source 1.1308.3 (account CodTanium) | NuGet (4 projects), npm (frontend) | ✅ 0 vulnerable paths |
| Snyk Code | website | ⚠️ 1 low "log forging", Program.cs:174 → false positive (the value is an `IPAddress`, cannot hold line breaks) |
| Semgrep 1.185.0 (p/default, owasp-top-ten, csharp, typescript, react, secrets, dockerfile) | 71 files | ✅ 0 findings (3 files partly parsed: new C# syntax) |
| Trivy config | Dockerfile | ✅ 0 misconfigurations |
| Host filter test (`dist`, Host header) | | ❌ `Host: xpact.example.com` → **400**; ✅ 200 with `AllowedHosts=xpact.example.com` |
| Image source | `WEBSITE_RELEASE` | ❌ `website-2026-11-12-1` is older than the #357–#360 fixes → new release `website-2026-11-14-1` |

Problems found, kept separate:
1. **Docs:** docker.md never said `AllowedHosts` must be set → a hosted container answers 400 to everyone. *Cause confirmed* (test above). Fix: docker.md "Hosting on the internet safely".
2. **Stale image:** the published image predates the security fixes. *Confirmed* (release date 2026-11-12 01:59, fixes merged 2026-11-13). Fix: new release + `WEBSITE_RELEASE` bump.
3. **Coverage run:** with `--collect "XPlat Code Coverage"` 13 of 48 API tests fail (worker `crashed`); without it 48/48 pass. *Suspected cause:* coverlet instrumentation and the low-integrity worker. Not fixed; coverage number comes from the run with 13 failures.
4. **Sonar setup:** the plain `sonar-scanner` never analysed C#. *Confirmed* (language distribution had no `cs`). The .NET scanner must be run with `/d:sonar.sourceEncoding=UTF-8`, or Docs.tsx gets 38 false issues from the ✅ emoji.

Not done: real Cloudflare/Azure/OPSWAT (need a domain or paid key), SonarCloud (not wanted), a scan of the Windows image itself (cannot run Windows containers on Windows 11 Home).

How to repeat the Sonar scan: `powershell -File reports\security-scan-2026-11-14\sonar-net.ps1` (needs `dotnet tool install -g dotnet-sonarscanner` and the DPAPI token, see [docs](../../student/tools/sonar/)).

## Part 3: fixes and final acceptance run

**Revision:** incremental-test @ `e0c3eab` → release [`website-2026-11-14-2`](https://github.com/andersoxie/xpact/releases/tag/website-2026-11-14-2) · one `publish.ps1` build reused for every check · `Xpact.Api.dll` `bff8f7ac…`, `xpact.dll` `adae03d2…` (unchanged) · production build · Windows 11, local.

| Problem | Fix | Status |
|---|---|---|
| 1 Image older than #357–#360 | release `website-2026-11-14-1` (#372), then `-2` | ✅ image built and published by CI |
| 2 `AllowedHosts` missing from docker.md | "Hosting on the internet safely" (#372) | ✅ re-tested: `Host: xpact.example.com` → 400 without, 200 with the setting |
| 3 13 tests crash under coverage (#370) | `coverage.runsettings` instruments only Xpact.Api (#374). Cause **confirmed**: instrumented `Xpact.Contracts.dll` in the low-integrity worker | ✅ `test.ps1 -Coverage` 48/48 |
| 4 SonarQube: C# never analysed, 76 issues (#371) | worker (#375), API split (#376), LibraryImport (#377), last log guard (#378) | ✅ 76 → 1 → 0 expected (#378 removes the last one; see below) |

Final run on the release build (expected vs observed):

| Check | Expected | Observed |
|---|---|---|
| Backend tests, with coverage | 48/48 | ✅ 48/48, C# line coverage 93 % |
| Frontend type check + build | passes | ✅ |
| Attack battery (`attack.py`, 27 checks) | 27 pass | ✅ 27/27 |
| bsharp SonarQube (.NET scanner, @ `2ccfe09`) | 0 bugs/vulnerabilities | ✅ 0 bugs, 0 vulnerabilities, A/A/A, 1 issue (fixed in #378). ⚠️ 7 hotspots: student account cannot open them (403) |
| ZAP 2.17 spider + active scan | no high/medium code findings | ✅ only "HTTP Only Site" (local test has no HTTPS: the proxy/tunnel adds it, checklist #3) + 2 informational |
| nuclei 3.11.1 (7,246 templates) | 0 | ✅ 0 |
| Semgrep 1.185 (OWASP sets) | 0 | ✅ 0 (76 files) |
| Snyk Code | 0 real | ✅ 2 low "log forging" = same false positive (values are `IPAddress`) |
| Snyk / npm audit / `dotnet list --vulnerable` / Trivy | 0 | ✅ 0 |
| gitleaks (history) | no secrets | ✅ 58 hits, all file checksums in benchmark/report JSON (as on 2026-11-13) |
| CodeQL (security-extended, every PR) | 0 alerts | ✅ |

Not tested: W3C/Eiffel/Python suites (the parser DLLs did not change), the Windows container itself (no Windows containers on Windows 11 Home), Hyper-V isolation on a server.
Lesson: SonarQube + ZAP + tests + Docker at the same time ran this PC out of memory (both scans crashed); run them one after another.
