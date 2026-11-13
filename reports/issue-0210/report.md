# Report: issue #210: the XPact website

Issue: [#210](https://github.com/andersoxie/xpact/issues/210) · Branch: `fix/210-xpact-website` · Base: `student-Mass` @ `22876e9` · Date: 2026-11-02
Status: 🟡 pull request open · ⬜ not deployed

> **In short:** `website/` now holds a working website. Visitors upload or paste XML and see XPact's verdict, error position and parser events. It also has docs, W3C and benchmark results, and project links. Everything was tested locally: **19 / 19** backend tests, and browser QA with **0** console errors. The parser was **not** changed.

## 1. What was built

| Guide component | Built as | Folder |
|---|---|---|
| Frontend | React 19 + TypeScript (Vite); pages Home, Validator, Documentation, Benchmarks, Project; light/dark; phone layout | [`website/frontend/`](../../website/frontend/) |
| Backend | ASP.NET Core (.NET 10): `POST /api/validate` (file, JSON or raw XML), `/api/info`, `/api/health`, `/api/results/{name}` | [`website/backend/src/Xpact.Api/`](../../website/backend/src/Xpact.Api/) |
| Worker | One process per document; P/Invoke into the Expat C API of `xpact.dll`; Job Object (512 MB), 10 s timeout | [`website/backend/src/Xpact.Worker/`](../../website/backend/src/Xpact.Worker/) |
| Parser | `xpact.dll` and `xpact_assertions.dll`, **unchanged**, built by `scripts/build_native_eiffel.ps1` | — |
| Results | JSON results; conformance, benchmark and Expat-comparison numbers exported from `reports/` | [`website/data/`](../../website/data/), [`export-data.py`](../../website/scripts/export-data.py) |

Website documentation, simple first and more detail further in: [website/README.md](../../website/README.md) → [docs/](../../website/docs/README.md): architecture, API, security, development, testing, roadmap.

## 2. Configuration

| Item | Value |
|---|---|
| Machine | student PC 2, Windows 11, 16 logical cores |
| Revision | `student-Mass` @ `22876e9` + this branch |
| Parser DLLs | built 2026-11-02, EiffelStudio 25.12, `msc_vc140`; smoke test ok for both; `xpact.dll` SHA-256 `35460E77DDC74083…`, `xpact_assertions.dll` `68EF303C17D0C182…` |
| Assertions | the end-to-end tests run documents through **both** builds |
| Tools | .NET SDK 10.0.300 · Node 24.19 · Vite 8.3 · TypeScript 7.0 · React 19.3 |

## 3. Commands and results

| # | Command | Result | Log |
|---|---|---|---|
| 1 | `.\website\scripts\build-dll.ps1` | ✅ both DLLs built, smoke ok | in the console |
| 2 | `python website\scripts\export-data.py` | ✅ 3 data files (W3C: 2,585 cases; 10 benchmark rows; Expat comparison 1,302 pairs) | — |
| 3 | `.\website\scripts\test.ps1` | ✅ backend **19 / 19**; frontend type check and build ok; exit 0 | [logs/test.txt](logs/test.txt) |
| 4 | `.\website\scripts\publish.ps1` | ✅ `website/dist`; exit 0 | [logs/publish.txt](logs/publish.txt) |
| 5 | browser QA on the published site ([qa.mjs](logs/qa.mjs)) | ✅ 5 pages render; validator: accepted / rejected (code 7, line 3 marked) / same verdict byte by byte; **0 console errors, 0 failed requests** | [logs/browser-qa.txt](logs/browser-qa.txt) |
| 6 | screenshots ([shots.mjs](logs/shots.mjs)) | ✅ no overflow at 390 px; dark mode | [screenshots/](screenshots/) |

What each of the 19 tests checks, expected vs observed: [website/docs/testing.md](../../website/docs/testing.md#what-the-19-backend-tests-check-expected--observed).

### Valid and invalid XML (from the tests)

| Input | Expected | Observed |
|---|---|---|
| declaration + comment + attribute + text + PI (both builds) | accepted; 2 start, 2 end, 1 comment, 1 PI | ✅ |
| `<root>\n  <child>\n</root>` | rejected, code 7 "mismatched tag", line 3 | ✅ |
| `<root>` | rejected, code 3 (as Expat) | ✅ |
| `<root/>junk` | rejected, code 9 (#124) | ✅ |
| duplicate attribute | rejected, code 8 | ✅ |
| `C3 28` (invalid UTF-8) | rejected | ✅ |
| 3 documents × chunk sizes 1, 2, 3, 7 | same verdict, code and start-tag count as whole | ✅ |
| entity → `file:///C:/Windows/win.ini` | file not read | ✅ |

## 4. Problems met (kept separate)

### P1: one test expectation was wrong
1. **Problem:** `Invalid_documents_are_rejected("<root>", 5)` failed.
2. **Environment:** as in §2.
3. **Command:** `dotnet test website\backend\Xpact.Web.slnx -c Release`
4. **Expected (my test):** code 5.
5. **Actual:** code 3.
6. **Error output:** `Assert.Equal() Failure: Expected: 5 Actual: 3`
7. **Investigation:** Expat also reports `XML_ERROR_NO_ELEMENTS` (3) for an unclosed root at the end of input.
8. **Cause:** ✅ confirmed: my expectation, not XPact.
9. **Fix:** the test now expects 3.
10. **Verification:** 19 / 19.

### P2: port 8080 is taken on this PC
1. **Problem:** local checks on `http://127.0.0.1:8080` returned 404 pages, and `/api/health` came back as HTML.
2. **Environment:** student PC 2.
3. **Command:** `Xpact.Api.exe --urls http://127.0.0.1:8080`, then `Invoke-WebRequest`.
4. **Expected:** the site.
5. **Actual:** another server answered.
6. **Error output:** `404 Not Found … The requested URL was not found on this server.`
7. **Investigation:** `Get-NetTCPConnection -LocalPort 8080` shows the owner is `httpd`.
8. **Cause:** ✅ confirmed: Apache `httpd` listens on 8080.
9. **Fix:** the site uses 5099; the scripts and docs say so.
10. **Verification:** all routes are correct on 5099.

### P3: a parser finding, with its own issue
Nested entity expansion is rejected after ~7 s as "syntax error"; Expat stops it in ~0.1 s → [#211](https://github.com/andersoxie/xpact/issues/211), [report](../issue-0211/report.md). The website contains it with its time and memory limits.

## 5. Limitations

- [ ] Not deployed (guide phase 7): HTTPS, forwarded headers and a low-privilege worker account are still to do ([security.md](../../website/docs/security.md#known-gaps-before-a-public-deployment)).
- [ ] The memory cap was not triggered by any test; no load test.
- [ ] The frontend has no unit tests (type check, build and browser QA only).
- [ ] The Postman collection was not run in Postman; the same requests are covered by the xUnit tests.
- [ ] The benchmark numbers on the site are from `docs/benchmarks.md` (2026-06-21); they are not re-measured.

*Update 2026-11-11:* forwarded headers are done (#224); the memory cap is tested (#227) and a load test is done ([load-test.md](../../website/docs/load-test.md), #255). HTTPS is the supervisor's. The list above is the state when this report was written.

## 6. Next

- [x] Review and merge the pull request into `student-Mass` *(done: PR #212, 2026-11-02)*
- [ ] Decide on hosting (a Windows VM, as the guide suggests) and deploy
- [ ] [#211](https://github.com/andersoxie/xpact/issues/211) in the parser
