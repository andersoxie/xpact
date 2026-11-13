# #359 · Uploads over 64 KB were written to a temp file

| | |
|---|---|
| Status | ✅ **fixed and verified** locally (2026-11-13) · not yet in a release build |
| Issue | [#359](https://github.com/andersoxie/xpact/issues/359) · found by the [security scan 2026-11-13](../security-scan-2026-11-13/README.md) |
| Evidence | [test-ps1-2026-11-13.txt](test-ps1-2026-11-13.txt) · battery check "Upload-to-disk" in the scan |

## 1. Problem
[security.md](../../website/docs/security.md) says visitors' documents are never written to disk. A multipart upload over 64 KB was spooled by ASP.NET to `%TEMP%\ASPNETCORE_*.tmp` while the request ran (deleted afterwards).

- **Environment:** student PC, Windows 11 Home · `incremental-test` @ `e4e4c31` · site from `publish.ps1`, Production
- **Command:** battery check "Upload-to-disk": a 5 MB multipart upload while watching `%TEMP%` for `ASPNETCORE_*`
- **Expected:** no temp file. **Actual (before):** 1 temp file during the request.

## 2. Cause
✅ Confirmed: `FormOptions.MemoryBufferThreshold` default 64 KB.

## 3. Fix
`MemoryBufferThreshold` = the body limit: form files stay in memory. That memory is bounded by `UploadGate` (#357).

## 4. Verification

| check | before | after |
|---|---|---|
| Battery "Upload-to-disk" (5 MB, real Kestrel) | 🔴 1 temp file | ✅ 0 |
| New test `UploadInMemoryTests` (2 MB, `FileSystemWatcher` on the temp folder) | 🔴 fails with the fix removed | ✅ passes |
| `website\scripts\test.ps1` | 47 / 47 | ✅ **48 / 48** |
