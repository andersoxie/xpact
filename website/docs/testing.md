# Test record

[← website README](../README.md)

The baseline of the website, in the CLAUDE.md test-report format. Add a new section for each run; never overwrite an old one.

## Run 1: 2026-11-02, first complete version ✅

### Revision and configuration

| Item | Value |
|---|---|
| Revision | `student-Mass` @ `22876e9` + the uncommitted `website/` folder |
| Machine | student PC 2, Windows 11 (16 logical cores) |
| Parser | `xpact.dll` (production, SHA-256 `35460E77DDC74083…`) and `xpact_assertions.dll` (`68EF303C17D0C182…`), built 2026-11-02 with `scripts/build_native_eiffel.ps1`, EiffelStudio 25.12, `msc_vc140`; DLL smoke test ok for both |
| Backend | .NET SDK 10.0.300, Release, x64 |
| Frontend | Node 24.19, Vite 8.3, TypeScript 7.0, React 19.3 |
| Assertions | both builds tested: the end-to-end tests run every document through **both** `production` and `assertions` where it matters |

### Commands and results

| # | Command | Result |
|---|---|---|
| 1 | `.\website\scripts\build-dll.ps1` | ✅ both DLLs built, smoke ok, copied to `backend/native` |
| 2 | `python website\scripts\export-data.py` | ✅ `conformance.json`, `benchmarks.json` (10 rows), `comparison.json` |
| 3 | `.\website\scripts\test.ps1` | ✅ backend **19 / 19 passed**; frontend type check and build ok |
| 4 | `.\website\scripts\publish.ps1` | ✅ `website/dist` with the API, worker, DLLs, data and site |
| 5 | browser QA on the published site (headless Chromium, 5 pages, validator flows) | ✅ all pages render; 0 console errors; 0 failed requests |
| 6 | screenshots: validator (light), home and benchmarks (dark), validator at 390 px | ✅ no overflow (page width 390 px), error line marked, chart labelled |

### What the 19 backend tests check (expected → observed)

| Test | Input | Expected | Observed |
|---|---|---|---|
| Health and info | — | both builds available | ✅ |
| Well-formed (×2 builds) | XML declaration, comment, attribute, text, PI | accepted; 2 start, 2 end, 1 comment, 1 PI; text `hello` | ✅ |
| Mismatched tag | `<root>\n  <child>\n</root>` | rejected, code 7, line 3 | ✅ |
| Invalid documents | empty, `<root>`, `<root/>junk`, duplicate attribute | `400`, code 3, code 9, code 8 | ✅ |
| Invalid UTF-8 | `<a>` `C3 28` `</a>` | rejected | ✅ |
| File upload | multipart, assertions build | accepted, 33 bytes | ✅ |
| Chunk independence (×3 docs) | chunk sizes 1, 2, 3, 7 | same verdict, code and start count as whole | ✅ |
| External entities | entity → `file:///C:/Windows/win.ini` | no text reaches the result | ✅ |
| Bad requests | unknown build, chunk −1, 2 KB over a 1 KB limit | `400`, `400`, `413` | ✅ |
| Slow documents | entities expanding to ~10⁹ bytes, timeout 3 s | rejected, timeout or crashed, in < 8 s | ✅ |
| Results endpoint | `conformance`, `benchmarks`, `appsettings` | `200`, `200`, `404` | ✅ |
| Rate limit | 3 requests, limit 2 / min | `200`, `200`, `429` | ✅ |
| Security headers | — | `nosniff`, `DENY` | ✅ |

### Parser events

The result's `events.sample` lists the parser events. Example from the browser QA, the default sample (the catalog document): 25 event rows, 9 start tags, 9 end tags, 17 text runs (whitespace counted, not listed), 1 comment.

### Known failures and problems met

| # | Problem | Cause | Status |
|---|---|---|---|
| 1 | One test first failed: `<root>` expected code 5, got 3 | ✅ confirmed: **my expectation was wrong**. At the end of input Expat also reports 3 "no element found"; XPact matches Expat | test corrected |
| 2 | Local checks on port 8080 got 404 pages | ✅ confirmed: Apache `httpd` listens on 8080 on this PC | site uses 5099 |
| 3 | Nested entity expansion rejected after ~7 s as "syntax error" (Expat: ~0.1 s, amplification limit) | ❓ suspected parser limit reached late; not investigated | ⬜ open: [#211](https://github.com/andersoxie/xpact/issues/211) ([report](../../reports/issue-0211/report.md)) |

### Limitations of this baseline

- [ ] Not deployed; tested on `localhost` only.
- [ ] The memory cap (Job Object) was not triggered by any test.
- [ ] No load test (many visitors at once).
- [ ] The frontend has no unit tests; it is checked by the type check, the build and the browser QA.
- [ ] The Postman collection was written but not run in Postman; the same requests are covered by the xUnit tests.
