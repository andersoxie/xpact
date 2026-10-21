# Report: issue #37, a C# test program for the xpact DLL

Issue: [#37](https://github.com/andersoxie/xpact/issues/37)   Branch: `fix/37-dll-test-program`   Base: `student-Mass` @ `42d6b40`   Date: 2026-10-22

> **In short:** ✅ a new test program, [`tests/dotnet/XpactDllTests/`](../../tests/dotnet/XpactDllTests/README.md),
> runs 3,360 cases (tasks C02, C03, part of C10, and #28) through the DLL's C
> API. ✅ Full runs on three DLLs are recorded in
> [`student/results/dll-tests-2026-10-22/`](../../student/results/dll-tests-2026-10-22/README.md).
> The problems it found are separate finding issues: #38 (C01), #39 (UTF-8), #40 (chunk ends with `<`); B03 and #28 evidence is on #3 and #28. **No parser code is changed.**

## Why

The Eiffel test matrix and the W3C runner call the Eiffel parser directly.
C02, C03 and C10 are about the C API: callbacks, final and non-final
`XML_Parse` calls, chunk boundaries. Nothing tested that path with these
inputs, and the guide noted that a June DLL accepted `<root>` when a start
handler was set (C01), never retested.

## What changed

| File | Change |
|---|---|
| `tests/dotnet/XpactDllTests/` | New: the program (`Native.cs` P/Invoke, `Catalog.cs` cases and expected results, `Executor.cs` one case, `Program.cs` parent/child runner, `Report.cs` judging and summary, `Options.cs`), its `README.md`, and `Directory.Build.props` that puts `bin/` and `obj/` under `build/` (ignored by git) |
| `student/results/dll-tests-2026-10-22/` | New: the three runs (summary, every case in `results.tsv`, one full crash output per crash reason), the timeout recheck, and a README in the test-report format of `CLAUDE.md` |
| `reports/issue-0037/report.md` | This report |

## Expected results (written before the first run)

The expected verdicts are in `Catalog.cs`, written before the program was
first run on 2026-10-22 00:47:

| Inputs | Expected, for every callback set and chunking |
|---|---|
| `<root/>`, `<root></root>`, `<root>hi</root>` | ACCEPT; start/end events as requested; character data `hi` |
| empty, `<root>`, `<root><child></root>`, `<root/>junk` | REJECT |
| CR LF, lone CR, CR after the root, CR in an attribute | ACCEPT; character data a single LF (`\x0a`) |
| `C3 A9` (é) in text, attribute, name, comment, PI, CDATA | ACCEPT |
| `C3 28`, `C0 AF`, `ED A0 80`, `F4 90 80 80` in the same six places | REJECT |

Expected of the program itself:

| # | Check | Expected |
|---|---|---|
| 1 | `dotnet build tests\dotnet\XpactDllTests -c Release` | 0 warnings, 0 errors; nothing new in `git status` outside `tests/dotnet/` |
| 2 | `--list` | 3,360 case ids |
| 3 | A crash inside the DLL | Recorded as CRASH for that case only; the run continues |
| 4 | Two runs on the same DLL | Same verdicts and error codes for every case that does not crash |
| 5 | Exit code | 1 when any case is not PASS, 0 when all pass |

## Verification

Windows 11, .NET SDK 10.0.300, EiffelStudio 25.12.9.8922 (`msc_vc140`),
MSVC 14.51. Commands and results are in the
[results README](../../student/results/dll-tests-2026-10-22/README.md).

| # | Actual | |
|---|---|---|
| 1 | Build succeeded, 0 warnings, 0 errors; `git status` shows only `tests/dotnet/` | ✅ |
| 2 | `3360 cases` | ✅ |
| 3 | 1,329 crashes on `xpact_assertions.dll`, each its own CRASH row, the run finished | ✅ |
| 4 | See the results README, "Repeatability" | ✅ |
| 5 | Exit 1 on all three DLLs (none passes everything) | ✅ |

### Two problems in the program itself, found and fixed before committing

| Problem | Cause | Fix | Verified |
|---|---|---|---|
| Some crash reasons were cut off (`markup_prefix_end @18`, `XP_NATIVE_LIBRARY_ROOT`) | **Confirmed:** the parent cleared the collected stderr when a case started, but stderr comes on a different pipe than the "case started" line, so the top of the Eiffel trace was sometimes already in it and got cleared | stderr is no longer cleared: a child stops at its first crash, so all its stderr belongs to that crash | ✅ After the fix those two reasons are gone; the same cases show `find_markup_declaration_end` |
| Crashes reported as TIMEOUT (11 at `--timeout 10` with a compiler running, 4 at 30 s idle) | **Confirmed** that they are crashes: each one crashed in 3-6 s when run alone. Why a crashed process sometimes takes longer to end when several crash at once is **unknown** | Default timeout 30 s; every TIMEOUT case is retried once alone at the end of the run, and the summary says so | ✅ See the results README |

## Limits

Only the start, end, character data and default handlers; no
`XML_ParseBuffer`, `XML_StopParser` or namespaces yet. The libexpat error
codes in the catalog are reference values from libexpat's documented
behaviour, **not** from running Expat; the program does not judge error codes.

## How to revert

```powershell
git revert <merged sha>
```
