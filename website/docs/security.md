# Security

[← website README](../README.md)

The site runs a parser on documents from strangers. These are the protections, and what has been tested.

## Protections

| Risk | Protection | Where | Tested |
|---|---|---|---|
| Reading server files or URLs through external entities (XXE) | No `ExternalEntityRefHandler` and no parameter-entity parsing are set, so the parser never opens a file or URL named in the document | `Xpact.Worker/Program.cs` | ✅ `External_entities_are_never_loaded` (an entity pointing to `C:\Windows\win.ini` stays empty) |
| A parser crash taking the site down | One worker **process** per document | `WorkerRunner.cs` | ✅ verdict `crashed` is handled; the worker pattern is the one used by `tests/dotnet/XpactDllTests` |
| Endless parsing (CPU) | Worker killed after 10 s; below-normal priority | `WorkerRunner.cs` | ✅ `Slow_documents_are_stopped_by_the_timeout` |
| Worker taken over | No privileges, Low integrity, started suspended (`WorkerLowIntegrity`) | `Workers/WorkerLauncher.cs` | ✅ `Worker_runs_at_low_integrity_without_privileges`, `A_low_integrity_process_cannot_write_to_the_api_accounts_files` (#299) |
| Memory exhaustion | Windows Job Object, 512 MB per worker | `Workers/JobObject.cs` | ✅ `The_memory_cap_stops_a_worker_that_needs_more` (#227): under a 40 MB cap a nested-entity document stops the worker (`crashed`); the API keeps serving |
| Huge uploads | Documents up to 10 MB (the parser's own limit); request body at most 2 × 10 MB + 64 KB (JSON escaping); `413` above. A 10 MB document needs about 175-250 MB in the worker (measured 2026-11-10), below the 512 MB cap | `Program.cs` | ✅ `Bad_requests_are_refused` |
| Request floods | Rate limit, 30 / min per IP; at most 4 workers at once | `Program.cs` | ✅ `Requests_are_rate_limited_per_client` |
| One visitor using up the limit for everyone behind a proxy | `X-Forwarded-For` is read from a proxy on this machine or one in `Xpact:KnownProxies` only, so the limit counts each real visitor and visitors cannot fake their address | `Program.cs` | ✅ `Visitors_behind_a_proxy_are_rate_limited_separately` |
| Reading other files through the results endpoint | Allowed names only: `conformance`, `benchmarks`, `comparison`, `testing` | `Program.cs` | ✅ `Results_files_are_served_and_names_are_checked` |
| Click-jacking, MIME sniffing, leaking referrers | `X-Frame-Options: DENY`, `frame-ancestors 'none'`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, a strict CSP without `'unsafe-inline'` and with `base-uri`, `form-action`, `object-src`; `Permissions-Policy`, `Cross-Origin-Opener-Policy`; no `Server` header | `Program.cs` | ✅ `Security_headers_are_set`; OWASP ZAP 2.17.0: 0 medium/high ([#286](https://github.com/andersoxie/xpact/issues/286)) |
| Storing visitors' documents | Nothing is written to disk: uploads stay in memory (also files over 64 KB, #359); the document goes to the worker on stdin; logs record size, build, verdict and time only | `Program.cs` (`FormOptions`), `WorkerRunner.cs` | ✅ `A_large_uploaded_file_does_not_touch_the_temp_folder` ([#359](../../reports/issue-0359/report.md)) |
| Memory flood: many large uploads at once | Uploads are admitted **before** their body is read: at most `MaxWorkersPerClient` per visitor (429) and a buffered-bytes budget `MaxBufferedMb` = 256 MB (503); one exact copy per body | `Workers/UploadGate.cs` | ✅ `UploadGateTests`; 60 IPs × 21 MB → 355 MB peak (was 1.7 GB from one IP) ([#357](../../reports/issue-0357/report.md)) |
| Slow clients holding connections (slowloris) | Body at least 4 KB/s after 10 s; `/api/validate` ends after `RequestTimeoutSeconds` = 120 s (504); `MaxConnections` = 500; slow headers end after Kestrel's 30 s | `Program.cs` | ✅ `A_trickling_upload_is_stopped_by_the_request_timeout`; 300 B/s ended after 11 s ([#358](../../reports/issue-0358/report.md)) |
| A planted DLL picked up by a P/Invoke | DLLs are looked up in System32 only; `xpact.dll` by full path | `NativeSearchPath.cs` | ✅ CA5392 70 → 0 ([#360](../../reports/issue-0360/report.md)) |

## Security scan 2026-11-13

Full scan of the website: own attack battery (27 harmful-upload and protocol checks), OWASP ZAP 2.17.0 active scan, SonarQube, .NET security analyzers, Trivy, `npm audit`, NuGet advisories and gitleaks over the git history. 4 findings (#357-#360), all fixed and verified; after the fixes 27/27 checks pass, ZAP 0 high/medium/low, SonarQube 0 issues, 0 vulnerable dependencies, 0 secrets. Details and how to repeat: [scan report](../../reports/security-scan-2026-11-13/README.md).

## Security scan 2026-11-14

Before handing the Docker image to the supervisor ([report](../../reports/security-scan-2026-11-14/README.md)). Build `e0c3eab` = image `website-2026-11-14-2`.

| Check | Result |
|---|---|
| WAF (OWASP CRS 4.25, like Cloudflare/Azure managed rules) | ⚠️ blocks every **pasted** XML (XSS rules see `<tags>`); XXE in a file upload passes the WAF. → exclude `/api/validate` from the XSS rules if a WAF is used; the parser and worker are the real protection |
| Antivirus (Defender, ClamAV) | ⚠️ uploads are not scanned; scanners miss EICAR inside XML. Accepted: XML only, kept in memory, never stored or executed |
| SonarQube (.NET scanner, now including C#) | ✅ 76 → 0 issues (#371); 9 hotspots: 3 removed, 6 reviewed as safe (#380) |
| Attack battery · ZAP · nuclei · Semgrep · CodeQL · Snyk · Trivy · npm/NuGet | ✅ 27/27 · only "HTTP only" (local) · 0 · 0 · 0 · 0 real · 0 · 0 |
| Host filter | ✅ unknown host → 400; **set `AllowedHosts` at deployment** ([docker.md](docker.md#hosting-on-the-internet-safely)) |

## Known gaps before a public deployment

- [ ] HTTPS: terminate TLS at the host (IIS, a reverse proxy or App Service). Kestrel runs plain HTTP here. **Handled by the supervisor on the server.**
- [x] Behind a proxy, configure forwarded headers, so the rate limit sees the real client IP ([#224](https://github.com/andersoxie/xpact/issues/224)): automatic for a proxy on the same machine; list other proxies in `Xpact:KnownProxies`.
- [x] A proxy that is not trusted is no longer silent: the log names it once and says which setting to change; `Xpact:KnownNetworks` for proxies in a range; a mistyped address stops the start ([docker.md](docker.md#behind-a-reverse-proxy)). Tests: `Only_trusted_proxies_pass_on_the_visitor_address`, `A_mistyped_proxy_setting_stops_the_start_with_a_clear_message`.
- [ ] **At deployment:** follow [Hosting on the internet safely](docker.md#hosting-on-the-internet-safely) (image `website-2026-11-14-2` or newer, `AllowedHosts`, HTTPS via tunnel/proxy, WAF exclusion). Choose the proxy setting from the table in [docker.md](docker.md#behind-a-reverse-proxy) (supervisor's server).
- [x] Test the memory cap with a document that actually reaches it ([#227](https://github.com/andersoxie/xpact/issues/227)).
- [x] ✅ The worker runs with **no privileges at Low integrity** (#299, [report](../../reports/issue-0299/report.md)): it cannot write to the API account's files, registry or processes. A separate low-privilege Windows account (needs the hosting/supervisor) would add more; optional.
- [x] Load test: how many visitors at once before the 4-worker queue becomes slow ([load-test.md](load-test.md): ~31-40 requests/s, no failures up to 32 at once).

## Parser findings from the security tests

| Finding | Status | Report |
|---|---|---|
| Nested entity expansion ("billion laughs"): now stopped with Expat's error (code 43) in ~1.6 s; Expat ~0.1 s | 🟡 right error, slower | [#211](https://github.com/andersoxie/xpact/issues/211) · [report](../../reports/issue-0211/report.md) |

The website itself is safe from this finding: the time limit and memory cap contain it.

## Findings from the code review 2026-11-11

Code review of `website/` on `incremental-test` @ `7667a16`. ⚠️ **From reading the code only: none of these is tested or confirmed yet.**
Also checked the same day: `dotnet list package --vulnerable --include-transitive` (4 projects) and `npm audit` found no vulnerable packages; a search of all tracked files found no secrets. The Aikido "High" secret alerts are SHA-256 checksums of source files in `benchmarks/results/*.json` and `reports/**/*.json` (key name contains "token"), so false positives.

| # | Level | Finding | Where | Suggested fix | Status |
|---|---|---|---|---|---|
| 1 | Medium | The memory cap fails open: the worker starts first and is put under the Job Object afterwards; if that fails, only a warning is logged and the worker runs with no cap | `Workers/WorkerRunner.cs:92-101` | Stop the worker and return an error (fail closed) | ✅ fixed, tested (#295, [report](../../reports/issue-0295/report.md)) |
| 2 | Medium | One visitor can keep all 4 workers busy: 30 slow requests/min (billion laughs ~7 s, #211, or 1-byte pieces) = 210-300 worker-seconds per minute, the 4 workers have 240. Waiting requests queue with no limit or timeout, each holding up to ~20 MB in the API (no memory cap there) | `WorkerRunner.cs:45`, `Program.cs:20` | Wait for a worker with a timeout (503), cap the queue, and/or limit worker time per IP | ✅ fixed, tested: 2 workers per IP (429), 15 s wait and a queue of 32 (503) ([report](../../reports/issue-0297/report.md)) |
| 3 | Low | Up to 300 characters of the worker's error output and raw error messages go back to the visitor (can contain paths or stack traces) | `WorkerRunner.cs:118`, `Program.cs:104` | Generic message to the visitor, details in the server log | ✅ fixed, tested (#283, PR #288) |
| 4 | Low | The worker gets all of the API's environment variables | `WorkerRunner.cs:76` | Clear the worker's environment, pass only what it needs | ✅ fixed, tested (#283, PR #288) |
| 5 | Low | Any `Host` header is accepted (`AllowedHosts: "*"`) | `appsettings.json` | Set the real domain at deployment | ✅ localhost only (#283, PR #288); **set the real domain at deployment** |
| 6 | Low | No HSTS header | `Program.cs` | Add `Strict-Transport-Security` together with HTTPS (supervisor) | ✅ sent on HTTPS outside Development (#283, PR #288) |
| 7 | Info | The CSP still allows inline styles (`style-src 'unsafe-inline'`); scripts stay strict | `Program.cs:59` | Optional | ✅ removed (#286, PR #287); ZAP 0 medium |
