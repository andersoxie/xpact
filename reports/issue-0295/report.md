# #295 Website: memory cap fails closed

| | |
|---|---|
| Branch | `fix/website-memory-cap-fail-closed` from `incremental-test` @ `0785dbf` |
| Environment | Student PC, Windows 11 Home, .NET 10, DLLs built 2026-11-11 (`xpact.dll` SHA-256 `02B7F95B803196B9…`) |
| Command | `.\website\scripts\test.ps1` (backend tests + frontend build) |

## Change
- `Workers/WorkerLimiter.cs`: `IWorkerLimiter`; `JobObjectWorkerLimiter` creates the Job Object and assigns the worker.
- `Workers/WorkerRunner.cs`: if the limit cannot be set → kill the worker, wait for its exit, log an error, return verdict `error` with a generic message. The document is never written to an uncapped worker. Lowering the priority has its own `try` (warning only).
- Test `Worker_is_stopped_when_the_memory_cap_cannot_be_set`: a limiter that throws `ERROR_ACCESS_DENIED`; checks verdict `error`, generic message, no Win32 details, worker process exited, normal limiter still works.

## Results
| Run | Result |
|---|---|
| New test on **fail-open** code (temporary change, reverted) | ❌ fails as it should: verdict `accepted`, expected `error` |
| `test.ps1` with the fix | ✅ 28/28 backend tests, frontend build ok ([log](test-website-2026-11-11.log)) |

## Limitations
- The failure is simulated with a test limiter; a real `AssignProcessToJobObject` failure was not produced on this PC.
- Between `Start` and the assignment the worker runs uncapped but idle (waiting for stdin). Starting it suspended would close that gap; not needed while it gets no input.
