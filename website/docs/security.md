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
| Click-jacking, MIME sniffing, leaking referrers | `X-Frame-Options: DENY`, `frame-ancestors 'none'`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, a strict CSP without `'unsafe-inline'` and with `base-uri`, `form-action`, `object-src`; `Permissions-Policy`, `Cross-Origin-Opener-Policy`; no `Server` header | `Program.cs` | ✅ `Security_headers_are_set`; OWASP ZAP 2.17.0: 0 medium/high ([#286](https://github.com/andersoxie/xpact/issues/286)) |
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
