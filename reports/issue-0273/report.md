# #273 An Eiffel exception inside a DLL call ends the process without a trace

> **Issue:** [andersoxie/xpact#273](https://github.com/andersoxie/xpact/issues/273) · **Branch:** `fix/273-dll-exception-guard` from `incremental-test` @ `e3934c3`
> **Changed:** `src/xp_native_bridge_installer.e`, `native/README.md`, one website test
> **Status:** ✅ fixed · ✅ verified (both DLL tiers)

## 1. In short

| | Before | After |
|---|---|---|
| Eiffel exception inside `XML_Parse` (here: "No more memory" under a 40 MB cap) | process dies: `0xC00000FF`, `0xC0000409` or `0xC0000005`, "PANIC: main entry point vanished", no trace | `XML_Parse` returns `XML_STATUS_ERROR`, `XML_GetErrorCode` = 1 `XML_ERROR_NO_MEMORY` |
| Same parser afterwards | — | answers safely (error code, line, column); `XML_ParserFree` works |
| New parsers in the same process | — | 200/200 parse correctly |
| Trace | none | printed to stderr with `XPACT_EXCEPTION_TRACE=1` |

## 2. The problem

| Field | |
|---|---|
| **Environment** | Student PC, Windows 11 Home, EiffelStudio 25.12, `msc_vc140`; `incremental-test` @ `e3934c3`; old DLLs `xpact.dll` `02B7F95B…`, `xpact_assertions.dll` `3EFEE772…` |
| **Command** | `python -I reports\issue-0273\inprocess.py <dll> 40` (this process caps itself at 40 MB, loads the DLL, parses a billion-laughs document with a character-data handler); `python -I reports\issue-0273\worker-oom.py <Xpact.Worker.exe> <dll> <build> 40` (website worker under a 40 MB Job Object) |
| **Expected** | An error code, like Expat's `XML_ERROR_NO_MEMORY`; the process keeps running |
| **Actual** | Old production DLL: `RUN-TIME root's set-up: main entry point vanished: Eiffel run-time panic`; old assertions DLL: `OSError 0xC00000FF`; worker: exit `0xC0000409` / `0xC0000005` ([log](logs/inprocess-before-after.txt)) |
| **Cause** | ✔ Confirmed: the only Eiffel exception handler on the stack was the root one set up in `native/xpact_eiffel_dllmain.c`, whose `jmp_buf` lives in the frame of the DLL initialisation that has already returned. The runtime's own message names it ("main entry point vanished"). |

## 3. The fix

Every one of the 49 native entry features of `XP_NATIVE_BRIDGE_INSTALLER` (what the C trampolines call) got a guard:

```eiffel
	parse (...): INTEGER
		local
			l_failed: BOOLEAN
		do
			if l_failed then
				record_failure (a_parser)      -- parser marked failed, error code stored
				Result := 0                    -- XML_STATUS_ERROR
			else
				... unchanged body ...
			end
		rescue
			if not l_failed then
				l_failed := True
				retry                          -- the rescue itself allocates nothing
			end
		end
```

- Failure values follow Expat: `XML_STATUS_ERROR`, `NULL` (create, `XML_GetBuffer`), `0`/`False`.
- A failed parser may be half updated, so it is **never called again**: `parser_for` skips it, `XML_GetErrorCode` returns the stored code (`XML_ERROR_NO_MEMORY` for `NO_MORE_MEMORY`, otherwise `XML_ERROR_UNEXPECTED_STATE` = 23, "please send a bug report"), `XML_ParserFree` releases it.
- `parser_create`'s postconditions now hold only when no failure was recorded (it returns `NULL` on failure, as Expat does).
- `XPACT_EXCEPTION_TRACE=1` prints the Eiffel trace to stderr.

## 4. Verification

| Check | Result |
|---|---|
| ✅ Both tiers build, smoke | `xpact.dll` `3AB5C4E8…`, `xpact_assertions.dll` `96AF5A72…`, smoke `ok` ([log](logs/build-dll.txt)) |
| ✅ In-process probe, before → after | crash → `code=1 (out of memory)`, failed parser answers, 200/200 new parsers; **both tiers** ([log](logs/inprocess-before-after.txt)) |
| ✅ Website worker under 40 MB | crash → `rejected`, code 1, exit 0, both tiers |
| ✅ Trace switch | `XPACT_EXCEPTION_TRACE=1` prints the trace (`HASH_TABLE.make` … `No more memory`) |
| ✅ C# DLL tests, 4,308 cases | old vs new DLL: **0 rows differ** in any result column, both tiers ([production](logs/dll-tests-xpact-summary.txt), [assertions](logs/dll-tests-xpact_assertions-summary.txt)) |
| ✅ W3C, 2,585 cases, Finalized + FinalizedAssertions | 2,283 passed, 302 no-crash-only, **0 failed, 0 unexpected**: same as the 2026-11-08 baseline ([log](logs/w3c-and-benchmarks.txt)) |
| ✅ Eiffel test matrix | `ok`, all lanes ([log](logs/eiffel-matrix.txt)) |
| ✅ Python suite, 239 tests | 238 ok in the parallel run; the 1 failure (`test_libexpat_isolation`, a 1 s fixture timeout in the test runner's own self-test, no xpact DLL involved) passed 3/3 when rerun alone: load from the parallel Eiffel compile ([log](logs/python-suite-parallel.txt)) |
| ✅ Website tests | 37/37; `The_memory_cap_stops_a_worker_that_needs_more` now expects `rejected` + code 1 instead of `crashed` |

## 5. Notes and limitations

- ⚠️ `scripts/run_benchmarks.ps1` rebuilds `build\native-eiffel\xpact.dll` (line 204/372): after the W3C run its hash was `34FA35DD…` instead of the tested `3AB5C4E8…` (same source, not byte-identical). The tested DLLs were copied back. Worth an issue of its own.
- The root exception vector in `xpact_eiffel_dllmain.c` still points at the finished frame; it is no longer reached from the API, but code outside the installer's features (DLL load itself) is not guarded.
- An access violation inside a **user's** C callback is turned into an Eiffel exception by the runtime and now becomes `XML_ERROR_UNEXPECTED_STATE` instead of a crash; with `XPACT_EXCEPTION_TRACE=1` it is visible.
- If memory is still exhausted while recording the failure (in the retry branch), the second exception is not caught (the guard retries only once).
- Possibly related, not rechecked: andersoxie#13 (GC section swallows exceptions), CodTanium/mass-xpact#20 (traceless heap corruption).
