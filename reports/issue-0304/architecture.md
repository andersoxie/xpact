# How xpact.dll is built, and where multi-threading fits (#304)

[← #304 trial](README.md)

## 1. The layers: who calls whom

```
 ┌───────────────────────────────────────────────────────────────────────────┐
 │  YOUR PROGRAM (C, C#, Python, the website worker)                         │
 │  calls the Expat API:  XML_ParserCreate · XML_Parse · XML_ParserFree ...  │
 └───────────────────────────────┬───────────────────────────────────────────┘
                                 │  exported functions (include/xpact.h)
 ┌───────────────────────────────▼───────────────────────────────────────────┐
 │  C SHIM            native/xpact_native.c                                  │
 │  the XML_* functions; keeps the C-side parser struct and handler pointers │
 └───────────────────────────────┬───────────────────────────────────────────┘
                                 │  xp_rt_* trampolines
 ┌───────────────────────────────▼───────────────────────────────────────────┐
 │  RUNTIME BRIDGE    native/xpact_eiffel_runtime_bridge.c                   │
 │  every call:  xp_eiffel_lock_enter()  →  call into Eiffel  →  leave()     │
 │  ★ TODAY (#274): one process-wide lock → calls take turns                 │
 │  ★ TRIAL (#304): no lock; each thread registers with the Eiffel runtime   │
 └───────────────────────────────┬───────────────────────────────────────────┘
                                 │  calls Eiffel routines through $pointers
 ┌───────────────────────────────▼───────────────────────────────────────────┐
 │  EIFFEL RUNTIME    (EiffelStudio: finalized.lib or mtfinalized.lib)       │
 │  garbage collector · memory · exceptions · once-values · thread contexts  │
 │  started once by native/xpact_eiffel_dllmain.c when the DLL is loaded     │
 └───────────────────────────────┬───────────────────────────────────────────┘
                                 │
 ┌───────────────────────────────▼───────────────────────────────────────────┐
 │  EIFFEL PARSER     src/*.e                                                │
 │  XP_NATIVE_LIBRARY_ROOT (start) → XP_NATIVE_BRIDGE_EXPORT / _INSTALLER    │
 │  → XP_NATIVE_PARSER → XP_PARSER (9,552 lines: the XML 1.0 parser)         │
 │  events go back out through XP_NATIVE_CALLBACK_HANDLER                    │
 └───────────────────────────────┬───────────────────────────────────────────┘
                                 │  "start element", "text", ... callbacks
                                 ▼
                 back up through the bridge to YOUR handler functions
```

The DLL is built by `scripts/build_native_eiffel.ps1`: the C files are compiled with `cl`, the Eiffel
classes are finalized by `ec` from `tests/xpact_native_library.ecf`, and everything is linked into one DLL.

## 2. One call, step by step

```
your thread            C shim              bridge                  Eiffel
───────────            ──────              ──────                  ──────
XML_Parse(p, buf) ──►  XML_Parse()  ──►  xp_rt_parse()
                                          lock_enter() ─────────►  installer.parse(p, buf)
                                                                     XP_PARSER scans bytes
                                          ◄── callback ──────────    "start element <a>"
your StartElement ◄──  handler ptr  ◄──  (still inside the lock)
handler returns   ──►              ──►                      ──►    continues scanning
                                          lock_leave() ◄────────    returns status
status            ◄──              ◄──
```

## 3. Three levels of parallelism

```
 LEVEL A: PROCESSES (works today, used by the website)
 ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
 │ worker 1    │ │ worker 2    │ │ worker 3    │ │ worker 4    │   each process has its OWN
 │ xpact.dll   │ │ xpact.dll   │ │ xpact.dll   │ │ xpact.dll   │   DLL copy + Eiffel runtime
 │ runtime     │ │ runtime     │ │ runtime     │ │ runtime     │   → truly parallel, no sharing
 └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘   (also: test 2, #197: 16×)

 LEVEL B: THREADS, ONE PROCESS, TODAY (#274)
 thread 1 ──► [ LOCK ] ──► Eiffel runtime (single-threaded)          safe, but only ONE thread
 thread 2 ──►  waits   ┘                                             is inside at a time
 thread 3 ──►  waits   ┘                                             → no speed-up

 LEVEL C: THREADS, ONE PROCESS, TRIAL (#304)
 thread 1 ──► register ─┐
 thread 2 ──► register ─┼──► Eiffel runtime (multi-threaded)         all parse at the same time
 thread 3 ──► register ─┘     shared: GC heap, installer object      → N× faster (in theory)
                              per thread: context, exception stack,
                                          once-values
```

## 4. What is shared and what is per thread in the multi-threaded runtime

| Thing | Single-threaded runtime (today) | Multi-threaded runtime (trial) |
|---|---|---|
| Heap and garbage collector | one | one, **shared**: GC stops all threads that are "in Eiffel" |
| `once` values (3 in `src/`) | one per process | **one per thread** (recomputed: harmless here) |
| Exception stack / handler | one, set up in `DllMain` | **one per thread**: `DllMain` sets it up only for the loading thread ⚠️ |
| The `installer` object (bridge) | one | one, created on the loading thread, used by all |
| Parser objects | one per `XML_Parser` | same; each thread uses its own parsers |
| Thread context (`GTCX`) | none | **per thread**: created by `eif_thr_register` |

## 5. Where the trial stops today

```
 step 1  load DLL                  ✅  (runtime starts on the loading thread)
 step 2  parse on that thread      ✅
 step 3  parse on a NEW thread     ❌  register ✅ → state ✅ → first Eiffel call (XML_ParserCreate) 💥
```
Suspects (⚠️ above): the new thread has no top-level exception handler (`exset` + `setjmp`, as in
`DllMain`), or something else `DllMain` prepares only for the first thread (`initsig`, `initstk`).

## 6. How you can help, in parallel
- [ ] **Get the crash stack:** install WinDbg (`winget install Microsoft.WinDbg`), then
      `cdb -g -G build\issue-0304\mt\steps.exe build\issue-0304\mt\xpact_mt.dll 3` and send the `kb` output.
- [ ] **Look up in the EiffelStudio docs** (CECIL / threads): what a thread **not created by Eiffel** must do before calling Eiffel routines in a multi-threaded system.
- [ ] Ask Anders the same question (he wrote `XP_GC_CRITICAL_SECTION`, #13).
