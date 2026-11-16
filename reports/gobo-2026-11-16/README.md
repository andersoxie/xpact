# Gobo Eiffel for xpact: what the switch means (2026-11-16)

[← reports](../README.md) · related: [#304 multi-threading](../issue-0304/README.md) · [speed work](../perf-allocations/README.md) · supervisor's qualification: [docs/gobo-assertions.md](../../docs/gobo-assertions.md)

## In short
| Question | Answer |
|---|---|
| What is Gobo Eiffel? | A second, independent Eiffel compiler (`gec`, open source). Same Eiffel language and ECF files; its **own runtime, own garbage collector (Boehm GC)** and own base library (`free_elks`); C back end: bundled Zig (`gecc`) by default, or the system C compiler (`GOBO_CC=msc` = Visual Studio, as EiffelStudio uses; GCC on Linux). |
| What did the supervisor do? | Qualified the Gobo **26.11.12** nightly on 13 Nov (commit `aaa9181`, PRs #366/#367): all 21 + 7 assertion cases agree with EiffelStudio on Linux and Windows; reported 6 Gobo bugs that the Gobo author fixed. |
| Is it faster? | **Yes, on one thread and with GC tuned.** Supervisor (Linux, catalog × 10,000): Gobo **915 ms** vs EiffelStudio 1,550 ms (1.7×), assertions on 4,050 vs 15,400 ms (3.8×), Expat 245 ms. |
| Does it make multi-threading work? | **Yes, this is the big one.** The same xpact parser on N threads scales under Gobo and does not under EiffelStudio (measurements below). |
| Can programs use it through the C API (xpact.dll)? | ✅ **Yes, built and working** ([Gobo DLL report](../gobo-dll/README.md)): identical results, any thread. Not faster yet (0.59× default GC, 0.90× tuned) and not parallel yet (global bridge lock). |

## Our measurements on this PC (Windows 11, Ryzen 7 5800H, 8 cores / 16 threads)
Gobo **26.11.14+55e703f** (the nightly that replaced 26.11.12; official 7z, SHA-256 checked), EiffelStudio 25.12.
Test: [eiffel/xp_mt_parse_test.e](../issue-0304/eiffel/xp_mt_parse_test.e), the **unchanged** xpact parser on N Eiffel
threads (`WORKER_THREAD`), 16,000 parses of the threads.c document in total, median of 3 alternating runs, 0 wrong
results in every run. Builds: EiffelStudio ([mt_parse_test.ecf](../issue-0304/eiffel/mt_parse_test.ecf)), Gobo
([mt_parse_test_gobo_o2.ecf](../issue-0304/eiffel/mt_parse_test_gobo_o2.ecf), `gec --finalize --gc=boehm`).

| Threads | EiffelStudio | Gobo, default GC | Gobo, GC tuned¹ | Gobo, GC off (not usable, shows the limit) |
|---:|---:|---:|---:|---:|
| 1 | 0.44 s | 0.79 s | **0.39 s** | 0.36 s |
| 2 | 0.49 s | 0.69 s | – | 0.21 s |
| 4 | 0.63 s | 0.65 s | **0.24 s** | 0.15 s |
| 8 | 0.97 s | 0.99 s | 0.37 s | 0.11 s |
| 16 | 1.83 s | 1.24 s | 0.71 s | 0.12 s |
| Peak memory (1 / 4 / 16 threads) | 17 / 17 / 21 MB | 8 / 9 / 13 MB | 9 / 15 / 30 MB | – |

¹ `GC_FREE_SPACE_DIVISOR=1` (collect less often) and `GC_MARKERS=8` (parallel marking), environment variables, no rebuild.
Raw: [threads](../issue-0304/gobo-vs-es-threads-o2.txt) · [GC tuning](../issue-0304/gobo-gc-tuning.txt).

**Same C compiler for both (msc), as suggested on #304** (Gobo `GOBO_CC=msc`, median of 3, 0 wrong results):

| Threads | EiffelStudio (msc) | Gobo, Zig | Gobo, msc | Gobo, msc, GC tuned¹ |
|---:|---:|---:|---:|---:|
| 1 | 0.43 s | 0.77 s | 0.78 s | **0.38 s** |
| 2 | 0.49 s | 0.67 s | 0.68 s | 0.29 s |
| 4 | 0.63 s | 0.62 s | 0.64 s | **0.24 s** |
| 8 | 0.96 s | 0.83 s | 0.88 s | 0.34 s |
| 16 | 1.80 s | 1.13 s | 1.19 s | 0.71 s |

The C compiler makes almost no difference; the GC settings do. Raw: [threads-msc.txt](threads-msc.txt) · environment: [gobo-env.ps1](gobo-env.ps1) · tool: [thread_compare.py](thread_compare.py).

What this shows:
1. **EiffelStudio's runtime cannot use several cores in one process**: more threads are slower (one allocator lock +
   stop-the-world GC); see [#304](../issue-0304/README.md).
2. **Under Gobo the parser is thread-safe and scales**: with the GC off, 8 threads are 3.3× faster than 1; the parser
   itself is not the limit.
3. **The Boehm GC is the remaining limit.** It is already built with `THREAD_LOCAL_ALLOC` and `PARALLEL_MARK`; what costs
   is the number of stop-the-world collections. Collecting less often (`GC_FREE_SPACE_DIVISOR=1`) gives the best
   result: **4 threads 0.24 s = 1.8× the throughput of the best EiffelStudio setting**, at 15 MB peak memory.
   A bigger initial heap (`GC_INITIAL_HEAP_SIZE`) made it slower.
4. `-O2` made no difference with Gobo's built-in C compiler (it already optimises).

## Differences that matter
| | EiffelStudio 25.12 | Gobo 26.11 nightly |
|---|---|---|
| Garbage collector | own generational GC; multi-threaded runtime has one allocator lock | Boehm GC with thread-local allocation and parallel marking |
| Threads in one process (xpact) | slower with more threads | **scales to ~4 threads (tuned GC)** |
| C compiler | Visual Studio (msc_vc140) | Zig (`gecc`) by default, or Visual Studio with `GOBO_CC=msc`: **same speed** on this PC (table below) |
| Base library | EiffelBase (ELKS) | `free_elks` (ELKS-compatible); the parser compiled unchanged |
| Assertion modes | runtime option table per class | compiled in; 26.11 fixes make them agree with EiffelStudio (supervisor) |
| Release channel | stable releases | **nightly** (26.11.12 replaced by 26.11.14 within two days): pin the build you test |
| xpact.dll / C API | ✅ today | ✅ built ([report](../gobo-dll/README.md)); slower until the bridge is tuned |
| Tooling in this repo | test matrix, W3C runner, Sonar, website | benchmark ECF (`benchmarks/xpact_gobo_benchmarks.ecf`); on Windows/gecc it needs Gobo's runtime folder as include path (`src` uses `<eif_misc.h>`): [Windows copy](xpact_gobo_benchmarks_win.ecf) |

## What we can do with Gobo
- [x] Build and run the parser with Gobo on this PC (done: `gec` 26.11.14 in `%USERPROFILE%\tools\gobo-26.11.14`).
- [x] Show that multi-threaded parsing works and scales under Gobo (done, table above).
- [x] ✅ **W3C suite with Gobo** (profile, 2,585 cases, both assertion modes, one run with 4 engines): Gobo **1,974 passed,
      0 failed, 0 errors**, **0 cases different** from EiffelStudio ([summary](w3c-summary-es-vs-gobo.md)). The 611 cases
      outside the profile need `--all-cases`, whose external-entity lane uses the DLL checker (no Gobo DLL yet).
- [x] ✅ **Port the DLL to Gobo** (msc): done 2026-11-16, [report](../gobo-dll/README.md). Next: remove the global bridge lock
      so the C API gets Gobo's multi-threading, and reduce the callback cost.
- [ ] Set the GC tuning inside the program (Gobo implements the `MEMORY` GC controls since 26.11) instead of env vars.
- [ ] Reduce allocations in the parser further: helps both compilers and is now the main limit for threads.

## Limits of these measurements
- One PC, one small document type (the threads.c document); the full fair-speed matrix has not been run with Gobo.
- Gobo version differs from the supervisor's qualified 26.11.12 (26.11.14, two days newer).
- The tables above use the pure Eiffel API; the C API / DLL results are in the [Gobo DLL report](../gobo-dll/README.md).
