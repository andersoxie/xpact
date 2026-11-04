# Report: mass-xpact #20: static `STRING_8` scanner input, intermittent crash

> **Issue:** [CodTanium/mass-xpact#20](https://github.com/CodTanium/mass-xpact/issues/20) · **Branch:** `perf/static-string-input`, stacked on `perf/resume-text-runs` (#11)
> **Changed:** `src/xp_parser.e`
> **Status:** ⛔ **parked, do not merge** · cause unknown · the crash also happens **without** this change (latent bug, see the update in section 1)

## 1. In short

The change makes the parser's internal scanners take `a_input: STRING_8` instead of
`READABLE_STRING_8`. Calls such as `a_input [i]` are then statically bound and can be inlined,
which makes a whole parse about **20 % faster**. Every result check passes, but one Expat test
crashes intermittently, and often under GC stress. Until the cause is known, the change stays parked.

> **Update 3 (2026-11-04, afternoon): load matters more than the build; "#16 exposes it" is not proven.**
> With 12 stressed runs in parallel instead of 4, **every** build crashed: the parser chain **with `-keep`** 6 of 21, the candidate fix 5 of 8, #16 5 of 11 ([probe run 6](logs/probe-run6/runs.txt)), all with the same GC signature.
> The baseline's 24 of 24 below was measured at the lower load, so it doesn't compare. A paired batch (all four builds at the same time, same load) is running.
> #16 and #18 stay blocked until it's in.
>
> **Update 2 (2026-11-04): #16 exposes it** *(withdrawn by update 3: the comparison was not at equal load)*. `student-Mass` as is passed 24 of 24 stressed runs; `student-Mass` + #16 (finalize without `-keep`) failed 3 of 16 ([section 4](#investigation)). **Do not merge #16 or #18** until this is understood.
>
> **Update 2026-11-04: the bug is older than this change.** The previous build, which does not have
> this change, failed 4 of 16 stressed runs under the same load: 2 × `0xC0000005`, 1 × `undefined entity` and 1 other failure
> ([probe run 3](logs/probe-run3/runs.txt)). Its earlier 0 of 7 was luck. This change does not cause
> the corruption; how much it changes the failure rate is not measured.

| Production DLL, one `XML_Parse` call, no handlers | #11 + #16 + #18 | + this change |
|---|---:|---:|
| `pr-xml-utf-8.xml` (207 KB) | 14.1–14.2 ms | **11.3 ms** |
| `weekly-utf-8.xml` (2.7 KB) | 179–184 µs | **143–147 µs** |

## 2. The change

- [x] 87 signatures in `XP_PARSER` from `READABLE_STRING_8` to `STRING_8`: every `a_input`, `a_subset`, `a_content` and `a_data` parameter from the resumable-prefix section on, and `find_sequence`'s input.
- [x] The public entry points keep `READABLE_STRING_8` and convert once with the new `string_8_input`: the object itself when it is a `STRING_8`, else a copy.
- [x] `normalized_input` keeps its identity checks (`= a_input`) on the decoded value and reads through a `STRING_8` local.
- [x] `is_valid_name` and `declared_encoding` keep `READABLE_STRING_8` and read through a `STRING_8` local.
- [x] **No implicit conversions left.** A `READABLE_STRING_8` passed where `STRING_8` is expected compiles silently through the obsolete `as_string_8` (a copy at every call). The first attempt had 164 of these. [check.ps1](logs/tools/check.ps1) + [obs.py](logs/tools/obs.py) list them in 11 s; the final count is 0.

## 3. What passed (both tiers, compared with #11)

| Check | Result |
|---|---|
| ✅ `XpactDllTests` (4,308) | 4,308 / 4,308 ×2, `results.tsv` byte-identical |
| ✅ Traces + CRC | byte-identical, both tiers |
| ✅ Test 2 | TSV byte-identical, both tiers |
| ✅ Split-point check (1,852) | identical, both tiers |
| ❌ Expat 2.8.1 `runtests` | see section 4 |

## 4. The failure

`test_deep_nested_attribute_entity` builds 60,000 nested internal entities
(`<!ENTITY sN '&sN-1;'>`) and one attribute that references the last one, parsed one byte at a time.

| Build | Normal runs | Full suite runs | GC stress runs |
|---|---|---|---|
| Previous | ✅ 90 / 90 | ✅ 4 / 4 | 2 pass, 1 timeout (300 s, machine loaded), 0 crashes; **later 12 / 16 (2 × `0xC0000005`, 1 × `undefined entity`, 1 other failure)**, probe run 3 |
| Static input, **assertions tier** | | | 9 / 12, **3 × `0xC0000005`**, no assertion violation first (probe run 3) |
| Static input | ❌ 59 / 60 (1 × `0xC0000005`) | ❌ 5 / 6 (1 × `undefined entity`) | 1 pass, **2 crashes** |
| Static input, no `array_optimization` | 70 / 70 | | |
| Static input, `inlining=false` | | | 2 pass, **2 crashes** |
| **Paired run** (all three at the same time, same load): previous | | | ✅ 4 / 4 |
| **Paired run**: static input | | | ❌ 3 / 4 (1 × `0xC0000005`) |
| **Paired run**: static input, `inlining=false` | | | ❌ 3 / 4 (1 × `0xC0000005`) |

GC stress = `EIF_MEMORY_SCAVENGE=65536`, `EIF_FULL_COLLECTION_PERIOD=1`.
Logs: [repeat runs](logs/repeat-runs.tsv), [crash output](logs/fail-static-run2.txt),
[full-suite failure](logs/full-suite-run1-failure.txt), [GC stress](logs/gc-stress.txt).
Scripts: [flaky.ps1](logs/tools/flaky.ps1), [stress.ps1](logs/tools/stress.ps1).

### Investigation

- [x] `array_optimization` ruled out: the generated C is byte-identical with and without it, so the "no `array_optimization`" rows are the same code.
- [x] Inlining ruled out: the change also crashes with `inlining=false`.
- [x] Not a fluke of one run: crashes in normal runs, in a full suite run, and under GC stress.
- [ ] Faulting stack, in-process probe ([log](logs/probe-run1.txt), [probe.c](logs/tools/probe/probe.c)): the runner relinked with a vectored exception handler that writes the stack and a minidump on an access violation, with no debugger attached (checked with a test that faults on purpose, [selftest.c](logs/tools/probe/selftest.c)). In 12 stressed runs (4 in parallel) of the relinked static build without inlining: 11 pass, no access violation, and **one new wrong result**: `unclosed token (line 60002, offset 3)`, at the `<foo` start tag. That is a third symptom next to the crash and `undefined entity`.
- [x] **Faulting stack caught** (probe run 2, [log](logs/probe-run2.txt), [raw stack](logs/probe-run2-av.txt), [mapped stack](logs/probe-run2-av-mapped.txt)): 12 more stressed runs gave 1 access violation, 1 `deep_nested_attribute_entity` failure and 10 passes. The access violation is a read of `ffffffffffffffff` in the Eiffel GC's `hybrid_mark` (6 frames deep), in a partial scavenge that `special_malloc` started for `{HASH_TABLE}.make` ← `empty_duplicate` ← `accommodate` ← `put` ← `{XP_PARSER}.put_general_entity` ← `parse_entity_declaration` ← `process_dtd_subset` ← … ← `{XP_NATIVE_PARSER}.parse_with_current_gc_policy` ← `XML_Parse`. So the GC found a corrupted reference in a live object while the entity table grew. The corruption happened **earlier**; this stack only shows where it was detected. It fits the `undefined entity` symptom (a damaged entity table).
  The faulting instruction is `movzx ebp, word ptr [rdi-0Ch]` (`hybrid_mark` reading the header of the object it is about to mark; `dumpbin /disasm`). The reference in `rdi` is `0x0001_01d4_a58c_c1e8`: an ordinary heap pointer (compare `rbx` = `0x01d4_a58c_c1b8`) with byte 6 set to `0x01`. Suspected, not confirmed: a one-byte value (`True`, or a character `0x01`) written past the end of an array into a neighbouring object's reference field; the production tier does not check `SPECIAL` bounds.
- [x] No time or randomness in the sources: no clock, tick counter or random call in `src/` or `native/`; the hash salt is only stored.
- [ ] Faulting stack: not caught. Under a mini debugger ([minidbg.c](logs/tools/minidbg.c), Win32 debug API, `StackWalk64`) the test child (`--xpact-child 241`) passed 7 of 7 stressed runs, with and without the debug heap.
- [x] Follow-up ([log](logs/followup.txt)): the relinked DLL without the debugger passed 4 / 4 stressed runs, and the **original** no-inlining DLL, run again with nothing else on the machine, passed 4 / 4. All four stress crashes happened while another heavy job ran at the same time; the two non-stress failures (1 of 60 single runs, 1 of 6 suites) happened with nothing else running.
- [x] Load alone ruled out ([log](logs/paired-load.txt), [paired.sh](logs/tools/paired.sh)): the previous build and both static builds ran stressed at the same time, 4 runs each, so all three had the same load. The previous build passed 4 / 4; each static build crashed once (`0xC0000005`). Load makes the crash more likely, but the static change is what exposes it. Combined stress tally without a debugger: previous build 0 crashes in 7 runs (one of them a 300 s timeout), static builds 6 crashes in 23 runs (including the 4 relinked and 4 machine-idle runs).
- [x] Deep recursion ruled out: `resolved_general_entity_name` follows the 60,000 one-reference aliases in a loop, so the Eiffel call stack does not grow with the nesting depth.
- [x] Aliasing ruled out: `string_8_input` now passes the caller's `STRING_8` itself instead of a copy, but no scanner changes its `a_input`, `a_subset`, `a_content` or `a_data` in place.
- [x] No threads: neither the C bridge, the Eiffel sources (`concurrency support="none"`) nor the isolated runner's child starts a thread or a timer.
- [x] Memory pressure ruled out: the test child peaks at 69 MB private (101 MB on the previous build), on a 15.9 GB machine.

### Cause

**Unknown.** Three different symptoms (access violation, `undefined entity`, `unclosed token`) from the same deterministic input, with no clock, randomness or thread in the code, mean the parse depends on something outside the input: object addresses or memory contents. Suspected: a GC-safety problem, a raw pointer to an Eiffel object kept across a
collection. It could be in the C bridge, or exposed by the changed allocation pattern. A wrong error
(`undefined entity`) next to access violations points to memory corruption, not to a logic
difference. Pure Eiffel code is GC-safe by construction, so the suspicion is on C code (bridge,
externals) or the runtime.

## 5. Next steps

- [x] Stress the static change in the **assertions** tier ([runs](logs/probe-run3/runs.txt), [stacks](logs/probe-run3/)): 3 access violations in 12 runs (plus 2 in a first attempt that I stopped to fix the log capture), all in the GC, with **no** precondition violation first. An out-of-bounds write through Eiffel `SPECIAL` or `STRING_8` features would have raised one, so that is unlikely.
- [x] Stress the previous build more: **it fails too**, 4 of 16 (see section 1). The two previous-build crashes left no probe file; why is unknown.
- [x] Stress `student-Mass` @ `253c81e` + #16 (`build/nokeep`, before #11, #18 and this change) ([runs](logs/probe-run4/runs.txt)): **fails too**, 13 / 16, 3 × `0xC0000005`, all three in `hybrid_mark` at the same instruction. So the bug is older than #11, #18 and #21.
- [x] Minidump memory ([dump-memory.txt](logs/probe-run4/dump-memory.txt), [dumpmem.py](logs/tools/probe/dumpmem.py), [region.py](logs/tools/probe/region.py)):
  - In all three dumps the bad byte is `0x01` at an address ending in **`...38c9be`**. Only the low 24 bits match; the heap ranges, and the offset inside each range, differ (`2939be`, `3b59be`, `3b9be`).
  - What lives there differs: in two dumps it is the `area` field of a 29- or 6-character `STRING_8`, in the third an item of a `SPECIAL` of references. One damaged string's area holds `entity-decl:s10749:0:&s10748;`, an event string from `{XP_NATIVE_CALLBACK_HANDLER}.on_entity_decl`.
  - So something writes `0x01` to a computed address. Not a field of one particular object.
- [x] Stress `student-Mass` @ `253c81e` as is (with `-keep`, `build/baseline`) ([runs](logs/probe-run5/runs.txt)): ✅ **24 / 24 pass**, no access violation. With #16 added (the only difference is finalizing without `-keep`), the same sources failed 3 of 16. At that failure rate, 24 clean runs would happen by chance in less than 1 % of cases. So **#16 exposes (or introduces) the corruption**. The suspected mechanism is unverified: without `-keep`, the finalized routines lose their exception frames and assertion code, which changes the generated C and its GC-root handling.
- [ ] The static assertions build (with `-keep`, plus #11, #18 and #21) still crashed 3 of 12, so `-keep` alone does not prevent it once the later changes are in. Not explained yet.
- [x] Missing GC roots in the generated C, unlikely ([gc-registration.txt](logs/gc-registration.txt), [unreg-all.awk](logs/tools/probe/unreg-all.awk)): every routine that has reference locals and makes calls registers them (`RTLD`/`RTLI`/`RTLR`), both with `-keep` (4,940 routines) and without (880). A heuristic text check, not a proof: it does not see references held in C registers across inlined code.
- [x] Watchpoint run (`watch.c`, [logs](logs/watch-run1/), [mapped stack](logs/watch-run1/mapped.txt)): hardware write watchpoints on the heap addresses ending in `38c9be`, on the #16 DLL relinked with a map.
  - In two test children, a `0x01` was written there by `{SPECIAL}.force` ← `{HASH_TABLE}.put` ← `accommodate` ← `force` ← **`{XP_PARSER}.resolved_general_entity_name`** ← `include_general_entity_in_literal` ← `append_reference_in_literal` ← `parse_attribute`.
  - That routine keeps `l_seen: HASH_TABLE [BOOLEAN, STRING_8]` while it follows the 60,000 aliases. The write stores entry 2,694 (`True`) of its `BOOLEAN` array: the `0x01` run ends exactly at the watched byte and the bytes after it are still `00`. So **this write is legitimate**: the array really occupied that memory then. Neither child crashed.
  - **Suspected, not confirmed:** in every crash the corrupting byte is `0x01` = `True`, at an address `l_seen`'s array once occupied. So the corruption is probably a later `True` written through a stale reference to that array, after it moved or was freed. The generated `HASH_TABLE` setters do have the write barrier (`RTAR`), and every routine on the path registers its locals. The stale reference is not explained, and may be in the Eiffel runtime.
- [ ] **Candidate fix** ([branch `fix/20-seen-name-tables`](https://github.com/CodTanium/mass-xpact/tree/fix/20-seen-name-tables), `e1433da`): the three alias-following loops (`resolved_general_entity_name`, `append_parameter_entity_literal`, `resolved_parameter_entity_name`) use `HASH_TABLE [STRING_8, STRING_8]` instead of a `BOOLEAN` table. Same cycle check, no `BOOLEAN` array. DLL tests 4,308 / 4,308, `results.tsv` identical to the #16 build. ❌ **Does not fix the crash:** it crashed 5 of 8 under the 12-loop load (probe run 6). Kept as a branch only; not proposed for merging.
- [ ] Suspects now: an Eiffel reference that the GC does not see (a C bridge pointer or a local the generated code does not register) and that is used after a scavenge has moved the object.
- [x] Get a crash dump without a debugger attached (done with the in-process probe, see section 4) (Windows Error Reporting `LocalDumps` for `xpact_libexpat_runtests.exe`) and map it; the debugger seems to hide the crash.
- [ ] Find out why other load on the machine matters for a single-threaded parse. No thread or timer in the bridge or runner (checked); the Eiffel runtime itself is still unchecked.
- [ ] Review the C bridge for pointers into Eiffel objects held across calls back into Eiffel.
- [ ] Run the same stress on the previous build more often, to rule out a latent bug that this change only makes more likely. So far 0 crashes in 7 stressed runs, 4 of them under the same load as the crashing builds.
