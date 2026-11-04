# Report: mass-xpact #3: assertions DLL exits with `0xC0000028` on `ibm68n03.xml` with only a default handler

> **Issue:** [CodTanium/mass-xpact#3](https://github.com/CodTanium/mass-xpact/issues/3) · **Branch:** `fix/3-default-handler-reference`, from `student-Mass` @ `8d187a7`
> **Changed:** `src/xp_parser.e` (three call sites, one new helper)
> **Status:** ✅ fixed · ✅ verified (see section 4)

## 1. In short

With only a default handler set, the parser checks whether the text between `&` and `;` names a
predefined entity (`lt`, `amp`, ...). It passed that text to `is_predefined_entity` even when the
text is not a name at all, as in `& aaa;` (a space after `&`). `is_predefined_entity` requires a
valid name. The assertions DLL raised the precondition violation inside the C callback chain, could
not unwind through the C frames, and the process ended with `0xC0000028` (STATUS_BAD_STACK). It
printed no output and no trace. The production DLL has no contract checks; `is_predefined_entity`
just returned `False` there, and the document was rejected correctly.

The fix asks `is_valid_name` first. For every string it gives the same answer the production DLL
already gave, so production behaviour is unchanged.

## 2. The problem

| Field | |
|---|---|
| **Environment** | Windows 11, student PC2; EiffelStudio 25.12.9.8922, `msc_vc140`, MSVC (VS 18); `student-Mass` @ `8ccf51b`, assertions tier. First seen on `253c81e`. |
| **Command** | `trace.exe default 100000 < one.txt` (one line: `xmlconf\ibm\not-wf\P68\ibm68n03.xml`; `XML_ParserCreate(NULL)`, `XML_SetDefaultHandler` only). Tool: `reports/mass-xpact-issue-0002/tools/trace.c` |
| **Expected** | Reject the document, as the production DLL does: `status=0 error=4` at line 7, column 32 |
| **Actual** | Exit code `0xC0000028`, no output at all ([trace](logs/trace-before-assertions.txt) is empty) |
| **Input** | `<root>extra space after ampsand & aaa;</root>` after a DOCTYPE that declares `aaa` (W3C `ibm-not-wf-P68-ibm68n03.xml`) |

## 3. Investigation and cause

- [x] `trace.exe` linked with [exprobe.c](logs/tools/exprobe.c): a vectored exception handler that logs every exception with its stack. No debugger is attached.
- [x] The assertions DLL relinked with a link map ([relink-map2.ps1](logs/tools/relink-map2.ps1)), and the frames mapped to Eiffel features through the generated C.
- [x] **Stack** ([raw](logs/exception-before.txt), [mapped](logs/exception-before-mapped.txt)), innermost first:
  - `longjmp` ← `ereturn` ← **`eviol`** (an Eiffel contract violation)
  - ← **`{XP_PARSER}.is_predefined_entity`** ← (a static C function: the caller) ← `{XP_PARSER}.parse` ← `{XP_NATIVE_PARSER}.parse` ← `XML_Parse`
- [x] **Cause ✔ confirmed:** `is_predefined_entity` has `require valid_name: is_valid_name (a_name)`. Three call sites pass `a_input.substring (i + 1, end - 1)` unchecked:
  - Line 1472, a scan of references in a literal.
  - Lines 2830 and 3074, the literal default-handler path for references in character data.
  - With the input `& aaa`, that text is `" aaa"`, which isn't a name.
- [x] Why it only shows with a default handler: the two character-data call sites only run when `l_literal_default` is true, i.e. when a default handler gets literal text.

## 4. The change

- [x] New query `is_valid_predefined_entity_name (a_name)`, defined as `is_valid_name (a_name) and then is_predefined_entity (a_name)`.
- [x] The three call sites use it.
- [x] Equal to the old production result for every string. The five predefined names are all valid names, so no invalid string can match one. So production behaviour can't change.

## 5. Verification

| Check | Result | Evidence |
|---|---|---|
| ✅ The failing case, assertions DLL | Exit 0; the same 24-line trace as production, `END@7:32:138 status=0 error=4` | [after](logs/trace-after-assertions.txt) |
| ✅ The failing case, production DLL | Byte-identical to before the fix | [before](logs/trace-before-production.txt), [after](logs/trace-after-production.txt) |
| ✅ Both tiers build | `System Recompiled.`; smoke `ok` | |
| ✅ DLL tests (4,308 cases), both tiers | 4,308 / 4,308; `results.tsv` byte-identical to `student-Mass` @ `8ccf51b`, both tiers | [production](logs/dlltests-production-summary.txt), [assertions](logs/dlltests-assertions-summary.txt) |
| ✅ W3C trace (`run-tools.ps1 -Run Trace`: events, default, suspend, abort; byte by byte, 7-byte pieces, whole), both tiers | All 9 trace files of the fix, **both tiers**, byte-identical to `student-Mass` production. Before the fix, the assertions DLL's two `default` traces stopped at this document (19,484 and 16,449 lines against 53,953 and 47,076) | SHA-256: [sm production](logs/w3c-trace-sha256-sm-prod.txt), [sm assertions](logs/w3c-trace-sha256-sm-asrt.txt), [fix production](logs/w3c-trace-sha256-fix3-prod.txt), [fix assertions](logs/w3c-trace-sha256-fix3-asrt.txt) |
| ✅ Expat 2.8.1 `runtests`, both tiers | `Checks: 399, Failed: 38` on both, the same 38 test names as before (the allocator tests) | [production](logs/expat-runtests-production.txt), [assertions](logs/expat-runtests-assertions.txt) |

## 6. How to revert

Revert the commit. The three call sites go back to `is_predefined_entity`, and the assertions DLL crashes again on this input.
