# Report: issue #156: normalize the declared default of tokenized attributes

> **Issue:** [#156](https://github.com/andersoxie/xpact/issues/156) F01-3 · found by the W3C output test ([#154 report](../issue-0154/report.md))
> **Branch:** `fix/156-normalize-tokenized-defaults`, from `student-Mass` @ `7028e68` · **Changed:** `src/xp_parser.e` only (+4 lines)
> **Status:** ✅ fixed · ✅ verified locally, both builds · 🟡 waiting for a Jenkins run before the issue is closed

## 1. In short

| | Before (`7028e68`) | After |
|---|---:|---:|
| ✅ W3C output exactly right | 393 / 432 | **394 / 432** |
| 🔴 wrong, xpact only | 6 | **5** (#157, #158, #159) |
| ❌ cases that got **worse** | | **0** |

| F01-3 case | Declarations | Status |
|---|---|---|
| `ibm-invalid-P32-ibm32i03`, `not-sa02`, `not-sa03` | external file | ✅ fixed earlier by #154 (PR #160) |
| `valid-sa-096` | internal DTD, **declared default** | ✅ **fixed here** |

**#156 is now 4 / 4.**

## 2. Problem report (CLAUDE.md format)

| Field | |
|---|---|
| **1. Problem** | The default value declared for a tokenized attribute (`NMTOKENS`, `ID`, `IDREFS`, `ENTITIES`, enumerations …) is used without space normalization |
| **2. Environment** | Windows 11 (student PC); EiffelStudio 25.12, MSVC (`msc_vc140`); Python 3.14; Expat control `pyexpat` 2.7.3; both DLL builds |
| **3. Command** | `python -I reports\issue-0154\tools\run.py --dll build\native-eiffel-assertions\xpact_assertions.dll --out <folder>` (and with `build\native-eiffel\xpact.dll`) |
| **4. Expected** | `valid-sa-096`: `<!ATTLIST doc a1 NMTOKENS " 1  \t2 \t">` + `<doc></doc>` → `<doc a1="1 2"></doc>` |
| **5. Actual (before)** | `<doc a1=" 1   2  "></doc>`: tabs became spaces (literal normalization), but the spaces were not collapsed |
| **6. Error output** | none: accepted with wrong content ([before](../issue-0154/logs/after-normal/diffs/valid-sa-096.xpact.txt)) |
| **7. Investigation** | `apply_default_attributes` (`src/xp_parser.e`) calls `collapse_spaces` only on a value the element **specifies**; a default is added afterwards with `put_default`, exactly as declared. XML 1.0 §3.3.3: after literal normalization, a non-CDATA value is trimmed and its runs of spaces collapsed; §3.3.2: a default value must match the declared type. Expat normalizes the default when it stores the declaration, so its `attlistdecl` event already carries the normalized default. Checked with `pyexpat` 2.7.3: `<!ATTLIST doc a1 NMTOKENS " 1  \t2 \t" a2 CDATA " x  y ">` gives the event `('doc', 'a1', 'NMTOKENS', '1 2', 0)` and keeps the CDATA default `' x  y '` as it is |
| **8. Cause** | ✅ **confirmed**: normalizing the default where it is parsed makes `valid-sa-096` pass and changes nothing else (section 4) |
| **9. Fix** | In the `<!ATTLIST>` parser, right after the default value is read: if the type is not `CDATA`, `collapse_spaces (l_value)`, before `record_attribute_decl` and the `attlistdecl` callback. So the stored default and the event both carry the normalized value, as in Expat |
| **10. Verification** | ✅ section 4 |

## 3. The change

```eiffel
if not has_error and then attached l_default_value as l_value and then not l_attribute_type.same_string ("CDATA") then
		-- A declared default is normalized like a specified value of its type (XML 1.0 section 3.3.3).
	collapse_spaces (l_value)
end
```

## 4. Verification

Assertions build first, then the normal build. "Before" is `student-Mass` @ `7028e68` (after #154).

| Check | Before | After the fix | Log |
|---|---|---|---|
| ✅ DLL build + smoke test | ok ×2 | ok ×2 | [assertions](logs/checks/build-assertions.txt), [normal](logs/checks/build-normal.txt) |
| ✅ **W3C output test** | 393 / 432 | **394 / 432**; only change `valid-sa-096` → pass; normal = assertions | [assertions](logs/after-assertions/results.tsv), [normal](logs/after-normal/results.tsv) |
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
| Dual lane: `xpact-core` not built | ✅ environment: no cached Xpact-core in this worktree, `-Offline` (as #154 P1) | xpact lane only; Xpact-core is not touched |
| `run_benchmarks.ps1` rewrites `docs/benchmarks.md` | by design | restored, not committed |

## 6. Limitations

- The C# tests compare verdicts and selected properties with Expat; the `attlistdecl` default value is not compared event by event there.
- The Xpact-core half of the dual lane and the native C checks were not rerun; the DLL smoke test ran in each build.

## 7. Revert

After the squash merge: `.\student\tools\fix.ps1 revert -Issue 156 -Commit <merged sha>`.
