# Issue #227: test that the worker memory cap stops a document that needs more

| Item | Value |
|---|---|
| Issue | [#227](https://github.com/andersoxie/xpact/issues/227) (label `test`) |
| Branch | `test/227-memory-cap-v2`, from `incremental-test` @ `68abdcb` (replaces the WIP branch `test/227-memory-cap`) |
| DLLs | `xpact.dll` `4513b4a2a7f1530b…`, `xpact_assertions.dll` `eb1266280bc18c71…` (the 2026-11-08 build, parser source unchanged since) |
| Machine | Windows 11 Home 10.0.26300, .NET SDK 10, Release build |
| Parser change | **none** (test and docs only) |
| Status | ✅ test added and passing |

## Problem

The worker's memory cap (Windows Job Object, `WorkerMemoryMb`, default 512 MB) was set up but no test reached it (`website/docs/security.md`: "⬜ not tested").

## Investigation

| Try | Result |
|---|---|
| 100,000 empty elements, 1 MB attribute, 1,000 attributes, 1,000 × 1 KB entities (WIP branch) | worker stays under 40-45 MB and finishes: the .NET heap adapts to the job limit |
| Cap 8 MB, `<a/>` | `error`: `xpact.dll` initialization fails (`0x8007045A`), so the worker never parses. Not a useful test |
| Nested entities ("billion laughs", 10 levels × 10), cap 512 MB | `rejected` in 1.35 s |
| the same, cap 64 MB | `rejected` in 1.63 s |
| the same, cap 40 MB | **`crashed`** in 1.14 s: exit `0xC0000409`, `PANIC: main entry point vanished` (the Eiffel runtime runs out of memory) |

Cause (confirmed by the runs above): the API accepts at most 1 MB per document, so only native memory growth inside the parser can reach a cap. Nested entity expansion does; the documents tried before did not.

## Change

`The_memory_cap_stops_a_worker_that_needs_more` in `website/backend/tests/Xpact.Api.Tests/ValidateApiTests.cs`:

| Step | Expected |
|---|---|
| cap 40 MB, `<a/>` | `accepted` (the cap leaves room for normal documents) |
| normal cap, nested entities | `rejected` (the document is fine without the cap) |
| cap 40 MB, nested entities | `crashed` (the cap stops the worker) |
| cap 40 MB, `<a/>` again | `accepted` (the API keeps serving) |

`website/backend/tests/tools/job-memory-probe.ps1` (from the WIP branch) is kept as a measuring tool. `website/docs/security.md` updated.

## Command

```powershell
cd website\backend
dotnet test Xpact.Web.slnx -c Release --nologo
```

## Verification

- [x] Backend suite **21 / 21 passed**, 3 runs in a row (7 s each).
- [ ] Frontend not rebuilt: no frontend file changed.

## Limitations

- The 40 MB cap is close to the worker's start-up size (~28 MB). If a later DLL or .NET version needs much more memory at start-up, the cap in the test may need raising.
- The `PANIC` shows the Eiffel runtime does not report out-of-memory cleanly; the worker pattern contains it. Related: [#211](https://github.com/andersoxie/xpact/issues/211).
