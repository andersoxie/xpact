# G03: xpact vs Expat 2.8.1 across chunks (G01 subset)

> **Issue:** [#169](https://github.com/andersoxie/xpact/issues/169) (task G03, week 7) · **Date:** 2026-10-31
> **Revision:** `f985102` (`student-Mass` = `main` + #166) · **Findings:** [#170](https://github.com/andersoxie/xpact/issues/170)-[#176](https://github.com/andersoxie/xpact/issues/176)
> **Status:** ✅ done · no code change to xpact
> **Since then (2026-10-31):** the findings [#172](https://github.com/andersoxie/xpact/issues/172), [#173](https://github.com/andersoxie/xpact/issues/173), [#174](https://github.com/andersoxie/xpact/issues/174), [#175](https://github.com/andersoxie/xpact/issues/175) are fixed (each fix report has its G03 rerun: `valid-sa-079`, `ibm-valid-P11-ibm11v02.xml`, `ibm-not-wf-P51-ibm51n06.xml` match; `o-p02fail15/27` now differ only in position, [#171](https://github.com/andersoxie/xpact/issues/171)). The table below is the state on `f985102`; a rerun on the fixed code is planned.

## 🚦 In short

| | Result |
|---|---|
| ✅ **Verdict** (accept / reject) | **the same as Expat in all 1,302 configuration pairs** (93 cases × 14 ways of feeding) |
| ✅ Against the W3C expectation (83 counted cases) | xpact **81 / 83**, Expat **81 / 83**: the same 2 misses (5th-edition names, see [below](#the-2-expectation-misses)) |
| ✅ Totals reconcile | every configuration, both engines: **48 ACCEPT + 45 REJECT = 93**; no crash, no timeout, no missing row |
| 🟡 **Everything the same** (verdict, error code, events, position) | **59 / 93** cases (52 counted + 7 marked) |
| 🔴 Differences | **34 cases**, 7 kinds, each filed as one finding: [#170](https://github.com/andersoxie/xpact/issues/170)-[#176](https://github.com/andersoxie/xpact/issues/176) |
| ✅ Both xpact builds | `xpact_assertions.dll` and `xpact.dll`: **identical** on every row |

**In one sentence:** xpact always gives Expat's verdict, however the input arrives; where they differ it is the error code (14 cases), the error position (14) or the events (6).

## 📊 The comparison table

Status per case, worst first (a case counts once, under its worst difference):

| Status | Counted (83) | Marked (10) | Total | Finding |
|---|---:|---:|---:|---|
| ✅ match: verdict, error code, events and position the same in all 14 configurations | 52 | 7 | **59** | |
| 🔴 verdict differs | 0 | 0 | **0** | |
| 🟠 error code differs | 13 | 1 | **14** | [#170](https://github.com/andersoxie/xpact/issues/170) |
| 🟡 events differ | 6 | 0 | **6** | [#172](https://github.com/andersoxie/xpact/issues/172)-[#176](https://github.com/andersoxie/xpact/issues/176) |
| 🟡 only the error position differs | 12 | 2 | **14** | [#171](https://github.com/andersoxie/xpact/issues/171) |
| 💥 crash or timeout | 0 | 0 | **0** | |
| **Total** | **83** | **10** | **93** | |

Per configuration: **1,042 of 1,302** pairs give the same verdict, error code and events.

<details>
<summary>📋 The 7 kinds of difference (click)</summary>

| ID | Finding | What differs | Cases | Depends on chunking? |
|---|---|---|---:|---|
| G03-1 | [#170](https://github.com/andersoxie/xpact/issues/170) | **error code**, e.g. `not-wf-sa-101`: xpact 18 *unknown encoding*, Expat 30 *XML declaration not well-formed* | 14 | no |
| G03-2 | [#171](https://github.com/andersoxie/xpact/issues/171) | **error column 0** where Expat points at the token (22 of 32 rejections; line right in 29 of 32) | 14 only this, more together with G03-1 | no |
| G03-3 | [#172](https://github.com/andersoxie/xpact/issues/172) | parsed **whole**: no events before an invalid-character error; in pieces xpact gives `start doc`, as Expat (= **F02-2** of the W3C-in-pieces test) | 2 | **yes** (xpact only) |
| G03-4 | [#173](https://github.com/andersoxie/xpact/issues/173) | error in the internal DTD subset reported at the `<!DOCTYPE` line (2:0), before 3 earlier `elementdecl` events; Expat: 7:33 after them | 1 | no |
| G03-5 | [#174](https://github.com/andersoxie/xpact/issues/174) | `#FIXED` default reported with `isrequired = 0` (Expat 1) | 1 | no |
| G03-6 | [#175](https://github.com/andersoxie/xpact/issues/175) | `SYSTEM ''` reported as `NULL` (Expat `""`) | 1 | no |
| G03-7 | [#176](https://github.com/andersoxie/xpact/issues/176) | in pieces, `a]]` delivered as text before the `]]>` error (Expat `a`) | 1 | **yes** |

Related older findings (other inputs): [#122](https://github.com/andersoxie/xpact/issues/122) (position 1:0 for malformed UTF-8), [#123](https://github.com/andersoxie/xpact/issues/123) (no events before a malformed-UTF-8 error), [#124](https://github.com/andersoxie/xpact/issues/124) (error 4, not 9).
</details>

<details>
<summary>🧩 Each engine against itself: the same result in every chunking?</summary>

| | Same in all 14 configurations | Not the same |
|---|---:|---|
| xpact | **90 / 93** | `o-p02fail15`, `o-p02fail27` (G03-3), `o-p14fail3` (G03-7) |
| Expat 2.8.1 | **92 / 93** | `o-p14fail3` (text before the error depends on the pieces, which the API allows) |

The verdict never changes with the chunking, for either engine.
</details>

<details>
<summary>🎯 Against the W3C expectation, and the marked cases</summary>

**Counted cases** (whole document, `XML_Parse`; every other configuration gives the same verdict):

| Expected | Cases | xpact | Expat 2.8.1 |
|---|---:|---|---|
| ACCEPT | 46 | 44 ✅ · 2 ❌ | 44 ✅ · 2 ❌ |
| REJECT | 37 | 37 ✅ | 37 ✅ |
| **Total** | **83** | **81 ✅** | **81 ✅** |

#### The 2 expectation misses
`x-ibm-1-0.5-valid-P04-ibm04av01.xml` and `x-ibm-1-0.5-valid-P05-ibm05v03.xml` use names that are legal only in the **5th edition** of XML 1.0. Through the DLL both engines reject them: the DLL uses the 4th-edition name tables, **like Expat** (known, by design; one of the "needs a decision" items in the AlotOfTests list). G01 marks them as passing because G01 ran them through the Eiffel runner, which uses the 5th edition. No new finding.

**Marked cases** (no binding W3C verdict here; compared only with Expat):

| Case | Why marked | xpact | Expat | Status |
|---|---|---|---|---|
| `not-wf-sa-081` | external general entities | REJECT | REJECT | error code differs (#170) |
| `valid-ext-sa-013` | external entities | ACCEPT | ACCEPT | match |
| `decl01` | external parameter entities | REJECT | REJECT | match |
| `ibm-not-wf-P77-ibm77n04.xml` | external parameter entities | REJECT | REJECT | match |
| `ibm-1-1-valid-P46-ibm46i01.xml` | XML 1.1 | ACCEPT | ACCEPT | match |
| `ibm-1-1-not-wf-P04-ibm04n20.xml` | XML 1.1 | REJECT | REJECT | position differs (#171) |
| `ibm-1-1-valid-P77-ibm77v05.xml` | XML 1.1 | REJECT | REJECT | position differs (#171) |
| `not-wf-sa-140` | not for the 5th edition | REJECT | REJECT | match |
| `not-wf-not-sa-005` | optional error | ACCEPT | ACCEPT | match |
| `ibm-invalid-P69-ibm69i01.xml` | optional error | ACCEPT | ACCEPT | match |

The external-entity cases are testable here because the harness loads local entities for both engines (G01 marked them when the runner's resolver was off).
</details>

<details>
<summary>⚙️ Configuration, commands and how to repeat it</summary>

| | |
|---|---|
| Machine | Windows 11, student PC; Python 3.14.0 |
| xpact | `build\native-eiffel\xpact_assertions.dll` (SHA-256 `9d1f30aa84eec3da…`), then `xpact.dll` (`aaf5d1d297b083de…`); MSVC finalized, built from `6d0db96` (same tree as `f985102`) |
| Expat | `libexpat.dll` **2.8.1** (`R_2_8_1`), MSVC Release, `char`, DTD/GE/NS on (`36a2532e2181ab8b…`), the same build as [expat-2.8.1](../expat-2.8.1/README.md) |
| Same code for both | [`reports/issue-0154/tools/harness`](../../../reports/issue-0154/tools/harness/engines.py): Expat C API through `ctypes`, each DLL in its own child process (a crash costs one case) |
| Settings, both engines | namespaces as in the W3C catalog; external entities from the suite folder only (like `xmlwf -p`); `XML_PARAM_ENTITY_PARSING_ALWAYS`; all event handlers set |
| 14 configurations | `XML_Parse` and `XML_GetBuffer` + `XML_ParseBuffer` × whole, 1, 2, 3, 7, 64, 1024-byte chunks |
| Compared | verdict, `XML_GetErrorCode`, the event list (adjacent text merged), and line:column after an error |
| Checked first | every G01 row is in the catalog and its file matches the manifest's SHA-256 (else exit 2) |

```powershell
python -I student\results\G03-comparison\compare.py --tag assertions --xpact-dll build\native-eiffel\xpact_assertions.dll
python -I student\results\G03-comparison\compare.py --tag normal --xpact-dll build\native-eiffel\xpact.dll
```
Each run: 2,604 parses, about 18 seconds, exit 0. `--expat-dll` points at another Expat build (default: `..\xpactGit\build\libexpat-R_2_8_1\build\libexpat.dll`).
</details>

## 📂 Files

| File | What |
|---|---|
| [`compare.py`](compare.py) | the tool |
| [`runs/assertions/results.tsv`](runs/assertions/results.tsv) · [`summary.json`](runs/assertions/summary.json) | one row per case; all totals, DLL paths and hashes |
| [`runs/assertions/differences/`](runs/assertions/differences/) | **a trace for every difference** (34 files): both results per differing configuration, the first differing event with context |
| [`runs/normal/`](runs/normal/) | `results.tsv` and `summary.json` for `xpact.dll`: identical rows. Its 34 traces are not committed: compared field by field they equal the assertions traces except `seconds` and `peak_mb` (time and memory of the parse) |
| [`run-assertions.txt`](run-assertions.txt) · [`run-normal.txt`](run-normal.txt) | console output |

Harness change for this task: `engines.py` and `worker.py` take `api="buffer"` (`XML_GetBuffer` + `XML_ParseBuffer`); the default (`XML_Parse`) is unchanged.

## ⚠️ Limitations

- [ ] 93 cases only (the G01 subset); the whole suite in pieces is the W3C-in-pieces test ([#165 report](../../../reports/issue-0165/report.md)), against `pyexpat` 2.7.3
- [ ] Only the main document is chunked; external entities are parsed whole
- [ ] Default handler, `XML_StopParser`/`XML_ResumeParser` and `XML_ParserReset` are not exercised here
- [ ] The causes of #170-#176 are not investigated yet (all ❔ or 🟡 suspected) · *2026-10-31: #172-#175 investigated and fixed; #170, #171, #176 still open*
