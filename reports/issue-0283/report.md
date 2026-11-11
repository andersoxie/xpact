# Issue #283: error details, worker environment, Host filter and HSTS

| Item | Value |
|---|---|
| Issue | [#283](https://github.com/andersoxie/xpact/issues/283) (label `bug`) |
| Branch | `fix/website-hardening`, from `incremental-test` @ `7667a16` |
| DLLs | `xpact.dll` `4513b4a2…`, `xpact_assertions.dll` `eb126628…` (2026-11-08 build, parser not changed) |
| Machine | student PC, Windows 11 Home, .NET SDK 10, Release build |
| Status | ✅ fixed and tested locally |

## Problem

Four gaps from the 2026-11-11 code review of `website/` (security.md findings 3-6), found by reading the code.

## Fix

| # | Gap | Fix | Test |
|---|---|---|---|
| 3 | Worker stderr (up to 300 chars), worker exception text and raw request-parsing errors went to the visitor | Fixed, generic messages; the details go to the server log (`LogWarning` / `LogInformation`); the worker writes exceptions to stderr only | `Unreadable_requests_get_a_fixed_message`; `The_memory_cap_stops_a_worker_that_needs_more` now also checks that "PANIC" is not in the reply |
| 4 | The worker got every environment variable of the API | `WorkerRunner.LimitEnvironment`: only system variables Windows and .NET need (SystemRoot, PATH, TEMP, …) | `The_worker_gets_only_system_environment_variables`; all end-to-end tests still run the real worker |
| 5 | `AllowedHosts: "*"` | `localhost;127.0.0.1;[::1]`. **At deployment set the real domain**, e.g. `AllowedHosts=xpact.example.com` (environment variable); otherwise the site answers 400 | `Unknown_host_names_are_refused` |
| 6 | No HSTS | `UseHsts()` outside Development, max-age 1 year; sent only on HTTPS (behind a proxy via `X-Forwarded-Proto`) | `Hsts_is_sent_on_https_outside_development` |

## Verification

| Run | Result |
|---|---|
| Baseline, unchanged code (`incremental-test` @ `7667a16`) | 22 / 22 passed |
| This branch, `dotnet test website\backend\Xpact.Web.slnx -c Release` | **26 / 26 passed** ([backend-tests.txt](backend-tests.txt)) |
| Published site, `ASPNETCORE_ENVIRONMENT=Production`, `http://localhost:5099` | pages load (Lighthouse run of #286 used this build first) |

## Limitations

- The new tests were not run against the old code to watch them fail first.
- HTTPS itself is the supervisor's (#210); HSTS only works once the site runs on HTTPS.
- `AllowedHosts` must be set at deployment (see above); the Docker smoke test (#284) uses `localhost`, which is allowed.
