# #299 Website: worker with no privileges at Low integrity

| | |
|---|---|
| Branch | `fix/website-low-integrity-worker` from `incremental-test` @ `6c4df1b` |
| Environment | Student PC, Windows 11 Home, normal user account, .NET 10, DLLs built 2026-11-11 (`xpact.dll` SHA-256 `02B7F95B803196B9…`) |
| Command | `.\website\scripts\test.ps1`; load test `website\backend\tests\tools\load-test.py` against `website\dist` |

## Change
- New `Workers/WorkerLauncher.cs`: `CreateProcessAsUser` with a copy of the API token, `CreateRestrictedToken(DISABLE_MAX_PRIVILEGE)` (only `SeChangeNotifyPrivilege` left) and integrity level **Low** (`S-1-16-4096`). Started **suspended**, below-normal priority, no window, own environment block, only its 3 pipe handles inherited (launches serialised so no worker inherits another's pipe).
- `WorkerRunner`: start suspended → Job Object (memory cap) → resume. The worker runs no code before it is capped (closes the small gap noted in #295). Fail closed: if the launch fails, verdict `error`, details only in the log.
- Setting `WorkerLowIntegrity` (default `true`); `false` = same launcher at normal integrity.

## Results
| Check | Result |
|---|---|
| Worker's token while suspended (`Worker_runs_at_low_integrity_without_privileges`) | ✅ integrity `0x1000` (Low), ≤ 1 privilege; with the setting off: Medium or higher |
| `cmd /c echo x>%TEMP%\…` started by the launcher | ✅ Low: **no file** · normal: file written (control) · Low into `AppData\LocalLow`: file written (control: the command runs, only the integrity level stops it) |
| Launch fails (`Nothing_is_parsed_when_the_worker_cannot_be_started_with_reduced_rights`) | ✅ verdict `error`, generic message |
| `test.ps1` | ✅ 37/37 backend tests, frontend build ok ([log](test-website-2026-11-11.txt)) |
| Load test, 1-32 visitors × 64 requests (per-client cap raised) | ✅ 256/256 accepted, no hang, no errors in the API log |

### Speed (16 visitors, 96 requests, 3 alternating runs; PC not idle)
| | req/s (median) |
|---|---:|
| old code (`incremental-test` @ `6c4df1b`) | 23.7 |
| new, Low integrity | 23.8 |
| new, `WorkerLowIntegrity=false` (separate run) | 22.5 vs Low 22.4 |

No measurable cost. Lower than the 31-40 req/s in `load-test.md` on both old and new code, so that difference comes from the PC, not this change.

## Limitations
- Tested on Windows 11 Home under a normal user. Not tested under IIS / an app-pool identity or as a Windows service; if `CreateProcessAsUser` is refused there, requests fail closed with `error` and `WorkerLowIntegrity=false` is the switch.
- Low integrity limits **writing** up the integrity levels; the worker can still **read** files the account can read. A separate Windows account (supervisor) would limit reading too.
- Command-line quoting for paths with spaces follows the Windows rules but is not tested with such a path.
