# #274 xpact.dll is not thread-safe: two threads with their own parsers crash it

> **Issue:** [andersoxie/xpact#274](https://github.com/andersoxie/xpact/issues/274) · **Branch:** `fix/274-serialize-dll-calls` from `incremental-test` @ `891570c`
> **Changed:** `native/xpact_eiffel_runtime_bridge.c`; docs in `include/xpact.h`, `native/README.md`, `README.md`
> **Status:** ✅ fixed (calls serialized) · ✅ verified · 🟡 parallel parsing still open (needs a multi-threaded Eiffel runtime, supervisor decision)

## 1. In short

| Threads, each with its own parser | Before | After |
|---|---|---|
| 1 | ✅ 2,000/2,000 | ✅ 2,000/2,000 |
| 2, 4, 8, 16 | 🔴 segmentation fault (production) / crash or hang (assertions) | ✅ all correct (up to 32,000 parses) |
| 8, handlers calling back into xpact, 7-byte pieces | 🔴 segmentation fault | ✅ 16,000/16,000 |
| Single-thread speed (1 × 20,000 parses, 5 alternating runs) | median 584 ms | median 583 ms: **no cost** |

Calls now **take turns**: safe from any number of threads, but not faster than one thread.

## 2. The problem

| Field | |
|---|---|
| **Environment** | Student PC, Windows 11 Home, EiffelStudio 25.12, MSVC (VS 18); `incremental-test` @ `891570c`; old DLL `xpact.dll` `3AB5C4E8…` |
| **Command** | `threads-xpact.exe <threads> 2000` ([threads.c](threads.c), from the acceptance run), `threads2-xpact.exe <threads> 1000` ([threads2.c](threads2.c), new); build: [build-thread-tests.ps1](build-thread-tests.ps1) (links `build\native-eiffel\xpact.lib`) |
| **Expected** | Like Expat: every parse correct with 1, 2, 4 threads |
| **Actual** | 1 thread correct; 2+ threads: `Segmentation fault` (exit 139); assertions DLL: also exit 127 / timeout |
| **Cause** | ✔ Confirmed: `xpact.ecf` has `<concurrency support="none"/>`; the Eiffel runtime's GC, object table and exception stack are process globals without locks. |

## 3. The fix

Every Eiffel call goes through one of the 48 `xp_rt_*` trampolines in `native/xpact_eiffel_runtime_bridge.c`. Each became a locked wrapper around the unchanged body:

```c
static enum XML_Status XMLCALL
xp_rt_parse(void *context, void *parser, const char *s, int len, int isFinal) {
	enum XML_Status result;
	xp_eiffel_lock_enter();              /* one process-wide CRITICAL_SECTION */
	__try {
		result = xp_rt_parse_body(context, parser, s, len, isFinal);
	} __finally {
		xp_eiffel_lock_leave();          /* also if the call is left by an exception */
	}
	return result;
}
```

- `CRITICAL_SECTION` is **re-entrant**: a handler that calls `XML_GetCurrentLineNumber` etc. on its own thread works (tested).
- Initialised once with `InitOnceExecuteOnce`; spin count 4000.
- A first version wrapped the bodies directly (`return` inside `__try`): **8 % slower** single-threaded (median 569 → 615 ms), because each `return` ran MSVC's local unwind. The wrapper form removed that cost.
- Non-Windows builds stop with `#error` until they get a lock (Linux packaging is deferred anyway).

## 4. Verification

| Check | Result |
|---|---|
| ✅ Both tiers build, smoke | `xpact.dll` `ADAE03D2…`, `xpact_assertions.dll` `75F43A5B…` ([log](logs/build-dll.txt)) |
| ✅ threads.c 1/2/4/8/16 threads, both tiers | all correct ([log](logs/threads-after.txt)) |
| ✅ threads2.c (pieces + re-entrant handlers) 1/8 threads, both tiers | all correct; on the old DLL it crashes (exit 139) |
| ✅ Stress: 20 × threads.c + 20 × threads2.c, 8 threads, both tiers | 0 / 40 failed runs per tier |
| ✅ Single-thread timing, old vs new, 5 alternating runs | 584 vs 583 ms (PC not idle; same conditions for both) |
| ✅ C# DLL tests, 4,308 cases | old vs new: **0 rows differ**, both tiers ([production](logs/dll-tests-xpact-summary.txt), [assertions](logs/dll-tests-xpact_assertions-summary.txt)) |
| ✅ #273 probe (exception → error code) | PASS ([log](logs/issue-0273-probe.txt)) |
| ✅ Python suite | 239/239 OK ([log](logs/python-suite.txt)) |
| ✅ Eiffel test matrix | ok ([log](logs/eiffel-matrix.txt)) |
| ✅ W3C 2,585 cases, both builds | 2,283 passed, 0 failed (same as baseline) ([log](logs/w3c-and-benchmarks.txt)); the run rebuilt the DLL (#302), the tested DLLs were copied back |
| ✅ Website tests | 37/37 |

## 5. Limitations and open questions

- 🟡 **No parallel speed-up:** 4 threads take about as long as one thread doing the same work. Real parallel parsing needs a multi-threaded Eiffel runtime (`concurrency support="thread"`): 2-5 days, may be slower per call, may show new bugs. **Question for Anders: needed for 1.0?**
- A handler must not block waiting for **another** thread that calls xpact (deadlock); documented in `include/xpact.h`.
- One parser used by two threads at the same time is still not allowed (same rule as libexpat).
- Tested on one PC (8+ cores); not tested with thread pools that create and destroy threads very often.
