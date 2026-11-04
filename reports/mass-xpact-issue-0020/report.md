# Report: mass-xpact #20: static `STRING_8` scanner input, intermittent crash

> **Issue:** [CodTanium/mass-xpact#20](https://github.com/CodTanium/mass-xpact/issues/20) · **Branch:** `perf/static-string-input`, stacked on `perf/resume-text-runs` (#11)
> **Changed:** `src/xp_parser.e`
> **Status:** ⛔ **parked, do not merge** · cause unknown

## 1. In short

The change makes the parser's internal scanners take `a_input: STRING_8` instead of
`READABLE_STRING_8`. Calls such as `a_input [i]` are then statically bound and can be inlined,
which makes a whole parse about **20 % faster**. Every result check passes, but one Expat test
crashes intermittently, and often under GC stress. The previous build does not. Until the cause is
known, the change stays parked.

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
| Previous | ✅ 90 / 90 | ✅ 4 / 4 | 2 pass, 1 timeout (300 s, machine loaded), 0 crashes |
| Static input | ❌ 59 / 60 (1 × `0xC0000005`) | ❌ 5 / 6 (1 × `undefined entity`) | 1 pass, **2 crashes** |
| Static input, no `array_optimization` | 70 / 70 | | |
| Static input, `inlining=false` | | | 2 pass, **2 crashes** |

GC stress = `EIF_MEMORY_SCAVENGE=65536`, `EIF_FULL_COLLECTION_PERIOD=1`.
Logs: [repeat runs](logs/repeat-runs.tsv), [crash output](logs/fail-static-run2.txt),
[full-suite failure](logs/full-suite-run1-failure.txt), [GC stress](logs/gc-stress.txt).
Scripts: [flaky.ps1](logs/tools/flaky.ps1), [stress.ps1](logs/tools/stress.ps1).

### Investigation

- [x] `array_optimization` ruled out: the generated C is byte-identical with and without it, so the "no `array_optimization`" rows are the same code.
- [x] Inlining ruled out: the change also crashes with `inlining=false`.
- [x] Not a fluke of one run: crashes in normal runs, in a full suite run, and under GC stress.
- [ ] Faulting stack: a mini debugger ([minidbg.c](logs/tools/minidbg.c), Win32 debug API, `StackWalk64`) runs the test child (`--xpact-child 241`) under GC stress; no crash caught yet (the crash is intermittent).

### Cause

**Unknown.** Suspected: a GC-safety problem, a raw pointer to an Eiffel object kept across a
collection. It could be in the C bridge, or exposed by the changed allocation pattern. A wrong error
(`undefined entity`) next to access violations points to memory corruption, not to a logic
difference. Pure Eiffel code is GC-safe by construction, so the suspicion is on C code (bridge,
externals) or the runtime.

## 5. Next steps

- [ ] Catch the crash under the debugger and map the stack (`xpact.map` from a `-MAP` relink).
- [ ] Review the C bridge for pointers into Eiffel objects held across calls back into Eiffel.
- [ ] Run the same stress on the previous build more often, to rule out a latent bug that this change only makes more likely.
