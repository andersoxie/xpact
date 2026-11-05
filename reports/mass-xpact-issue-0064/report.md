# Report: mass-xpact #64: without an external-entity handler, documents with external entities failed with code 21

> **Issue:** [CodTanium/mass-xpact#64](https://github.com/CodTanium/mass-xpact/issues/64), part of the Expat comparison work ([andersoxie/xpact#170](https://github.com/andersoxie/xpact/issues/170)) · **Branch:** `fix/64-unread-external-entities`, from `student-Mass` @ `e843e61`
> **Changed:** `src/xp_parser.e`, `src/xp_native_parser.e`
> **Status:** ✅ fixed · ✅ verified

## 1. In short

When no `XML_SetExternalEntityRefHandler` is set, Expat **reads no external entities and reports no error**. XPact used to reject such documents with code 21, `XML_ERROR_EXTERNAL_ENTITY_HANDLING`.

Now XPact behaves like Expat. In the whole-document comparison with Expat 2.8.1 over 3,061 W3C files, **verdict differences dropped from 24 to 4**:

| Comparison (3,061 files, no handlers, one final `XML_Parse`) | Before (`e843e61`) | After |
|---|---|---|
| Different verdict (accepted / rejected) | 24 | ✅ **4** |
| Same verdict, different error code | 361 | 361 (#170) |
| Same code, different line or column | 1,152 | 1,152 (#171) |
| Identical | 1,524 | ✅ **1,544** |

The 20 files that changed are the 20 code-21 cases, and each one now matches Expat exactly (status, code, line, column, byte index). **No other file changed** ([diff](logs/before-after-diff.txt); [Expat](logs/whole-expat-2.8.1.tsv), [before](logs/whole-xpact-before.tsv), [after](logs/whole-xpact-after.tsv)).

## 2. The problem

| Field | |
|---|---|
| **Environment** | Windows 11, student PC2; EiffelStudio 25.12, `msc_vc140`, MSVC (VS 18); `student-Mass` @ `e843e61`; Expat 2.8.1 compiled into the same probe |
| **Command** | `nohprobe.exe 0 < files-8k.txt` ([source](logs/tools/nohprobe.c)), built once with Expat and once against `xpact.dll` |
| **Expected** | Expat's result, e.g. `xmltest/valid/sa/097.xml` (`<!ENTITY % e SYSTEM "097.ent"> %e;`) accepted |
| **Actual** | Rejected, code 21, in 20 files: `xmltest/valid/sa/097`, `xmltest/valid/not-sa/011`, `012`, `026`, `ibm68v02`, `ibm69v02`, `ibm70v01`, `ibm79v01`, `ibm68i03`/`04`, `ibm69i03`/`04`, `ibm77n03`/`04`, `ibm79n01`/`02`, `eduni/errata-2e/E18`, `E60`, `eduni/xml-1.1/002`, `sun/not-wf/decl01` |
| **Cause** | ✔ Confirmed by the code. In Expat (`doContent`, `doProlog` in `xmlparse.c`), with no `externalEntityRefHandler`, an external general entity in content goes only to the default handler. An external parameter entity sets `keepProcessing = standalone`, then the not-standalone check runs. Neither raises an error or calls the skipped-entity handler. XPact's native resolver returned nothing without a handler, and that became "external entity not resolved" (code 21). |

## 3. The change

- [x] `XP_PARSER`: a new mode, `ignores_unread_external_entities` / `set_ignores_unread_external_entities`. When an external entity may not be loaded:
  - **in content:** nothing is reported (no error, no skipped-entity callback);
  - **a parameter entity in the DTD or in an entity value:** later declarations are disabled unless the document is standalone, and the not-standalone check runs.
- [x] `XP_NATIVE_PARSER.configure_external_entity_policy`: with no external-entity handler, uses this mode and loads nothing. The policy is also refreshed before every parse, so it always matches the handler that is set.
- [x] An external `&name;` in content still goes to the default handler, as in Expat (seen in the trace).
- [ ] Not done: Expat also passes an unread `%name;` in the DTD to the default handler; XPact does not. It is separate and doesn't affect the result.

The existing `skip_unread_external_entities` mode is **unchanged**. It calls `on_skipped_entity`, and the Eiffel tests (`tests/xp_test_root.e`) and the benchmarks use it.

## 4. Verification

| Check | Result |
|---|---|
| ✅ Both tiers build | `System Recompiled.`, smoke `ok` |
| ✅ Expat comparison, whole document | 20 files fixed, 0 others changed (table above) |
| ✅ The same in 1-, 7- and 16-byte pieces | fix60 → fix64 changes exactly the same 20 files ([log](logs/pieces-check.txt)) |
| ✅ DLL tests, 4,308 cases | 4,308 / 4,308 on both tiers; `results.tsv` byte-identical to fix60 ([production](logs/dlltests-production-summary.txt), [assertions](logs/dlltests-assertions-summary.txt)) |
| ✅ W3C trace, 9 modes (events, default, suspend, abort; 1-byte, 7-byte, whole) | changes only in the same 20 files (13 in the abort modes); assertions tier byte-identical to production ([production](logs/w3c-trace-sha256-production.txt), [assertions](logs/w3c-trace-sha256-assertions.txt)) |
| ✅ The changed traces against Expat 2.8.1 | `trace.c` built with Expat compiled in ([build](logs/tools/build-trace-expat.ps1)). In every mode, each changed file now ends with Expat's status and error code, 0 of them before ([log](logs/trace-vs-expat-end-results.txt), [script](logs/tools/endcmp.py)). The event lists are still not byte-identical to Expat, like ~90% of all files; see section 5. |
| ✅ Test 2 (2,585 cases) | TSVs and summaries byte-identical to fix60, both tiers |
| ✅ Expat 2.8.1 `runtests` | `Checks: 399, Failed: 38` on both tiers, the same 38 names as fix60 ([production](logs/expat-runtests-production.txt), [assertions](logs/expat-runtests-assertions.txt)) |

## 5. Still open

The trace event lists differ from Expat in ways that were already there, in most files. Example, `xmltest/valid/sa/097.xml`:
- XPact's default handler gets whole declarations and normalized newlines (`\x0a`); Expat gets single tokens and the raw `\x0d\x0a`.
- DOCTYPE positions differ (`1:0:0` against `1:14:14`).
- Byte indexes with CRLF differ.

These belong to #171 and the default-handler work, not to this fix.

The 4 remaining verdict differences are separate problems:

| File | Expat | XPact |
|---|---|---|
| `eduni/misc/008.xml` | rejected, 19 | accepted |
| `eduni/xml-1.1/008.xml` | accepted | rejected, 30 |
| `ibm/not-wf/P69/ibm69n05.xml` | accepted | rejected, 11 |
| `xmltest/not-wf/not-sa/002.xml` | accepted | rejected, 2 |

## 6. How to revert

Revert the commit. Documents with external entities and no handler fail with code 21 again.
