# Report: mass-xpact #69: the #64 fix broke 3 Eiffel tests

> **Issue:** [CodTanium/mass-xpact#69](https://github.com/CodTanium/mass-xpact/issues/69), found by the acceptance run [#67](https://github.com/CodTanium/mass-xpact/issues/67) · **Branch:** `fix/69-no-handler-loading`, from `student-Mass` @ `513f976`
> **Changed:** `src/xp_parser.e`, `src/xp_native_parser.e`, `tests/xp_test_root.e`
> **Status:** ✅ fixed · ✅ verified

## 1. In short

The #64 fix was verified with the DLL, W3C, Test 2 and Expat checks, but **not with the Eiffel test matrix**. The matrix finds 3 failing assertions ([before](logs/matrix-before.txt)):

| Assertion | Cause | Fix |
|---|---|---|
| `native Eiffel parser broadens external entity policy` | #64 set the policy to "no external entities" whenever there is no handler | The policy keeps its configured value; "no handler" now stops loading through `parameter_entity_loading_allowed` and the general-entity check |
| `native Eiffel parser reports skipped entity`, `… names skipped entity` | The test expects a skipped-entity callback for an unloaded external `&en;` without a handler. **Expat 2.8.1 makes no such callback** | The test now expects what Expat does: no skipped callback |

Now **4/4 matrix lanes pass** ([after](logs/matrix-after.txt)), and every #64 result is unchanged.

## 2. Expat is the reference for the changed test

`skipped.c` ([source](logs/tools/skipped.c)) parses 3 documents with a skipped-entity handler and no external-entity handler, with parameter-entity parsing off and on. It was built once with Expat 2.8.1 and once against `xpact.dll` ([output](logs/skipped-entity-expat-baseline-after.txt)):

| Document | Expat 2.8.1 | `253c81e` | After |
|---|---|---|---|
| `&en;`, external, PE parsing off | accepted, no callback | accepted, **`skipped:en:0`** | ✅ as Expat |
| `&en;`, external, PE parsing on | accepted, no callback | accepted, **`skipped:en:0`** | ✅ as Expat |
| `%pe;` external, then `&e;`, PE parsing off | accepted, `skipped:e:0` | **code 21** | ✅ as Expat |
| `%pe;` external, then `&e;`, PE parsing on | accepted, `skipped:e:0` | **`skipped:pe:1`**, `skipped:e:0` | ✅ as Expat |
| `%pe;` external, then `&undeclared;`, PE parsing off | accepted, `skipped:undeclared:0` | **code 21** | ✅ as Expat |
| `%pe;` external, then `&undeclared;`, PE parsing on | accepted, `skipped:undeclared:0` | **`skipped:pe:1`**, `skipped:undeclared:0` | ✅ as Expat |

## 3. Verification

| Check | Result |
|---|---|
| ✅ Both tiers build | `System Recompiled.`, smoke `ok` |
| ✅ Eiffel test matrix | 4/4 lanes `ok` (was 1 lane `FAILED`) |
| ✅ DLL tests, 4,308 cases | 4,308 pass; `results.tsv` byte-identical to fix64, both tiers ([production](logs/dlltests-production-summary.txt), [assertions](logs/dlltests-assertions-summary.txt)) |
| ✅ No-handler W3C, 3,061 files, whole and 1/7/16-byte pieces | byte-identical to fix64 (the #64 result is kept) |
| ✅ W3C trace, 9 modes | byte-identical to fix64, both tiers ([production](logs/w3c-trace-sha256-production.txt), [assertions](logs/w3c-trace-sha256-assertions.txt)) |
| ✅ Test 2, 2,585 cases | byte-identical to fix64, both tiers |
| ✅ Expat 2.8.1 `runtests` | `Checks: 399, Failed: 38`, the same 38 names, both tiers ([production](logs/expat-runtests-production.txt), [assertions](logs/expat-runtests-assertions.txt)) |
| ✅ Skipped-entity callbacks | 6/6 as Expat (section 2) |

## 4. Lesson

The verification recipe for a parser change now includes the Eiffel test matrix (`scripts/run_eiffel_test_matrix.ps1`).

## 5. How to revert

Revert the commit; the policy is forced to "none" without a handler again and the 3 assertions fail.
