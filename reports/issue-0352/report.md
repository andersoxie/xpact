# #352 · #353 · Uploading a ~10 MB file on the website

| | |
|---|---|
| Status | ✅ **fixed and verified** locally (2026-11-12) · not yet in a release build / Docker image |
| Issues | [#352](https://github.com/andersoxie/xpact/issues/352) page freezes (bug) · [#353](https://github.com/andersoxie/xpact/issues/353) timeout without a hint (limit, by design) |
| Evidence | [ui-results.txt](ui-results.txt) · [test-ps1-2026-11-12.txt](test-ps1-2026-11-12.txt) · scripts [mk.py](mk.py), [ui.js](ui.js), [ui2.js](ui2.js) |

## 1. Environment
Student PC, Windows 11 Home · `incremental-test` @ `b3efae6` · API + worker + DLL from `website\dist` (release `website-2026-11-12-1`, `xpact.dll` `ADAE03D2…`, unchanged) · Edge headless via `playwright-core` 1.49.1 · old site on :5099, same dist with the new frontend on :5098.

Test files (made with `mk.py <out> <bytes>`): `doc1.xml` 1,000,000 B, `doc9_9.xml` 9,900,000 B, `doc10mib.xml` 10,485,760 B (= the limit), `bad.xml` (first 10,000,000 B of `doc10mib.xml` + `<oops></root>`: not well-formed).

## 2. Two separate problems

### #352 · ✅ Page freezes (frontend bug)
- **Cause (confirmed):** `XmlEditor` renders one gutter row and one highlight row per line. 10 MiB ≈ 205,000 lines ≈ 410,000 DOM nodes.
- **Fix:** files over 256 KB are shown as a **read-only preview** of the first 256 KB, with a note; the whole file is still sent. "×" on the file chip clears the preview.

| `node ui.js <port> <file>` | load | gutter rows | validate |
|---|---|---|---|
| old, 1 MB | 4,888 ms | 19,611 | accepted, 2.5 s |
| ✅ new, 1 MB | 763 ms | 5,142 | accepted, 1.9 s |
| old, 10 MiB | 🔴 page frozen: Validate click timed out after 30 s | | |
| ✅ new, 10 MiB | 745 ms | 5,142 | accepted, 4.4 s |
| ✅ new, `bad.xml` (invalid) | | | rejected, code 4, line 196,080 (after the preview) |

### #353 · ✅ Timeout gives no hint (limit by design)
API alone (`curl -F file=@<f> -F build=<b> -F chunkSize=<c> http://localhost:5099/api/validate`), `TimeoutSeconds` = 10:

| document | build | pieces | result |
|---|---|---|---|
| 1 MB | production | whole / 4096 | accepted 0.35 s / 0.51 s |
| 1 MB | assertions | whole / 4096 | accepted 3.8 s / 4.4 s |
| 9.9 MB, 10 MiB | production | whole / 4096 | accepted 3.1-3.5 s / 4.1-4.2 s |
| 10 MiB | production | 1 B | ⏱ timeout |
| 9.9 MB, 10 MiB | assertions | whole / 4096 | ⏱ timeout (~40 s needed) |

- **Cause (confirmed):** the 10 s limit vs. the assertions build (~10× slower) and 1-byte pieces. Not a parser fault.
- **Fix:** a timeout result now says why and suggests the production build in one piece or pieces ≥ 4096 B (verified: `ui2.js`).
- ❓ **Open (Anders):** raise `TimeoutSeconds` for the assertions build? Deployment decision, not changed.

## 3. Verification
- [x] ✅ Frontend build (`npm run build`, includes `tsc`)
- [x] ✅ `website\scripts\test.ps1`: 42/42 backend tests, all website checks passed
- [x] ✅ Headless Edge: valid 1 MB and 10 MiB accepted, invalid 10 MB rejected with line, timeout hint shown
- [ ] Next website release + Docker image (student runs `gh release create`, see [#345](../issue-0345/report.md))
