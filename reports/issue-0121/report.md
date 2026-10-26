# Report: issue #121, C03/C10 compared with Expat 2.8.1

Issue: [#121](https://github.com/andersoxie/xpact/issues/121)   Branch: `fix/121-expat-comparison`   Base: `student-Mass` @ `e30f0e6`   Date: 2026-10-26

## In short

| | |
|---|---|
| Task | Week 5, the open parts of C03 and C10 (part): compare status, error code and position with Expat 2.8.1; add `80` and `FF` |
| How | Expat 2.8.1 built from source as `libexpat.dll`; the C# DLL test program (#37) run on it and on both xpact DLLs; [`compare.py`](../../student/results/expat-2.8.1/compare.py) case by case |
| Result | **4,308 / 4,308 verdicts the same.** Chunking never changes Expat's answer, nor xpact's verdict or code. **5 differences**, each in its own finding issue: [#122](https://github.com/andersoxie/xpact/issues/122)-[#126](https://github.com/andersoxie/xpact/issues/126) |
| Not done | No parser change: the findings are reported, not repaired (C08 stays with the experienced developers) |

## Environment

| | |
|---|---|
| Machine | Windows 11 Home 10.0.26300, the student PC |
| Expat | 2.8.1, `https://github.com/libexpat/libexpat/archive/refs/tags/R_2_8_1.tar.gz` (SHA-256 `c999c8e5…3504`); CMake 4.3.1-msvc1, MSVC 19.51.36260 x64, Release, upstream defaults (`XML_DTD`, `XML_GE`, `XML_NS` on, context bytes 1024); `libexpat.dll` SHA-256 `36a2532e…4661`. Script: [`expat-build.cmd`](expat-build.cmd), log: [`expat-build.txt`](expat-build.txt) |
| xpact | `xpact.dll` (`75a8bf14…`) and `xpact_assertions.dll` (`f4f75bdd…`), finalized, MSVC, built 2026-10-26 17:40 from `e8c5cb3` (#110); no change in `src`, `include` or `native` between `e8c5cb3` and `e30f0e6` (`git diff --stat` empty) |
| Test program | `tests/dotnet/XpactDllTests`, .NET 10, Release, with this branch's `Catalog.cs` |

## What changed

| File | Change |
|---|---|
| `tests/dotnet/XpactDllTests/Catalog.cs` | two UTF-8 sequences added: `lone-continuation` (`80`) and `ff` (`FF`), in the same six places (C10 draft) |
| `tests/dotnet/XpactDllTests/README.md` | new inputs, 4,308 cases, how to compare with Expat |
| `student/results/expat-2.8.1/` | New: `compare.py`, `cases.tsv`, `summary.md`, `README.md`, the three runs in `runs/` |
| `student/results/C03-chunks/`, `C10-utf8/` | New: README each and the byte-exact fixtures (6 and 42) |
| `student/github/issues/14-C03.md`, `15-C10.md` | boxes ticked, "Done 2026-10-26" |
| `student/PLAN.md`, `student/notes/weekly/week-05.md`, `student/results/README.md`, `reports/README.md` | ticked / rows; the known problem "error codes differ from libexpat" replaced by #122-#126 |

## Expected results (written before the runs, in #121)

| # | Check | Expected |
|---|---|---|
| 1 | Expat, malformed UTF-8 | rejected everywhere, whole and at every split |
| 2 | Expat, chunking | never changes verdict or error code |
| 3 | xpact vs Expat verdicts | the same everywhere |
| 4 | Error codes | differences expected; recorded, not judged |

## Verification

| # | Command / check | Actual | |
|---|---|---|---|
| 1 | `cmake … && cmake --build …` ([`expat-build.cmd`](expat-build.cmd)) | `libexpat.dll` built, exit 0; test program reports `Version: expat_2.8.1` | ✅ |
| 2 | `dotnet build tests\dotnet\XpactDllTests -c Release` | 0 errors | ✅ |
| 3 | `XpactDllTests.exe --dll …\libexpat.dll` | `TOTAL 4308 pass 4308 fail 0 crash 0`, exit 0 ([summary](../../student/results/expat-2.8.1/runs/libexpat/summary.txt)) | ✅ expected 1, 2 |
| 4 | `XpactDllTests.exe --dll …\xpact.dll` | `TOTAL 4308 pass 4308 fail 0 crash 0`, exit 0 ([summary](../../student/results/expat-2.8.1/runs/xpact/summary.txt)) | ✅ |
| 5 | `XpactDllTests.exe --dll …\xpact_assertions.dll` | `TOTAL 4308 pass 4308 fail 0 crash 0`, exit 0; `results.tsv` byte-identical to #4 (SHA-256 `34bce072…`) | ✅ |
| 6 | `python -I student\results\expat-2.8.1\compare.py --expat … --xpact …` | `4308 cases compared; fixtures: C03-chunks 6, C10-utf8 42` | ✅ |
| 7 | verdicts | 0 differ | ✅ expected 3 |
| 8 | error codes | 72 differ, all `<root/>junk` (4 vs 9, #124); every other code equals the catalog's libexpat code | ✅ recorded (expected 4) |
| 9 | rerun of `compare.py`; run against the assertions DLL | byte-identical outputs; only the run label in `summary.md` changes | ✅ |
| 10 | claims in the READMEs checked against `cases.tsv` | c02 differences only in `trailing-junk`, `mismatched` (default), `text` (split only); all 3,096 rejected UTF-8 cases code 4/4; 510 `é` cases accepted by both | ✅ |

**Corrected during the work:** the first run used a wrong output path, so all
three runs wrote to one folder; rerun into separate folders. `compare.py` first
broke the Markdown tables with the `|` inside event lists, and a local variable
hid a helper function; both fixed before the results above.

## Findings (one issue each, causes not traced)

| Issue | Difference | Cases | Cause |
|---|---|---|---|
| [#122](https://github.com/andersoxie/xpact/issues/122) | malformed UTF-8 reported at 1:0 | 3,096 | suspected |
| [#123](https://github.com/andersoxie/xpact/issues/123) | no events before a malformed-UTF-8 error | 598 | suspected |
| [#124](https://github.com/andersoxie/xpact/issues/124) | `<root/>junk`: code 4 not 9; position moves | 72 | unknown |
| [#125](https://github.com/andersoxie/xpact/issues/125) | default handler gets the mismatched end tag | 21 | unknown |
| [#126](https://github.com/andersoxie/xpact/issues/126) | default handler gets LF, not the raw CR | 38 | suspected |

Recorded, not judged: text divided into different pieces (2 cases, allowed by
the Expat API) and which `XML_Parse` call reports the error (649 chunked cases).

## Limitations

See [`student/results/expat-2.8.1/README.md`](../../student/results/expat-2.8.1/README.md#limitations):
small inputs only, four handlers, Expat's choices treated as the reference.

## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 121 -Commit <merged sha>
```
