# #357 · Upload body read into memory before any limit

| | |
|---|---|
| Status | ✅ **fixed and verified** locally (2026-11-13) · not yet in a release build |
| Issue | [#357](https://github.com/andersoxie/xpact/issues/357) · found by the [security scan 2026-11-13](../security-scan-2026-11-13/README.md) |
| Evidence | [flood.py](flood.py) · [test-ps1-2026-11-13.txt](test-ps1-2026-11-13.txt) |

## 1. Problem
`/api/validate` read the whole body (up to 20 MB, plus copies) **before** the per-visitor limit (429) and the queue limit (503) were checked. Refused requests still cost their full body in RAM.

- **Environment:** student PC, Windows 11 Home · `incremental-test` @ `a177d8d` · site from `website\scripts\publish.ps1`, Production · DLL `ADAE03D2…` (unchanged)
- **Command:** `python -I flood.py <port> <n> [multi]`: n parallel POSTs of a 21 MB JSON body (10 MB of quotes, doubled by JSON escaping); `multi` = a different `X-Forwarded-For` per thread (trusted from localhost) = many visitors
- **Expected:** memory bounded; refused uploads cost nothing.

## 2. Cause
✅ Confirmed: `ValidateInput.ReadAsync` buffered the body (MemoryStream → ToArray, JSON string → UTF-8) before `WorkerRunner` checked its limits.

## 3. Fix
- New `UploadGate` (`Workers/UploadGate.cs`), checked **before** the body is read:
  per visitor at most `MaxWorkersPerClient` uploads in flight (429); the bodies in memory stay within the new setting `MaxBufferedMb` (default 256 MB; each upload reserves 4× its `Content-Length`, or 4× the largest body when unknown) (503). A single upload larger than the budget still runs when nothing else does. `Content-Length` over the body limit → 413 at once.
- Fewer copies: a form file and a raw body with `Content-Length` are read into one exactly sized array.

## 4. Verification

| run | before | after |
|---|---|---|
| 30 × 21 MB from one IP, defaults | 🔴 1,706 MB peak (measured with 4 per visitor) | ✅ **237 MB**, 2 × 200, 28 × 429 |
| 30 × 21 MB from one IP, 4 per visitor | 🔴 1,706 MB | ✅ 422 MB |
| 60 × 21 MB from 60 IPs, defaults | 🔴 not run before (≈ 60 × 57 MB ≈ 3.4 GB expected) | ✅ **348 MB**, 3 × 200, 57 × 503 in 1.6 s |
| 10 MB document as JSON (browser-style escaping), raw, form | ✅ accepted | ✅ accepted |
| `website\scripts\test.ps1` | 42 / 42 | ✅ **46 / 46** (+4 `UploadGateTests`) |

**Test change:** `Documents_up_to_10_MB_are_accepted` posted JSON with .NET's default encoder (`<` → `\u003C`, ~30 MB for this document). Kestrel always refused that body (2× limit); the in-process test host does not enforce Kestrel's limit, so the test passed only there. It now escapes like the site's page (`JSON.stringify`, ≤ 2×).

## 5. Limits
- During a flood, honest visitors also get 503 until memory is free; the budget protects the server, not each visitor.
- Many IPs remain a network-level problem for the reverse proxy (supervisor).
