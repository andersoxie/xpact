# Report: mass-xpact #68: between calls, the position pointed inside unfinished markup

> **Issue:** [CodTanium/mass-xpact#68](https://github.com/CodTanium/mass-xpact/issues/68), found by the acceptance run [#67](https://github.com/CodTanium/mass-xpact/issues/67) · **Branch:** `fix/68-pending-markup-position`, from `student-Mass` @ `7ba2687`
> **Changed:** `src/xp_parser.e`
> **Status:** ✅ fixed · ✅ verified · ⚠️ 12 CDATA calls left (section 5)

## 1. In short

`XML_GetCurrentLineNumber` / `ColumnNumber` / `ByteIndex` between `XML_Parse` calls, with no handlers, when a tag, comment, declaration or PI is not complete yet:

| | Expat 2.8.1 and `253c81e` | Before (`student-Mass`) | After |
|---|---|---|---|
| Position | the **start** of the unfinished markup | **inside** it, at the end of the input of the call that parsed it | ✅ the start |

All 3,061 W3C files, position after **every** call compared with Expat ([1 byte](logs/per-call-positions-chunk1.txt), [7 bytes](logs/per-call-positions-chunk7.txt)):

| Calls equal to Expat | `253c81e` | Before | After |
|---|---|---|---|
| 1 byte per call (495,725 calls) | 122,310 | 96,019 ❌ | ✅ **122,827** |
| 7 bytes per call (72,000 calls) | 14,863 | 11,720 ❌ | ✅ **15,357** |
| Calls where `253c81e` = Expat and we are not | | 26,295 / 3,147 | ✅ **5 / 7** (CDATA) |

**The final result of every file is unchanged**: status, error code, line, column and byte index, whole and in 1/7/16-byte pieces ([log](logs/final-results-unchanged.txt)).

## 2. The problem

| Field | |
|---|---|
| **Environment** | Windows 11, student PC2; EiffelStudio 25.12, `msc_vc140`; `student-Mass` @ `7ba2687`; baseline DLL `253c81e`; Expat 2.8.1 compiled into the same probe |
| **Command** | `callpos.exe <chunk> < files-8k.txt` ([source](logs/tools/callpos.c)), built with Expat and against `xpact.dll`; `cpcmp.py` / `cpkind.py` ([tools](logs/tools/)) |
| **Example** | `eduni/errata-2e/E36.xml`, line 3 `<foo bar="123⏎456"/>` at byte 71, byte by byte: Expat and `253c81e` report byte 71 on every call until the tag is complete; we reported byte 76 |
| **Cause** | ✔ Confirmed by the fix. `{XP_PARSER}.parse_prefix_tokens` moved `i` past unfinished markup to the end of the input and recorded that as the position. `253c81e` did the same, but parsed the whole document again on the next call and so came back to the markup start. Since #2, later calls that add nothing complete do not parse again, so the wrong position stayed. |

## 3. The change

- [x] `parse_prefix_tokens`: when unfinished markup (not a DOCTYPE, which reports its declarations so far) ends a non-final parse, the position is the markup start.
- [x] `parse_prefix_before_invalid_character`: this path parses the prefix in front of an invalid character to report the error **at that character**, also inside unfinished markup. It sets the position to the character again. A first version without this line moved the final error position of 72 W3C files away from Expat; it was found by the no-handler check and corrected before this result.

## 4. Verification

| Check | Result |
|---|---|
| ✅ Both tiers build | `System Recompiled.`, smoke `ok` |
| ✅ Final results, 3,061 W3C files, whole and 1/7/16-byte pieces | 0 files changed ([log](logs/final-results-unchanged.txt)) |
| ✅ Positions after every call | table in section 1 |
| ✅ DLL tests, 4,308 cases | 4,308 pass; `results.tsv` byte-identical to `student-Mass`, both tiers ([production](logs/dlltests-production-summary.txt), [assertions](logs/dlltests-assertions-summary.txt)) |
| ✅ W3C trace, 9 modes | byte-identical to `student-Mass`, both tiers ([production](logs/w3c-trace-sha256-production.txt), [assertions](logs/w3c-trace-sha256-assertions.txt)) |
| ✅ Test 2, 2,585 cases | byte-identical to `student-Mass`, both tiers |
| ✅ Expat 2.8.1 `runtests` | `Checks: 399, Failed: 38`, the same 38, both tiers ([production](logs/expat-runtests-production.txt), [assertions](logs/expat-runtests-assertions.txt)) |
| ✅ Eiffel test matrix | 4/4 lanes ok ([log](logs/matrix.txt)); the 4th lane first stopped with "Cannot create project directory" (environment, a lock), and passed when run again on its own |

## 5. Still open

12 calls inside **CDATA sections** ([1 byte](logs/still-worse-than-253c81e-chunk1.txt), [7 bytes](logs/still-worse-than-253c81e-chunk7.txt)): inside an opened CDATA section Expat moves on with the text, so its position is not the section start. A variant that excludes CDATA was measured (55,857 calls equal to Expat against 55,856) and not kept: no clear gain for an extra special case. This belongs to the CDATA position work (andersoxie#123, #171).

## 6. How to revert

Revert the commit; positions between calls point inside unfinished markup again.
