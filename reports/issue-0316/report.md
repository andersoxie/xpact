# #316 · Under a small memory cap the worker can crash in the DLL instead of reporting out of memory

| | |
|---|---|
| Status | 🟡 **investigated, not fixed** · parked by the student (2026-11-12) |
| Issue | [#316](https://github.com/andersoxie/xpact/issues/316) |
| Impact | low: the document is always stopped and the site keeps serving; with the normal 512 MB cap the same document is rejected with code 43 |
| Evidence | [cap-sweep-2026-11-12.txt](cap-sweep-2026-11-12.txt) |

## 1. Problem
The nested-entity document (10 levels × 10) under a 40 MB worker cap should end as `rejected`, code 1 `XML_ERROR_NO_MEMORY` (#273). In the website's Docker image it sometimes ends as `crashed`, with the worker printing "Stack overflow.".

- **Environment:** student PC, Windows 11 Home, `incremental-test` @ `fff0d2d`, worker and DLL from release `website-2026-11-12-1` (`xpact.dll` `ADAE03D2…`); GitHub Actions `windows-2022` with the same image.
- **Command:** `scratchpad cap_sweep.ps1`: one `Xpact.Worker.exe` per run under a Job Object `ProcessMemoryLimit` with the API's flags, the document on stdin.
- **Expected:** `rejected` code 1 whenever the cap is reached.
- **Actual:** see below.

## 2. What was found

| | Finding |
|---|---|
| ✅ | **A race, also in CI.** Same image and document in today's two runs: PR run 43138345877 → code 1; publish run 43138936736 → stack overflow |
| ✅ | **Not container-specific.** Reproduced on the PC without a container: 18–22 MB → stack overflow every run; 24–26 MB → mostly access violation `0xC0000005`; ≥ 30 MB → code 1 (30 of 30). The container uses more memory before the parse, so there the edge is at ~40 MB |
| ✅ refuted | **"A refused stack-page commit"** (the first suspected cause). Parsing on a thread with a 16 MB stack, 8 MB committed in advance, still overflowed, and at 26–30 MB too (the committed stack used part of the budget). Change reverted, never committed |
| ✅ | **The overflow is in native code.** With `XPACT_EXCEPTION_TRACE=1` the only output is "Stack overflow.": no .NET frames, no Eiffel trace |
| ❓ suspected | The out-of-memory path in the Eiffel runtime or the DLL recurses (allocation fails → exception → handling needs memory → …), or the GC recurses over the deep entity structure. The access violations suggest an unchecked failed allocation. **Not verified** |

## 3. Cause
❔ **Unknown** (narrowed to native code in the DLL / Eiffel runtime).

## 4. Fix
None yet. The Docker workflow keeps accepting `rejected` code 1 **or** `crashed` for this check (it still requires that the document is stopped and the site keeps serving).

## 5. Next step
WinDbg is installed on the student PC (1.2611.4001.0, `cdb.exe`, 2026-11-12). Build a copy of the DLL with symbols in a separate folder (the tested DLL stays unchanged), run one worker at a 20 MB cap under `cdb`, read the native stack of the overflow, then decide the fix with the supervisor (the code is likely his).

## Verification
Not applicable yet (no fix). The evidence above is reproducible with the sweep in the log file.
