# #304 trial: a multi-threaded xpact.dll (2026-11-15)

[← reports](../README.md) · issue [#304](https://github.com/andersoxie/xpact/issues/304) · status: 🟡 **stopped**: second thread crashes; needs Eiffel-runtime knowledge (supervisor)

## Question
Can xpact.dll parse on several threads **at the same time**? Today (#274) calls from many threads are safe but take turns behind one lock, because the Eiffel runtime is built single-threaded (`concurrency support="none"`).

## What was tried (working tree only, not committed)
| Change | Where |
|---|---|
| Build tier `-BuildTier MultiThread` → `build/native-eiffel-mt/xpact_mt.dll` (own object folder, `/DEIF_THREADS`) | `scripts/build_native_eiffel.ps1` |
| ECF target `xpact_native_library_mt` = production target with `concurrency support="thread"` | `tests/xpact_native_library.ecf` |
| With `EIF_THREADS`: no global lock; each outside thread calls `eif_thr_register(1)` once and marks itself in/out of Eiffel (`EIF_EXIT_C` / `EIF_ENTER_C`, depth counter for re-entrant calls) | `native/xpact_eiffel_runtime_bridge.c` |
| The loading thread leaves Eiffel after `DllMain` initialized the runtime | `native/xpact_eiffel_dllmain.c` |

The build works: the DLL links `mtfinalized.lib` and the generated Makefile defines `EIF_THREADS` (build ~1 min).

## Result ([steps.c](steps.c))
| Step | Normal DLL `adae03d2…` | MT DLL |
|---|---|---|
| 1 Load the DLL | ✅ | ✅ |
| 2 Parse on the main thread | ✅ | ✅ |
| 3 Parse on a second thread | ✅ | ❌ access violation (`0xC0000005`) |
| 4 Two threads at once | ✅ | not reached |

Trace prints showed: the second thread **registers fine** (`eif_thr_is_initialized` 0 → `eif_thr_register(1)` → state ok); the crash comes in the **first Eiffel call on that thread** (`XML_ParserCreate`), with no other thread running, so it is not a race.

## Cause
**Unknown.** Checked and ruled out: the three `once` features in `src/` (`public_functions`, `name_start_ranges`, `name_extra_ranges`) compute their own values, so per-thread onces are harmless. Suspected (not confirmed): per-thread runtime setup that `DllMain` does by hand only for the first thread (`initsig`, `initstk`, the top-level exception vector `exset` + `setjmp`), or how the adopted `installer` object (`eif_adopt` on the first thread) is reached from another thread.

## Why stopped
Without a debugger on this PC every step is a rebuild + trace cycle; the next steps need knowledge of the Eiffel runtime's thread model (the supervisor's area, see also #13). Cost is uncertain (hours); the website does not need it (one worker process per document already parses in parallel).

## Next steps if continued
1. Install the Windows debugger (`cdb`, Windows SDK) and get the crash stack of `steps.exe xpact_mt.dll 3`.
2. Ask: what must a foreign thread do before calling Eiffel routines through `$` pointers in an MT finalized DLL (`exset`/`setjmp`? `eif_thr_register` enough?).
3. When steps 1-4 pass: `python -I reports/issue-0304/run_threads.py` (speed with 1-16 threads, correctness) and the W3C run on the MT DLL.

## Tools kept
- [steps.c](steps.c): step-by-step test of any xpact DLL on 1-2 threads.
- [run_threads.py](run_threads.py): builds the #274 thread tests against the normal and the MT DLL and times 1-16 threads on the same total work (note: add one warm-up run; a fresh exe's first start was slow, probably the virus scanner).

## Update 2026-11-16: further than the first stop

Debugger: WinDbg `cdbX64.exe` (already installed); the MT link step now writes `xpact_mt.pdb` (`-DEBUG`, MT tier only).

| # | Crash found with cdb | Cause (confirmed) | Fix (working tree) |
|---|---|---|---|
| 1 | 2nd thread, `{XP_NATIVE_BRIDGE_INSTALLER}.parser_create`+0x88: NULL at context+0x108 | the outside thread had no local-variable stacks / thread context | EiffelStudio's recipe for threads not created by Eiffel (`EIF_INITIALIZE_AUX_THREAD` in `eif_setup.h`): `eif_thr_register(1)`, `eif_set_thr_context()`, `initstk()` |
| 2 | 2 threads at once: `{HASH_TABLE}.force` in `parser_create` | all threads write the installer's shared `live_parser_ids` | `xp_registry_lock/unlock` (C, waits "in C" so GC cannot deadlock) around every table operation in the installer |
| 3 | (found by reading) `input_chunk` + `input_chunk_in_use` | one shared input buffer: two threads could parse each other's bytes (wrong results, no crash) | made them `once` = one per thread in the MT runtime, unchanged in the single-threaded build |

| Test | Result |
|---|---|
| `steps.c` steps 1-4 (2 threads × 2,000 parses at once) | ✅ |
| `threads.c` 2 / 8 / 16 threads under cdb | ✅ 8,000 / 32,000 / 64,000 parses, 0 wrong |
| `threads.c` 4 threads under cdb `-hd` (normal heap) | ❌ access violation in `eif_rt_xmalloc` ← `emalloc_size` ← parser code: memory corrupted earlier (cause **unknown**; suspect: GC moving objects while a raw pointer is held across a re-entrant call from a handler) |
| Speed, 1 thread, 32,000 parses | normal 0.86 s · MT 1.50 s (**MT 1.7× slower**: thread-context lookup + GC checks in every routine); `threads2` 2.10 s · 3.51 s |

## Update 2026-11-16 (2): narrowing the GC crash

| Experiment | Runs crashed (4 threads × 4,000) | Conclusion |
|---|---|---|
| GC on / GC off (`XPACT_GC_OFF=1` → `eif_gc_stop()`) | 6/6 / **0/6** | the crash needs the garbage collector |
| 1 thread × 16,000 / 64,000 parses (GC on) | 0/3 / 0/3 | GC alone is fine; it needs 2+ threads |
| plain document, no handler / DTD + handler | 4/4 / 3/4 | not the DTD, not the handlers |
| registry lock as a `blocking` external | 6/6 | not stale references around the lock wait |
| 100 warm-up parses on the main thread first | 4/6 | not lazily filled type caches |
| no per-thread `once` input buffer | 6/6 | not the per-thread buffer |
| per-thread tables, no registry lock at all | 6/6 | not the lock |

All-thread stacks at the crash: the crashing thread is in the runtime's type conformance code
(`eif_gen_conf2` → `rt_merged_annotation`) or the allocator (`eif_rt_xmalloc`) called from parser code; the
other threads wait normally in the allocator. Cause: **unknown**, inside the interplay of the multi-threaded
Eiffel runtime's GC with threads not created by Eiffel, or a thread-safety assumption in the parser classes.

## Update 2026-11-16 (3): pure-Eiffel thread test: the answer

[eiffel/](eiffel/) (`run.ps1`): XP_PARSER on N threads of EiffelStudio's own `WORKER_THREAD` (multi-threaded
runtime, no C bridge, no outside threads), 16,000 parses of the threads.c document in total, median of 3.

| Threads | Failed runs | Median |
|---:|---:|---:|
| 1 | 0/3 | 0.48 s |
| 2 | 0/3 | 0.50 s |
| 4 | 0/3 | 0.65 s |
| 16 | 0/3 | **1.83 s** |

1. ✅ The parser classes are thread-safe under the multi-threaded runtime: the remaining crash is in the bridge
   (outside threads joining the runtime), not in the parser.
2. ❌ **More threads are slower**, not faster: the runtime has one allocator behind a lock and a stop-the-world GC,
   and the parser allocates a lot, so the threads queue (the crash stacks always showed the other threads waiting in
   `eif_pthread_cs_lock` inside the allocator). Together with the 1.7× single-thread cost of the MT runtime, thread
   parallelism inside one process cannot make xpact faster with this runtime.

**Conclusion for #304:** do not pursue a multi-threaded xpact.dll for speed. Parallelism belongs at the process level
(one runtime per process): the website's worker processes, and test 2 with `--jobs` (5.4×, #197). A real gain inside
one process would need fewer allocations in the parser or a runtime without the global allocator lock: questions for
the supervisor, not quick fixes.
