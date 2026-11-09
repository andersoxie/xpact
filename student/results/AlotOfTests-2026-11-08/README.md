# 🧪 AlotOfTests rerun on `incremental-test` (2026-11-08)

> **What:** the 11 AlotOfTests areas of [2026-10-28](../AlotOfTests-2026-10-28/README.md), plus the repository's own suites, rerun on the final parser.
> **Tested code:** andersoxie/xpact `incremental-test` @ `df75792`; parser source identical to the acceptance run's `45d2f53` ([report](../../../reports/acceptance-253c81e-vs-45d2f53/report.md)).
> **Builds:** `xpact.dll` (SHA-256 `4513b4a2a7f1530b…`) and `xpact_assertions.dll` (`eb1266280bc18c71…`), built at 23:10 on 2026-11-08 with `websitescriptsbuild-dll.ps1` (EiffelStudio 25.12, MSVC `msc_vc140`, smoke test ok); the same DLLs the website and the release `website-2026-11-09` use. The W3C runner rebuilt `build
ative-eiffel` from the same source at 00:40, after the other tests (new hashes `b3f661e2…` / `a86eae91…`, timestamps differ).
> **Reference:** Expat through Python 3.14.0's `pyexpat` (Expat 2.7.3); Expat 2.8.1 for its own unit tests.
> **Machine:** the student PC (Windows 11, AMD Ryzen 7 5800H). Areas 1, 2, 7, 8, 9 and areas 3–4 ran at the same time; areas 5, 6, 10, 11 and the repository suites ran alone.
> **Status:** ✅ no crash in XPact, no regression against 2026-10-28; several results better. Known differences are listed below and stay open.

## 📊 Before and after

| # | Test | 2026-10-28 (`293918f`) | **2026-11-08 (`incremental-test`)** | |
|---|---|---|---|---|
| 1 | W3C output comparison | 359 / 432 exact | **399 / 432** (4 XPact only, 29 Expat too) | ✅ better |
| 1b | All 2,585 W3C verdicts through the DLL | core 1,654 pass · 320 fail (319 rejected by Expat too) · legacy 309 · 302 no-crash | **identical, case by case, both builds** | ⚪ same |
| 2 | W3C in pieces (≈ 8.0 million `XML_Parse` calls) | 3 XPact timeouts (`pr-xml-*`) | **ok 2,564 / 2,585 · 0 XPact crashes or timeouts · verdict never changes** | ✅ better |
| 3 | Fuzzing, 30 min, seed 1 | 571,839 inputs, 0 crashes | **3,879,031 inputs, 0 crashes, 0 hangs**; same verdict as Expat 99.985 % | ✅ 6.8× more in the same time |
| 4 | Differential vs Expat, 20 min, seed 1 | 1,457,486 documents | **3,148,557 documents**, 0 crashes; same verdict 99.94 % | ✅ 2.2× more |
| 5 | Security and limits (29 cases) | 19 pass · 9 fail · 1 crash/timeout | **20 pass · 9 fail (hard limits)**, both builds | ✅ better |
| 6 | Expat 2.8.1 `runtests` (399 per build) | 361 pass · 38 allocator · 3 timeouts in the assertions build (F06-1) | **361 pass · 38 allocator · 0 timeouts**, both builds | ✅ better |
| 7 | libxml2 corpus (1,417 files) | 1,269 same as Expat | **1,288 same as Expat**; the same 2 timeouts (`recurse/lol_eg.xml`, `lol_ep.xml`) | ✅ better |
| 8 | Encodings (146 cases) | 141 pass | **141 pass**, same 5 differences, both builds | ⚪ same |
| 9 | Memory: 8 scenarios × 20,000 lifecycles | no leak | **no leak** (levels off at 32–34 MB) | ⚪ same |
| 10 | CPython 3.14 XML tests on XPact (976) | 38 fail | **34 fail** | ✅ better |
| 11 | Large files (16 files, 4 ways) | 9 MB in 64 KB pieces: 4–5 min or timeout | **9 MB in pieces 0.58 s**, same events as Expat; 20 MB still rejected (over the 10 MB limit) | ✅ better |

### Repository suites (same build)

| Suite | Result |
|---|---|
| C# DLL tests (`tests/dotnet/XpactDllTests`) | **4,308 / 4,308** pass, 0 crash, 0 timeout, both builds |
| Python suite (`tests/python`) | **212 tests OK** |
| Eiffel test matrix (`run_eiffel_test_matrix.ps1`) | **4 / 4 lanes ok** |
| W3C runner, all lanes (`run_benchmarks.ps1 -EiffelBuild Finalized,FinalizedAssertions -W3cAllCases -SkipWslC`) | **2,585 cases, 0 failed, 0 errors**, both builds: 2,283 judged by the W3C verdict + 302 no-crash lanes; the same counts as 2026-10-28 ([summary](repo-suites/w3c/summary.md)) |

The benchmark timings of that single run are kept in [repo-suites/benchmarks-single-run.md](repo-suites/benchmarks-single-run.md); the website keeps the acceptance run's timings (4 alternating runs on an idle PC). The DLL external-entity lane (247 cases) was not rerun.

## ⚠️ Known failures (open, not fixed by this run)

| Where | What | Tracked |
|---|---|---|
| 2 | 16 W3C documents give other events or another error code in pieces (verdict unchanged) | andersoxie#176, mass-xpact#74 |
| 5 | 9 cases hit hard limits (100k attributes, 50k namespaces …) or `ns-separator-in-uri` accepted | AlotOfTests F05 |
| 7 | 2 external billion-laughs files time out instead of being stopped | AlotOfTests F07 |
| 8 | 5 encoding differences (BOM vs declaration, unpaired surrogate) | mass-xpact#83 |
| 10 | 34 CPython tests fail in `test_pyexpat`, `test_sax`, `test_xml_etree(_c)` | AlotOfTests F10 |
| 11 | documents over 10 MB are rejected | design limit |
| all | not thread-safe (not tested here) | mass-xpact#75 |

## 🔁 Commands

[`scripts/run-all-incremental.sh`](scripts/run-all-incremental.sh) `A`, `B`, `C` (11 areas, tags `it` and `it_assertions`) and [`scripts/run-repo-suites.ps1`](scripts/run-repo-suites.ps1), run from a copy of the AlotOfTests folder with the harness pointed at the `incremental-test` worktree. [`collect.py`](collect.py) builds [`summary.json`](summary.json), which the website reads. Console output of every step: [`console/`](console/).

## Limitations

- [ ] One PC; no Linux.
- [ ] Areas 3 and 4 are time-boxed: their counts depend on the machine load (they ran next to areas 1, 2, 7–9).
- [ ] The tests show what they cover; they do not prove there are no other faults.
