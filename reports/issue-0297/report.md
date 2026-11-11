# #297 Website: per-client worker cap, queue wait timeout and queue cap

| | |
|---|---|
| Branch | `fix/website-worker-queue` from `incremental-test` @ `a85620a` |
| Environment | Student PC, Windows 11 Home, .NET 10, DLLs built 2026-11-11 (`xpact.dll` SHA-256 `02B7F95B803196B9…`) |
| Command | `.\website\scripts\test.ps1` (backend tests + frontend build) |

## Change
| Setting | Default | When exceeded |
|---|---|---|
| `MaxWorkersPerClient` | 2 | `429 Too many documents at once`, `Retry-After: 5` |
| `QueueWaitSeconds` | 15 | `503 Server busy`, `Retry-After: 10` |
| `MaxQueuedRequests` | 32 | `503 Server busy` at once, `Retry-After: 10` |

- `WorkerRunner.RunAsync`: per-client count (key = remote IP, the same as the rate limiter), then a free slot at once or a bounded, timed wait; `WorkerBusyException` → problem details in `Program.cs`.
- The frontend already shows the `title`/`detail` of any problem response; no frontend change.
- Tests use a "gate" limiter that holds a worker busy until the test releases it (no timing on slow XML).

## Results
| Run | Result |
|---|---|
| The 3 new tests against the **old** behaviour (temporary change, reverted) | ❌ all 3 fail as they should (`200` instead of `429`; queued requests waited instead of `503`) |
| `test.ps1` with the fix | ✅ 31/31 backend tests, frontend build ok ([log](test-website-2026-11-11.txt)) |

## Limitations
- Behind a NAT or company proxy, many visitors share one IP and so share 2 workers; raise `MaxWorkersPerClient` if that is a problem.
- Not load-tested again; `load-test.md` explains which settings to raise for a one-machine load test.
- Worker *time* per IP (the third option in the finding) is not limited; the 2-worker cap bounds it to 2 × 10 s at a time.
