# Report: issue #157: normalize public identifiers

> **Issue:** [#157](https://github.com/andersoxie/xpact/issues/157) F01-4 · found by the W3C output test ([#154 report](../issue-0154/report.md))
> **Branch:** `fix/157-normalize-public-ids`, from `student-Mass` @ `d0a4e21` · **Changed:** `src/xp_parser.e` only (+6 lines)
> **Status:** ✅ fixed · ✅ verified locally, both builds · 🟡 waiting for a Jenkins run before the issue is closed

## 1. In short

| | Before (`d0a4e21`) | After |
|---|---:|---:|
| ✅ W3C output exactly right | 394 / 432 | **395 / 432** |
| 🔴 wrong, xpact only | 5 | **4** (#158, #159) |
| ❌ cases that got **worse** | | **0** |

The W3C case is a notation, but the problem was wider: **no** public identifier was normalized. All four places now match Expat:

| Where | Before (xpact) | After (xpact) | Expat |
|---|---|---|---|
| `<!DOCTYPE d PUBLIC "  -//A⏎   B//EN " …>` | `'  -//A\n   B//EN '` | ✅ `'-//A B//EN'` | `'-//A B//EN'` |
| `<!NOTATION n PUBLIC " a ⏎  b ">` | `' a \n  b '` | ✅ `'a b'` | `'a b'` |
| `<!ENTITY e PUBLIC "  x ⏎ y " "e.xml">` | `'  x \n y '` | ✅ `'x y'` | `'x y'` |
| `<!ENTITY u PUBLIC " p  q " "u.bin" NDATA n>` | `' p  q '` | ✅ `'p q'` | `'p q'` |

([probe](pubid_probe.py): [before](logs/checks/pubid-probe-before.txt), [after](logs/checks/pubid-probe-after.txt))

## 2. Problem report (CLAUDE.md format)

| Field | |
|---|---|
| **1. Problem** | Public identifiers (DOCTYPE, NOTATION, ENTITY, unparsed ENTITY) are reported and used as written, without normalizing white space |
| **2. Environment** | Windows 11 (student PC); EiffelStudio 25.12, MSVC (`msc_vc140`); Python 3.14; Expat control `pyexpat` 2.7.3; both DLL builds |
| **3. Command** | `python -I reports\issue-0154\tools\run.py --dll build\native-eiffel-assertions\xpact_assertions.dll --out <folder>`; `python -I reports\issue-0157\pubid_probe.py build\native-eiffel\xpact.dll` |
| **4. Expected** | `notation01`: `PUBLIC '+//ISBN 0-7923-9432-1::Graphic Notation//NOTATION CompuServe Graphic Interchange Format//EN'` |
| **5. Actual (before)** | the line break and the following spaces after `//NOTATION` were kept ([diff](../issue-0154/logs/after-normal/diffs/notation01.xpact.txt)) |
| **6. Error output** | none: accepted with wrong content |
| **7. Investigation** | Every public identifier is read by one routine, `read_public_id_literal` (`src/xp_parser.e`), which only checked the `PubidChar` set. XML 1.0 §4.2.2: before matching, a public identifier is normalized: white space strings become one space, leading and trailing white space removed. Expat does this in every place (checked with `pyexpat`, table above), also for the identifier passed to the external entity handler |
| **8. Cause** | ✅ **confirmed**: normalizing in `read_public_id_literal` fixes `notation01` and the probe, and changes nothing else (section 4) |
| **9. Fix** | after the `PubidChar` check: CR and LF become spaces (tab is not a `PubidChar`, so it is already rejected), then the existing `collapse_spaces` |
| **10. Verification** | ✅ section 4 |

## 3. The change

```eiffel
if not has_error then
		-- Line ends become spaces, then space runs collapse and the ends are trimmed (XML 1.0 section 4.2.2).
	a_value.replace_substring_all ("%R", " ")
	a_value.replace_substring_all ("%N", " ")
	collapse_spaces (a_value)
end
```

The normalized value is also what the resolver receives (`include_external_subset`, `resolved_external_replacement`), as in Expat.

## 4. Verification

Assertions build first, then the normal build. "Before" is `student-Mass` @ `d0a4e21` (after #156).

| Check | Before | After the fix | Log |
|---|---|---|---|
| ✅ DLL build + smoke test | ok ×2 | ok ×2 | [assertions](logs/checks/build-assertions.txt), [normal](logs/checks/build-normal.txt) |
| ✅ **W3C output test** | 394 / 432 | **395 / 432**; only change `notation01` → pass; normal = assertions | [assertions](logs/after-assertions/results.tsv), [normal](logs/after-normal/results.tsv) |
| ✅ Public-ID probe (4 places) | 0 / 4 like Expat | **4 / 4** like Expat | [before](logs/checks/pubid-probe-before.txt), [after](logs/checks/pubid-probe-after.txt) |
| ✅ W3C verdicts through the DLL, all 2,585 | baseline | **identical** per case, both builds | [summaries](logs/checks/verdicts/) |
| ✅ Jenkins Benchmarks stage, run locally (`-SkipWslC`) | 2,283 + 302, 0 failed | **2,283 + 302, 0 failed, 0 errors, 0 skipped**, both builds | [summary](logs/checks/jenkins-w3c/summary.md), [console](logs/checks/jenkins-benchmarks-stage.txt) |
| ✅ External entities through the DLL | 247 / 247 | **247 / 247**, both builds | [summary](logs/checks/dll-entity-lane/summary.json) |
| ✅ Python suite | 206 OK | **206 OK** | [log](logs/checks/python.txt) |
| ✅ C# DLL tests vs Expat 2.8.1 (4,308 inputs) | recorded table | difference table **identical**, both builds | [off](logs/checks/csharp/xpact/), [on](logs/checks/csharp/xpact_assertions/) |
| ✅ Dual regression lane (xpact, built from the changed source) | 910 / 910 | **910 / 910**, both builds | [summary](logs/checks/dual-regression/summary.md) |
| ✅ Eiffel test matrix | 4 / 4 | **4 / 4** | [log](logs/checks/eiffel-matrix.txt) |
| 🟡 Jenkins | | not run yet | |

## 5. Problems met (kept separate)

| Problem | Cause | What was done |
|---|---|---|
| My first Expat probe failed with "illegal character(s) in public id" | ✅ my test input: it had a tab, which is not a `PubidChar` | tab removed from the probe; Expat was right |
| The probe failed with `WinError 87` when run with a relative DLL path | ✅ my probe: `os.add_dll_directory` needs an absolute path (as #154 P2) | the probe resolves the path |
| Dual lane: `xpact-core` not built | ✅ environment, as #154 P1 | xpact lane only |

## 6. Limitations

- `PUBLIC ""` and `PUBLIC "   "` both give an empty identifier; for the DOCTYPE, xpact reports an empty one as no identifier (unchanged behaviour, not compared with Expat here).
- The Xpact-core half of the dual lane and the native C checks were not rerun; the DLL smoke test ran in each build.

## 7. Revert

After the squash merge: `.\student\tools\fix.ps1 revert -Issue 157 -Commit <merged sha>`.
