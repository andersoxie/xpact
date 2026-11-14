# #358 · Slow uploads were never disconnected

| | |
|---|---|
| Status | ✅ **fixed and verified** locally (2026-11-13) · not yet in a release build |
| Issue | [#358](https://github.com/andersoxie/xpact/issues/358) · found by the [security scan 2026-11-13](../security-scan-2026-11-13/README.md) |
| Evidence | [slow.py](slow.py) · [test-ps1-2026-11-13.txt](test-ps1-2026-11-13.txt) |

## 1. Problem
A client could send its upload very slowly and keep the connection (and its buffer) open for hours: Kestrel's default minimum is 240 B/s and there was no total time limit. A 20 MB body at 300 B/s = ~18 h. Many such clients exhaust connections and memory.

- **Environment:** student PC, Windows 11 Home · `incremental-test` @ `83421c3` · site from `publish.ps1`, Production, real Kestrel on `:5099`
- **Command:** `python -I slow.py <port> <bytes per second> <seconds>`: headers with `Content-Length: 20000000`, then the given rate
- **Expected:** the connection is ended well before the upload could finish.

## 2. Cause
✅ Confirmed: Kestrel defaults (`MinRequestBodyDataRate` 240 B/s, no request timeout, unlimited connections).

## 3. Fix
- `MinRequestBodyDataRate` 4,096 B/s after a 10 s grace period.
- `/api/validate` has a total time limit, new setting `RequestTimeoutSeconds` (default 120 s: upload + queue + parse), then 504 and the request is cancelled.
- New setting `MaxConnections` (default 500).

## 4. Verification

| run (real Kestrel) | before | after |
|---|---|---|
| 300 B/s | 🔴 still open after 40 s | ✅ ended after **11 s** (400) |
| 8 KB/s (above the minimum rate) | 🔴 would run ~40 min | ✅ ended after **120 s** (504) |
| New test `SlowUploadTests` (real Kestrel, raw TCP, 2 s limit) | — | ✅ 504 after 2 s |
| `website\scripts\test.ps1` | 46 / 46 | ✅ **47 / 47** |

Not shown: the new test failing without the fix (it was written after the fix; the before/after runs above show the behaviour change).

## 5. Limits
- A visitor on a line slower than ~4 KB/s cannot upload; a 10 MB document needs ≥ ~85 KB/s to finish within 120 s.
- Request timeouts are not applied while a debugger is attached (ASP.NET Core rule).
