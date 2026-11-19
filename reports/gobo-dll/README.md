# xpact.dll built with Gobo Eiffel + Microsoft C (2026-11-16)

[← reports](../README.md) · issue [#414](https://github.com/andersoxie/xpact/issues/414) · finding [#415](https://github.com/andersoxie/xpact/issues/415) · background: [Gobo for xpact](../gobo-2026-11-16/README.md) · [#304 multi-threading](../issue-0304/README.md) · [speed work](../perf-allocations/README.md) · raw results: [results/](results/)

## In short
| Question | Answer |
|---|---|
| Does a Gobo-built xpact.dll work? | ✅ **Yes.** Same C API (`include/xpact.h`), same results: Test 2 (W3C in pieces, 2,585 cases) gives a **byte-identical** result file to the EiffelStudio DLL; smoke test ok; 1-16 threads, 0 wrong results. |
| Is it faster? | ⚠️ **Single thread: almost.** After the follow-ups ([section 4](#4-follow-ups-418-lock-removal-callback-fix-gc-tuning-in-the-dll)): **0.92×** the new EiffelStudio DLL (1 MB cells; was 0.59×). Faster than ES with 1-byte pieces (1.22×) and without callbacks (parser alone 1.7×). |
| Does it use several cores? | ✅ **Yes, since [#418](https://github.com/andersoxie/xpact/issues/418)** (Gobo build only). With the global bridge lock removed: 16,000 parses take **0.40 s on 4 threads vs 0.61 s** for the ES DLL (0.67 s on 1 thread). The ES build keeps the lock. |
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

No DLL gets faster with more threads: the bridge's global lock lets one thread into Eiffel at a time. Raw: [threads-dll.txt](results/threads-dll.txt). *(Superseded for Gobo by section 4.)*

### 4. Follow-ups: #418 lock removal, callback fix, GC tuning in the DLL
All measured on charger, idle PC, median of 3, old/new alternating. New DLLs: Gobo `478180E1FFB69475` (`build\gobo-dll\out`), ES `C8A5A7B9…` (worktree `C:\xpact\wt-es-head`, same source).

| Change | Files | What it does |
|---|---|---|
| **Remove the global bridge lock** ([#418](https://github.com/andersoxie/xpact/issues/418)) | `native/xpact_eiffel_runtime_bridge.{c,h}`, `src/xp_native_bridge_installer.e`, `src/xp_native_bridge_export.e` | Gobo build only (`XP_GOBO_RUNTIME`): no process-wide lock; a small **registry lock** guards the shared parser tables; `input_chunk` is a per-thread `once`. `XPACT_GLOBAL_LOCK=1` brings the old lock back (for comparisons). ES build: unchanged lock (ES onces are not safe without it). |
| **Callback strings reused** | `src/xp_native_callback_handler.e` | Profile showed the callback cost was **Boehm finalizers** from a new `C_STRING`/`MANAGED_POINTER` per callback (not `eif_protect`, as suspected). Now a pool of reused strings (fresh ones only for re-entrant callbacks). Helps both builds. |
| **GC tuning inside the DLL** | `reports/gobo-dll/gobo_dllmain.c` | `GC_set_free_space_divisor(1)` + markers = min(CPUs, 8) before the runtime starts; same speed as the env variables (1.48 vs 1.53 s); env variables still override. |
| Profiler knows Gobo names | `reports/perf-allocations/sample.py` | maps `T12f34` → `{CLASS}.feature` from gec's comments. Profiles: [profile/](results/profile/) |

**Callback cells** (1 MB UTF-8, cb=1; checksums equal) — [callback-speed.txt](results/callback-speed.txt)
| Cell | ES old → new | Gobo old → new |
|---|---:|---:|
| elements, callbacks | 162 → **124 ms** | 282 → **149 ms** |
| attributes, callbacks | 89 → **68 ms** | 165 → **79 ms** |
| text, callbacks | 49 → **44 ms** | 64 → **54 ms** |
| elements, no callbacks | 43 → 43 ms | **25 → 25 ms** (parser alone 1.7× faster than ES) |

**Threads** (`threads.c`, 16,000 small parses) — [threads-418.txt](results/threads-418.txt)
| Threads | ES DLL (lock) | Gobo, lock on | **Gobo, no lock** |
|---:|---:|---:|---:|
| 1 | **0.44 s** | 0.67 s | 0.67 s |
| 2 | 0.58 s | 0.77 s | 0.49 s |
| 4 | 0.61 s | 0.81 s | **0.40 s** |
| 8 | 0.65 s | 0.86 s | 0.41 s |
| 16 | 0.65 s | 0.92 s | 0.56 s |

**Fair speed matrix, 1 MB cells** (84 cells, `--jobs 1`, 0 checksum mismatches, same 4 timeouts as before)
| Comparison | median speed-up | best / worst | xpact / Expat |
|---|---:|---:|---|
| ES old → ES new | 1.03× | 1.28× / 0.98× | 17.0× → **15.4×** slower |
| Gobo default GC (old) → Gobo new | **1.69×** | 3.04× / 1.07× | 29.5× → 17.3× slower |
| Gobo env-tuned (old) → Gobo new | 1.02× | 1.90× / 0.93× | 19.7× → 17.3× slower |
| **ES new → Gobo new** | **0.92×** | 1.76× / 0.70× | 15.4× vs 17.3× slower |

ES new → Gobo new by group: 1 B pieces **1.22×**, 16 B 1.02×, 256 B-64 KB 0.88-0.90×, whole 0.93×; namespaces worst (0.74×). Raw: [es418-1MB.tsv](results/es418-1MB.tsv) · [gobo418-1MB.tsv](results/gobo418-1MB.tsv) · compares: [ES](results/compare-418-es-1MB-vs-es418-1MB.txt) · [Gobo](results/compare-418-gobo-1MB-vs-gobo418-1MB.txt) · [Gobo tuned](results/compare-418-gobotuned-1MB-vs-gobo418-1MB.txt) · [ES vs Gobo](results/compare-418-es418-1MB-vs-gobo418-1MB.txt). Run time 75 min each.

**Correctness after the follow-ups** ✅
| Test | ES DLL new | Gobo DLL new |
|---|---|---|
| DLL smoke test | ✅ | ✅ |
| Test 2 (2,585 cases, `--jobs 16`) | ✅ identical (`1feb6129…`) | ✅ identical (`1feb6129…`) |
| `steps.c` 1-4 | ✅ 4/4 | ✅ 4/4 |
| `threads.c` 1-16 threads | ✅ 0 wrong | ✅ 0 wrong (2 GC settings) |
| `threads2` (8,000 parses, shared handler) / stress 20×8 | ✅ | ✅ 8,000/8,000, 0 failed |
| Eiffel test matrix (`run_eiffel_test_matrix.ps1`) | ✅ | – (ES only) |

## How this matches the background
| Background fact | This measurement | Match? |
|---|---|---|
| Standalone, 1 thread: ES 0.43 s, Gobo default 0.78 s, **Gobo tuned 0.38 s** ([table](../gobo-2026-11-16/README.md)) | DLL: ES 1.00×, Gobo default 0.59×, Gobo tuned 0.90× | ✅ default GC slower in both (0.55× vs 0.59×). ⚠️ Tuned: standalone beats ES, the DLL does not yet: the C bridge adds Gobo-specific cost (below). |
| Standalone Gobo **scales** with threads (4 threads 0.24 s) | DLL: no scaling, either compiler | ✅ expected: the global bridge lock, not Gobo. |
| Supervisor, Linux (GCC): Gobo 915 ms vs ES 1,550 ms (1.7× faster) | Windows, both msc: Gobo default 0.59× | ⚠️ Different. Suspected (not confirmed): Boehm's default GC settings on Windows, the C bridge, Linux vs Windows. Not the C compiler (Zig = msc here). |
| Gobo W3C profile identical to ES (1,974 / 0 / 0) | Test 2 result file byte-identical | ✅ |
| ES DLL vs Expat 17.15× after the speed-ups | 16.4× (all), 17.0× (1 MB) | ✅ same range |

*Update (section 4): profiled — the cause was Boehm finalizers from per-callback `C_STRING`s, not `eif_protect`; fixed.* Original guess: callback-heavy cells lose most (one small cell: 2.84 ms vs 0.90 ms ES). Each callback goes through `eif_adopt` / `eif_access` / `eif_wean`; Gobo implements `eif_protect` with an uncollectable Boehm allocation per object, and each `$feature` call looks up the thread context in thread-local storage.

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
- [x] Remove the global bridge lock for the Gobo build ([#418](https://github.com/andersoxie/xpact/issues/418)): 4 threads 0.40 s vs 0.61 s ES
- [x] Profile the callback path and reduce it (cause: finalizers, not `eif_protect`; string reuse, both builds)
- [x] GC tuning inside the DLL instead of environment variables
- [ ] Namespaces cells (0.74×) and 256 B-64 KB pieces (~0.89×): profile next
- [ ] Full 204-cell run of the new DLLs; W3C runner and C#/Python tests against the Gobo DLL
- [ ] Why scaling stops at 4 threads and 16 threads (0.56 s) is slower than 8 (0.41 s): [#431](https://github.com/andersoxie/xpact/issues/431)
- [ ] Gobo assertions variant of the DLL

## Limits
- One PC, Windows only; Gobo nightly 26.11.14 (the supervisor qualified 26.11.12).
- Section 4 speed: 1 MB inputs only (84 of 204 cells).
- Lock removal is Gobo-only; the ES DLL still serializes threads.
- **Multi-core means several parses at once**: one parse still runs on one core ([#432](https://github.com/andersoxie/xpact/issues/432)).
- Scaling stops at about 4 threads; 16 is slower than 8 (cause unknown, [#431](https://github.com/andersoxie/xpact/issues/431)).
- The Boehm GC uses up to 8 marker threads in the Gobo build (set in `gobo_dllmain.c`).
- Section 4 changes are not committed yet (waiting for the student's go).
