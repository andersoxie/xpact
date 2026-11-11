# Security

[← website README](../README.md)

The site runs a parser on documents from strangers. These are the protections, and what has been tested.

## Protections

| Risk | Protection | Where | Tested |
|---|---|---|---|
| Reading server files or URLs through external entities (XXE) | No `ExternalEntityRefHandler` and no parameter-entity parsing are set, so the parser never opens a file or URL named in the document | `Xpact.Worker/Program.cs` | ✅ `External_entities_are_never_loaded` (an entity pointing to `C:\Windows\win.ini` stays empty) |
| A parser crash taking the site down | One worker **process** per document | `WorkerRunner.cs` | ✅ verdict `crashed` is handled; the worker pattern is the one used by `tests/dotnet/XpactDllTests` |
| Endless parsing (CPU) | Worker killed after 10 s; below-normal priority | `WorkerRunner.cs` | ✅ `Slow_documents_are_stopped_by_the_timeout` |
| Memory exhaustion | Windows Job Object, 512 MB per worker | `Workers/JobObject.cs` | ✅ `The_memory_cap_stops_a_worker_that_needs_more` (#227): under a 40 MB cap a nested-entity document stops the worker (`crashed`); the API keeps serving |
| Huge uploads | Documents up to 10 MB (the parser's own limit); request body at most 2 × 10 MB + 64 KB (JSON escaping); `413` above. A 10 MB document needs about 175-250 MB in the worker (measured 2026-11-10), below the 512 MB cap | `Program.cs` | ✅ `Bad_requests_are_refused` |
| Request floods | Rate limit, 30 / min per IP; at most 4 workers at once | `Program.cs` | ✅ `Requests_are_rate_limited_per_client` |
| One visitor using up the limit for everyone behind a proxy | `X-Forwarded-For` is read from a proxy on this machine or one in `Xpact:KnownProxies` only, so the limit counts each real visitor and visitors cannot fake their address | `Program.cs` | ✅ `Visitors_behind_a_proxy_are_rate_limited_separately` |
| Reading other files through the results endpoint | Allowed names only: `conformance`, `benchmarks`, `comparison`, `testing` | `Program.cs` | ✅ `Results_files_are_served_and_names_are_checked` |
| Click-jacking, MIME sniffing, leaking referrers | `X-Frame-Options: DENY`, `frame-ancestors 'none'`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, a strict CSP | `Program.cs` | ✅ `Security_headers_are_set` |
| Storing visitors' documents | Nothing is written to disk; the document goes to the worker on stdin; logs record size, build, verdict and time only | `WorkerRunner.cs` | ✅ by design (code review) |

## Known gaps before a public deployment

- [ ] HTTPS: terminate TLS at the host (IIS, a reverse proxy or App Service). Kestrel runs plain HTTP here. **Handled by the supervisor on the server.**
- [x] Behind a proxy, configure forwarded headers, so the rate limit sees the real client IP ([#224](https://github.com/andersoxie/xpact/issues/224)): automatic for a proxy on the same machine; list other proxies in `Xpact:KnownProxies`.
- [x] Test the memory cap with a document that actually reaches it ([#227](https://github.com/andersoxie/xpact/issues/227)).
- [ ] Run the worker under a low-privilege Windows account (today it inherits the API's account).
- [x] Load test: how many visitors at once before the 4-worker queue becomes slow ([load-test.md](load-test.md): ~31-40 requests/s, no failures up to 32 at once).

## Parser findings from the security tests

| Finding | Status | Report |
|---|---|---|
| Nested entity expansion ("billion laughs") is rejected after ~7 s as "syntax error"; Expat rejects it in ~0.1 s as "amplification limit breached" | ⬜ open | [#211](https://github.com/andersoxie/xpact/issues/211) · [report](../../reports/issue-0211/report.md) |

The website itself is safe from this finding: the time limit and memory cap contain it.

## Findings from the code review 2026-11-11

Code review of `website/` on `incremental-test` @ `7667a16`. ⚠️ **From reading the code only: none of these is tested or confirmed yet.**
Also checked the same day: `dotnet list package --vulnerable --include-transitive` (4 projects) and `npm audit` found no vulnerable packages; a search of all tracked files found no secrets. The Aikido "High" secret alerts are SHA-256 checksums of source files in `benchmarks/results/*.json` and `reports/**/*.json` (key name contains "token"), so false positives.

| # | Level | Finding | Where | Suggested fix | Status |
|---|---|---|---|---|---|
| 1 | Medium | The memory cap fails open: the worker starts first and is put under the Job Object afterwards; if that fails, only a warning is logged and the worker runs with no cap | `Workers/WorkerRunner.cs:92-101` | Stop the worker and return an error (fail closed) | ⬜ suspected |
| 2 | Medium | One visitor can keep all 4 workers busy: 30 slow requests/min (billion laughs ~7 s, #211, or 1-byte pieces) = 210-300 worker-seconds per minute, the 4 workers have 240. Waiting requests queue with no limit or timeout, each holding up to ~20 MB in the API (no memory cap there) | `WorkerRunner.cs:45`, `Program.cs:20` | Wait for a worker with a timeout (503), cap the queue, and/or limit worker time per IP | ⬜ suspected |
| 3 | Low | Up to 300 characters of the worker's error output and raw error messages go back to the visitor (can contain paths or stack traces) | `WorkerRunner.cs:118`, `Program.cs:104` | Generic message to the visitor, details in the server log | ⬜ suspected |
| 4 | Low | The worker gets all of the API's environment variables | `WorkerRunner.cs:76` | Clear the worker's environment, pass only what it needs | ⬜ suspected |
| 5 | Low | Any `Host` header is accepted (`AllowedHosts: "*"`) | `appsettings.json` | Set the real domain at deployment | ⬜ open |
| 6 | Low | No HSTS header | `Program.cs` | Add `Strict-Transport-Security` together with HTTPS (supervisor) | ⬜ open |
| 7 | Info | The CSP still allows inline styles (`style-src 'unsafe-inline'`); scripts stay strict | `Program.cs:59` | Optional | ⬜ open |
