# Report: mass-xpact #72: the assertions DLL died on 7 fuzzed documents

> **Issue:** [CodTanium/mass-xpact#72](https://github.com/CodTanium/mass-xpact/issues/72), found by differential fuzzing in the acceptance run [#67](https://github.com/CodTanium/mass-xpact/issues/67) · **Branch:** `fix/72-loop-variants`, from `student-Mass` @ `950c004`
> **Changed:** `src/xp_parser.e`
> **Status:** ✅ fixed · ✅ verified

## 1. In short

On 20,000 fuzzed documents (each whole, byte by byte, in 7-byte and in random pieces), the **assertions** DLL ended the process on 7, with no output and no trace. `253c81e` has the same 7. The production DLL was right on all of them.

| Documents | Cause | Fix |
|---|---|---|
| 4, e.g. `</£` ([minimal](logs/minimal/)) | `parse_end_tag` returned **0** when `scan_name` rejected a non-ASCII character after `</`; the `parse` loop then broke its invariant `i >= 1` | Return past the input, as every other error branch does |
| 3, e.g. `<!ELEMENT doc (#PCDATA>` | In `parse_mixed_content_particle`, the iteration that reports a model without `)` left the loop variant unchanged | The variant also counts the error |

**After: 0 of 20,000 crash on both tiers** ([assertions](logs/fuzz-assertions-before-after.txt), [production](logs/fuzz-production-before-after.txt)).

Why there was no trace: separate issue [#73](https://github.com/CodTanium/mass-xpact/issues/73).

## 2. The problem

| Field | |
|---|---|
| **Environment** | Windows 11, student PC2; EiffelStudio 25.12, `msc_vc140`; `xpact_assertions.dll` of `253c81e` and `student-Mass` @ `950c004` |
| **Command** | `fuzzgen.py files-8k.txt fuzz 20000 67`, then `fuzzrun.py fuzzprobe-xpact.exe <dll dir> fuzz/list.txt out.tsv` ([tools](logs/tools/)) |
| **Error output** | Exit `0xC00000FF`. Stack from `exprobe.c` mapped with a link map (`mapstack.py`): `XML_Parse` → … → `{XP_PARSER}.parse` / `{XP_PARSER}.parse_mixed_content_particle` → `eviol` → `ereturn` → `longjmp` → `ntdll` |
| **Investigation** | Each document shrunk with `shrink.py` (remove bytes while the assertions DLL still dies): `<d>£</£`, `</` + U+0A03, `<t></` + U+0C45, `</` + BOM. First guess (the `parse` loop variant) did not fix them; the invariant did. |
| **Cause** | ✔ Confirmed: the 7 documents give the production result on the assertions DLL after the fix. |

## 3. Verification

| Check | Result |
|---|---|
| ✅ Both tiers build | `System Recompiled.`, smoke `ok` |
| ✅ Fuzz, 20,000 documents × 4 ways | assertions: 7 → **0** crashes; production: 0 crashes, **0 results changed** |
| ✅ The 7 documents | assertions output = production output; production output unchanged |
| ✅ No-handler W3C, 3,061 files, whole and 1/7/16-byte pieces | byte-identical to `student-Mass` |
| ✅ DLL tests, 4,308 cases | byte-identical to `student-Mass`, both tiers ([production](logs/dlltests-production-summary.txt), [assertions](logs/dlltests-assertions-summary.txt)) |
| ✅ W3C trace, 9 modes; Test 2, 2,585 cases | byte-identical to `student-Mass`, both tiers ([production](logs/w3c-trace-sha256-production.txt), [assertions](logs/w3c-trace-sha256-assertions.txt)) |
| ✅ Expat 2.8.1 `runtests` | `Checks: 399, Failed: 38`, the same 38, both tiers ([production](logs/expat-runtests-production.txt), [assertions](logs/expat-runtests-assertions.txt)) |
| ✅ Eiffel test matrix | 4/4 lanes ok ([log](logs/matrix.txt)); lane 4 again stopped with "Cannot create project directory" in the full run and passed alone (environment, separate issue) |

## 4. How to revert

Revert the commit; the 7 documents end the assertions DLL again.
