# #316 · Under a small memory cap the worker can crash instead of reporting out of memory

| | |
|---|---|
| Status | ✅ **cause confirmed, fixed in the worker, verified locally** (2026-11-12) · not yet in a release build / Docker image |
| Issue | [#316](https://github.com/andersoxie/xpact/issues/316) |
| Impact | low: only with an unusually small cap; the document was always stopped and the site kept serving |
| Evidence | [fix-sweep-2026-11-12.txt](fix-sweep-2026-11-12.txt) (old vs new) · [cdb-20mb-run1.txt](cdb-20mb-run1.txt), [run2](cdb-20mb-run2.txt), [run3](cdb-20mb-run3.txt) (native stacks) · [cap-sweep-2026-11-12.txt](cap-sweep-2026-11-12.txt) (first investigation) · scripts [sweep316.ps1](sweep316.ps1), [cdb316.ps1](cdb316.ps1) |

## 1. Problem
The nested-entity document (10 levels × 10) under a 40 MB worker cap should end as `rejected`, code 1 `XML_ERROR_NO_MEMORY` (#273). In the Docker image it sometimes ended as `crashed` ("Stack overflow."). On the PC the same happened at 12–26 MB.

- **Environment:** student PC, Windows 11 Home · `incremental-test` @ `439ed26` · DLL `website\dist\native\xpact.dll` `ADAE03D2…` (unchanged) · WinDbg `cdb.exe` 1.2611.4001.0
- **Command:** `powershell -File sweep316.ps1 -WorkerDir <worker folder> -Label <name>`: one worker per run in a Job Object with the API's flags, 5 runs per cap · native stacks: `powershell -File cdb316.ps1 -CapMb 20 -Out <file>`
- **Expected:** a clean result (code 1, or at least a reported error) whenever the cap is reached, never a crash.

## 2. What the debugger showed (3 runs at 20 MB, no XPact symbols needed)

| run | thread that died | stack (top → bottom) |
|---|---|---|
| 1 | .NET **finalizer** thread | `ntdll!RtlAllocateHeap` ← `malloc` ← `coreclr` type loader ← `GC.RunFinalizers` |
| 2 | **main** thread | `_chkstk` ← C++ exception in `coreclr!AppDomain::LoadAssembly` ← `Program.<Main>$` (first use of a type after the parse) |
| 3 | .NET **finalizer** thread | `coreclr!__chkstk` ← `ClassLoader::CreateTypeHandleForTypeDefThrowing` ← `FinalizerThread` |

- ✅ **Not recursion:** the dying thread had used only ~20 KB (run 1) and ~63 KB (run 2) of stack. "Stack overflow" here means Windows could not commit the next stack page because the process was at its cap.
- ✅ **Not in XPact or the Eiffel runtime:** every crash is inside **CoreCLR**, when .NET loads a type or JIT-compiles a method for the first time (JSON output after the parse, a finalizer, tiered re-JIT) after the parse has used all memory the cap allows.
- ✅ **Why it is a race:** whichever thread needs memory first decides the outcome: the Eiffel heap (→ clean code 1), .NET in a place that can throw (→ access violation / `0x80131506`), or a stack page (→ stack overflow).
- ✅ This also explains why the first idea (a bigger stack on the parse thread) did not help: the parse thread is not the one that dies.

## 3. Cause
✅ **Confirmed:** at the cap, the .NET runtime in the worker needs memory for first-time type loading / JIT / finalizers and fails inside native runtime code.

## 4. Fix (worker only, no DLL change), branch `fix/316-worker-warmup`
1. **Warm-up** before the real parse: two tiny documents (valid + invalid, whole + in pieces), each serialized to JSON; flush stdout/stderr; run pending finalizers. Every path used after the parse is loaded while memory is free.
2. **4 MB reserve:** allocated (and touched) just before `XML_Parse`, freed as soon as it returns, so .NET has room to build and print the result.
3. **`TieredCompilation` off** in `Xpact.Worker.csproj`: no background re-JIT thread allocating during the parse.

## 5. Verification

| cap (MB) | old worker (5 runs) | warm-up only | ✅ fix (5 runs) |
|---|---|---|---|
| 12–14 | 🔴 AV / stack overflow / 0x80131506 | 🔴 hangs / crashes | ✅ `error` (caught `OutOfMemoryException`) |
| 16 | `error` | `error` | ✅ `error` |
| 18–26 | 🔴 stack overflow / AV, 0 of 25 clean | 🔴 4 of 25 clean | ✅ `error`, 25 of 25 clean |
| 30, 40 | ✅ code 1 | ✅ code 1 | ✅ code 1 (10 of 10) |

- 🔴 → ✅ **0 crashes in 50 runs** (old: 35 crashes in the 40 runs below 30 MB).
- Speed (10 MiB valid document, 3 alternating runs, PC **not idle**): total 3.56 s → 3.73 s median (+0.17 s, warm-up and full JIT at start); parse time 3.22 s → 3.28 s (noise); 1 MB unchanged (0.67 s).
- [x] ✅ Worker builds with 0 errors
- [x] ✅ `website\scripts\test.ps1` on the branch (see PR)
- [ ] Docker workflow: after the next release, the "Memory cap inside the container" check can require `rejected` code 1 again instead of also accepting `crashed`

## 6. Limits / open
- Below ~30 MB the result is `error` ("internal error"), not code 1: the worker itself does not fit. Such caps are not a real setting (default 512 MB).
- The 4 MB reserve lowers the memory left for the parse by 4 MB; with the default 512 MB cap this does not matter.
