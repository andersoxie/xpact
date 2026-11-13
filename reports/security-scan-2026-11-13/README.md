# Website security scan · 2026-11-13

| | |
|---|---|
| Status | ✅ **done**: 4 findings, all fixed and verified on the merged commit `9eb1193` |
| Scope | XPact website (`website/`): API, worker, React page, dependencies, git history. HTTPS is out of scope (supervisor's server) |
| Machine | student PC, Windows 11 Home · site from `website\scripts\publish.ps1`, Production, real Kestrel · DLL `ADAE03D2…` (unchanged) |
| Issues | [#357](https://github.com/andersoxie/xpact/issues/357) · [#358](https://github.com/andersoxie/xpact/issues/358) · [#359](https://github.com/andersoxie/xpact/issues/359) · [#360](https://github.com/andersoxie/xpact/issues/360) |

## 1. Result at a glance

| Layer | Tool (version) | Before | After |
|---|---|---|---|
| Harmful uploads + protocol attacks | own battery [attack.py](attack.py), 27 checks | 🟡 24 pass, 3 fail ([before](attack-before.txt)) | ✅ **27 / 27** ([final](attack-final.txt)) |
| Memory flood, 60 IPs × 21 MB | [flood.py](../issue-0357/flood.py) | 🔴 1.7 GB from **one** IP | ✅ 355 MB (budget 256 MB + the app) |
| Web scanner, spider + active scan | OWASP ZAP 2.17.0 | – | ✅ 0 high · 0 medium · 0 low · 2 info ([report](zap-report.json)) |
| Code quality and security rules | SonarQube (company server) | 0 issues | ✅ **0 issues** after the fixes ([result](sonarqube-2026-11-13.txt)); gate fails only on coverage; 2 hotspots need review rights (#342) |
| .NET security analyzers | `AnalysisLevel=latest-all` | 70 × CA5392 | ✅ 0 ([before](dotnet-analyzers-before.txt), [after](dotnet-analyzers-after.txt)) |
| Dependencies (npm, NuGet), Dockerfile, secrets | Trivy 0.76.1 | ✅ 0 vulnerabilities, 0 secrets, 0 misconfigurations ([table](trivy-website.txt)) | – |
| npm / NuGet advisories | `npm audit`, `dotnet list package --vulnerable` | ✅ 0 / 0 ([npm](npm-audit-summary.txt), [NuGet](nuget-vuln.txt)) | – |
| Secrets in all 455 commits | gitleaks 8.30.1 | ✅ 0 real (56 false positives: file checksums) ([summary](gitleaks-summary.txt)) | – |

Tools were downloaded as releases ≥ 2 weeks old, each into its own folder, SHA-256 checked against the publisher's checksums (Trivy, gitleaks) or release notes (ZAP). ZAP runs on the Java 17 that ships with the SonarScanner: nothing installed system-wide.

## 2. Findings

| # | Finding | Level | Fix | Verified |
|---|---|---|---|---|
| [#357](../issue-0357/report.md) | Upload body read into memory **before** any limit: 30 × 21 MB from one IP → 1.7 GB | 🔴 Medium (DoS) | `UploadGate`: per-visitor count and a 256 MB buffered-bytes budget, checked before reading; fewer copies | ✅ 237 MB one IP, 355 MB for 60 IPs; 46/46 |
| [#358](../issue-0358/report.md) | Slow uploads never disconnected (300 B/s still open after 40 s; 20 MB = 18 h) | 🔴 Medium (DoS) | min. 4 KB/s, `RequestTimeoutSeconds` 120 (504), `MaxConnections` 500 | ✅ ended after 11 s / 120 s; 47/47 |
| [#359](../issue-0359/report.md) | Uploads > 64 KB spooled to a temp file, contrary to security.md | 🟡 Low (privacy) | form files kept in memory (bounded by #357) | ✅ 0 temp files; test fails without the fix; 48/48 |
| [#360](../issue-0360/report.md) | CA5392: DLL search path not pinned | ⚪ Info (hardening) | `DefaultDllImportSearchPaths(System32)` | ✅ 70 → 0 |

## 3. What the attack battery checks (all ✅ after the fixes)

| Area | Checks |
|---|---|
| External entities / SSRF | file read (`file:///c:/windows/win.ini`), UNC path (NTLM leak), outbound HTTP via DOCTYPE, entity, parameter entity, stylesheet PI, XInclude: **0 connections** to a local listener |
| Entity bombs | billion laughs (code 43, 1.6 s), quadratic blow-up (43), entity bomb in 20,000 attributes |
| Structure | 3 million nested elements, a 5 MB name, 300,000 attributes, duplicate attribute |
| Encodings / binary | 10 MB random bytes, UTF-16, UTF-32, NUL, overlong UTF-8, surrogates, unknown encoding, gzip bomb with `Content-Encoding: gzip` (not decompressed) |
| Scripts | SVG with `<script>` and `onload`: answer is JSON with `nosniff` and CSP; the page has no `innerHTML`/`eval` |
| Multipart | `../` and CRLF in the file name, 5,000 fields (400), 150 extra files |
| Parameters | `build=../..`, NUL, negative and huge chunk sizes, JSON nested 5,000 deep: never 500 |
| Server files | `appsettings.json`, DLLs, `.exe`, `web.config`, `.git/config`, `..%2f` in `/api/results`: never served |
| HTTP | TRACE/PUT/DELETE/OPTIONS 405, foreign `Host` 400, security headers, no `Server`/`X-Powered-By` |
| Disk | no temp file during a 5 MB upload |
| Slow clients | slow headers dropped (~30 s), slow body dropped (11 s) |
| Rate limit | 30 per minute, then 429 |

**Not a finding:** a spoofed `X-Forwarded-For` from localhost is believed. That is intended (a reverse proxy on the same machine); from any other address it is ignored, shown by the unit test `Only_trusted_proxies_pass_on_the_visitor_address`. The first battery run counted this as a failure; the check was corrected.

**Observed, parser-side (not website security):** a 5 MB element name, 300,000 attributes and 3 million open elements are rejected with code 2 "syntax error" quickly and safely; Expat would accept the first two. These are parser limits (`src/xp_limits.e`, related to #293), not a risk for the site.

## 4. Limitations
- HTTPS, HSTS in production, the domain and `AllowedHosts`, and network-level flood protection (many IPs) belong to the reverse proxy: supervisor ([#210](https://github.com/andersoxie/xpact/issues/210)).
- ZAP's spider cannot see the POST API of a single-page site; the battery covers `/api/validate`.
- The fixes are on `incremental-test`, **not yet in a release build or the Docker image**.
- The one-IP flood on the final build was refused at once (30 × 429) because the battery's rate-limit check had just used that minute; the fair one-IP number is the 237 MB from the #357 run.

## 5. How to repeat
```
powershell -File website\scripts\publish.ps1
website\dist\Xpact.Api.exe --urls http://localhost:5099
set Xpact__RequestsPerMinute=100000 & set Xpact__MaxWorkersPerClient=4 & website\dist\Xpact.Api.exe --urls http://localhost:5098
python -I reports\security-scan-2026-11-13\attack.py 5098 5099 out.json
python -I reports\issue-0357\flood.py 5099 60 multi
python -I reports\issue-0358\slow.py 5099 300 40
java -jar zap-2.17.0.jar -cmd -port 8091 -quickurl http://localhost:5098/ -quickout zap.json
trivy fs --scanners vuln,secret,misconfig --skip-dirs node_modules website
gitleaks git . --redact
```
