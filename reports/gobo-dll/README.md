# xpact.dll built with Gobo Eiffel + Microsoft C (2026-11-16)

[← reports](../README.md) · issue [#414](https://github.com/andersoxie/xpact/issues/414) · finding [#415](https://github.com/andersoxie/xpact/issues/415) · background: [Gobo for xpact](../gobo-2026-11-16/README.md) · [#304 multi-threading](../issue-0304/README.md) · [speed work](../perf-allocations/README.md) · raw results: [results/](results/)

## In short
| Question | Answer |
|---|---|
| Does a Gobo-built xpact.dll work? | ✅ **Yes.** Same C API (`include/xpact.h`), same results: Test 2 (W3C in pieces, 2,585 cases) gives a **byte-identical** result file to the EiffelStudio DLL; smoke test ok; 1-16 threads, 0 wrong results. |
| Is it faster? | ❌ **Not yet.** Default GC: **0.59×** the EiffelStudio DLL's speed (204 cells). Tuned GC: **0.90×** (1 MB cells). |
| Does it use several cores? | ❌ **Not yet.** Both DLLs still run all Eiffel calls under one global lock in the C bridge. Removing that lock is the next step; the parser itself already scales under Gobo ([background](../gobo-2026-11-16/README.md)). |
| Did the C compiler matter? | No. Both builds use Microsoft `cl -O2`, and Gobo with Zig or msc gave the same thread times (0.77 vs 0.78 s). |

## What was built
| | EiffelStudio DLL (the standard) | Gobo DLL (new) |
|---|---|---|
| Eiffel compiler | EiffelStudio 25.12 (`ec`) | Gobo 26.11.14+55e703f (`gec --finalize --cc=no`) |
| C compiler | Microsoft `cl` (msc_vc140), `-O2` | Microsoft `cl`, `-O2 -MT` (Gobo's own flags) |
| Runtime / GC | ISE runtime, own GC | Gobo runtime, Boehm GC |
| Source | commit `020be3e`, built in a separate worktree | same `src/`, `native/` (+ Gobo-only code below) |
| Build | `scripts/build_native_eiffel.ps1` | [build_gobo_dll.ps1](build_gobo_dll.ps1), ECF [xpact_native_library_gobo.ecf](xpact_native_library_gobo.ecf) |
| SHA-256 (first 16) | `9F7B8A69DF69E552` | `BC9DC12B8F063B56` |

Rebuild: `powershell -File reports\gobo-dll\build_gobo_dll.ps1` → `build\gobo-dll\out\xpact.dll` (about 3 min; never writes into `build\native-eiffel`).

### Gobo-only code (EiffelStudio build unchanged: everything is behind `#ifdef XP_GOBO_RUNTIME`)
- [gobo_dllmain.c](gobo_dllmain.c): starts Gobo's runtime (`main` renamed to `xp_gobo_main`) **on the first `XML_ParserCreate*` call**, once, not in `DllMain`; releases foreign threads on `DLL_THREAD_DETACH`.
- [gobo_thread_adopt.c](gobo_thread_adopt.c) (appended to Gobo's generated C): `xp_gobo_ensure_thread()` gives a thread that Gobo did not create a Gobo context, as `GE_thread_create_with_attr` does: Boehm `GC_register_my_thread`, `GE_new_context`, thread context, onces, exceptions; plus an uncollectable root for the context.
- `native/xpact_eiffel_runtime_bridge.c`: calls `xp_gobo_ensure_thread()` before each Eiffel call. `native/xpact_native.c`: calls `xp_gobo_ensure_runtime()` in `XML_ParserCreate_MM`.

## Results (idle PC: Windows 11, Ryzen 7 5800H, 8 cores / 16 threads)

### 1. Correctness ✅
| Test | EiffelStudio DLL | Gobo DLL |
|---|---|---|
| DLL smoke test (`xpact_eiffel_dll_smoke.exe`) | ✅ ok | ✅ ok |
| Test 2: W3C in pieces, 2,585 cases, `run.py --jobs 16` | 2,564 ok / 16 xpact-only / 5 both | **identical**; result file SHA `1feb6129…` = long-standing baseline for both |
| Fair speed matrix output checksums (204 cells) | 0 mismatches | 0 mismatches |
| Threads (`steps.c` steps 1-4, `threads.c` 1-16 threads × 3 GC settings) | ✅ | ✅ 0 wrong results |

### 2. Speed: fair speed matrix (1 KB - 10 MB inputs, 6 piece sizes, with/without callbacks, `--jobs 1`)
| | cells | xpact / Expat (median) | vs EiffelStudio DLL (median) | best / worst cell |
|---|---:|---:|---:|---:|
| EiffelStudio DLL | 204 | **16.4× slower** | 1.00× | – |
| Gobo DLL, default GC | 204 | 26.7× slower | **0.59×** | 1.72× / 0.31× |
| *1 MB cells only:* EiffelStudio | 84 | 17.0× slower | 1.00× | – |
| *1 MB:* Gobo, default GC | 84 | 29.5× slower | 0.58× | 1.52× / 0.37× |
| *1 MB:* Gobo, **GC tuned¹** | 84 | 19.7× slower | **0.90×** | 1.75× / 0.60× |

¹ `GC_FREE_SPACE_DIVISOR=1 GC_MARKERS=8` (environment variables, no rebuild). Tuning alone makes the Gobo DLL 1.64× faster.
By group (default GC vs ES): namespaces is worst (0.43×), text best (0.70×); 1-byte pieces 0.83×.
Both DLLs time out on the same 4 cells (`elements-1MB-latin1`, 1 B / 16 B pieces). Raw: [es.tsv](results/es.tsv) · [gobo.tsv](results/gobo.tsv) · [gobotuned-1MB.tsv](results/gobotuned-1MB.tsv) · [compare all](results/compare-es-gobo.txt) · [compare 1 MB](results/compare-1MB.txt). Run time: ES 94 min, Gobo 106 min.

### 3. Threads through the DLL (`threads.c`, 16,000 small parses, median of 3, alternating)
| Threads | EiffelStudio DLL | Gobo DLL, default GC | Gobo DLL, GC tuned¹ |
|---:|---:|---:|---:|
| 1 | **0.42 s** | 1.12 s | 0.61 s |
| 2 | 0.50 s | 1.20 s | 0.69 s |
| 4 | 0.52 s | 1.29 s | 0.73 s |
| 8 | 0.55 s | 1.36 s | 0.78 s |
| 16 | 0.58 s | 1.43 s | 0.84 s |

No DLL gets faster with more threads: the bridge's global lock lets one thread into Eiffel at a time. Raw: [threads-dll.txt](results/threads-dll.txt).

## How this matches the background
| Background fact | This measurement | Match? |
|---|---|---|
| Standalone, 1 thread: ES 0.43 s, Gobo default 0.78 s, **Gobo tuned 0.38 s** ([table](../gobo-2026-11-16/README.md)) | DLL: ES 1.00×, Gobo default 0.59×, Gobo tuned 0.90× | ✅ default GC slower in both (0.55× vs 0.59×). ⚠️ Tuned: standalone beats ES, the DLL does not yet: the C bridge adds Gobo-specific cost (below). |
| Standalone Gobo **scales** with threads (4 threads 0.24 s) | DLL: no scaling, either compiler | ✅ expected: the global bridge lock, not Gobo. |
| Supervisor, Linux (GCC): Gobo 915 ms vs ES 1,550 ms (1.7× faster) | Windows, both msc: Gobo default 0.59× | ⚠️ Different. Suspected (not confirmed): Boehm's default GC settings on Windows, the C bridge, Linux vs Windows. Not the C compiler (Zig = msc here). |
| Gobo W3C profile identical to ES (1,974 / 0 / 0) | Test 2 result file byte-identical | ✅ |
| ES DLL vs Expat 17.15× after the speed-ups | 16.4× (all), 17.0× (1 MB) | ✅ same range |

Where the extra cost is (suspected, not yet profiled): callback-heavy cells lose most (one small cell: 2.84 ms vs 0.90 ms ES). Each callback goes through `eif_adopt` / `eif_access` / `eif_wean`; Gobo implements `eif_protect` with an uncollectable Boehm allocation per object, and each `$feature` call looks up the thread context in thread-local storage.

## Problems found and fixed (all in the new Gobo-only code)
| # | Problem | Command | Expected → actual | Cause | Fix | Verified |
|---|---|---|---|---|---|---|
| 1 | DLL hangs while loading | `steps.exe <gobo dll> 1` | loads → hangs in `LoadLibrary` (works with `GC_MARKERS=1`) | **confirmed**: Boehm starts parallel marker threads and waits for them inside `DllMain`; Windows' loader lock blocks new threads | start the runtime on the first `XML_ParserCreate*` call (`InitOnceExecuteOnce`) | ✅ default, 8 markers, tuned: all load |
| 2 | Access violation in `HASH_TABLE.force` from `parser_create` | `steps.exe <gobo dll> 2` | parse → crash | **confirmed**: bridge compiled without `GE_USE_BOEHM_GC`, so `eif_access` returned the slot, not the object | compile bridge with `-DGE_USE_BOEHM_GC -DGE_USE_THREADS` (+ Boehm include paths) | ✅ step 2 ok |
| 3 | Second thread gets a wrong result | `steps.exe <gobo dll> 3` | ok → "step 3 wrong result" | **confirmed**: no Gobo context on a thread Gobo did not create | `xp_gobo_ensure_thread()` | ✅ step 3 ok |
| 4 | Crash with 2+ threads (`threads.exe 2 2000`), fine with `GC_DONT_GC=1` | as left | 4,000 ok → segfault | **confirmed**: `GE_new_context` uses collectable memory; only Windows TLS pointed to it, which Boehm does not scan, so the GC freed it | uncollectable root per adopted thread; unregister on thread exit | ✅ 1-16 threads × 3 GC settings, 0 wrong |

Also found (not fixed, outside this work): `scripts/build_native_eiffel.ps1 -OutputDir X` still writes `xpact_native.obj` and `xpact_eiffel_runtime_bridge.obj` into `build\native-eiffel` (line 14, `$EcfObjectRoot`). ([#415](https://github.com/andersoxie/xpact/issues/415)). That is why the ES DLL was built in a separate worktree (`C:\xpact\wt-es-head`).

## Left to do
- [x] Build xpact.dll with Gobo + msc, same C API
- [x] Make it load without workarounds and work on any thread
- [x] Same results as the EiffelStudio DLL (Test 2, speed checksums, smoke, threads)
- [x] Speed and thread comparison against the EiffelStudio DLL
- [ ] **Remove the global bridge lock for the Gobo build** (per-thread state, registry lock as in branch `trial/304-mt-park`): this is where Gobo's multi-threading pays off
- [ ] Profile the callback path (`eif_adopt`/`eif_protect` cost under Gobo) and reduce it
- [ ] Set the GC tuning inside the DLL (Gobo's `MEMORY` controls) instead of environment variables
- [ ] Full tuned run (204 cells; only the 84 1 MB cells were run); W3C runner and C#/Python tests against the Gobo DLL
- [ ] Gobo assertions variant of the DLL

## Limits
- One PC, Windows only; Gobo nightly 26.11.14 (the supervisor qualified 26.11.12).
- Tuned GC measured on 1 MB inputs only (84 of 204 cells).
- Cause of the Gobo DLL's extra cost is suspected, not profiled.
- Nothing committed; `native/` changes are uncommitted and behind `#ifdef XP_GOBO_RUNTIME`.
