# 🔧 Fix for F01-1 and F01-2: attribute defaults across external files

> **Status:** ✅ fixed and verified locally · ✅ committed and in [PR #160](https://github.com/andersoxie/xpact/pull/160) (issues [#154](https://github.com/andersoxie/xpact/issues/154), [#155](https://github.com/andersoxie/xpact/issues/155)); repo copy: `reports/issue-0154/` · 🟡 PR not merged yet · branch `fix/f01-1-attribute-defaults-external` (local only, no upstream) in worktree `C:\Users\masou\Desktop\Lia\xpact\w10-attr-defaults`, based on `student-Mass` @ `293918f`
> Issue drafts: [F01-1](../issue-drafts/01-F01-1.md), [F01-2](../issue-drafts/02-F01-2.md) (not on GitHub yet)

[⬅ back to test 1](../README.md)

## In short

| | Before | After the fix |
|---|---:|---:|
| ✅ W3C output exactly right | 359 / 432 | **393 / 432** |
| 🔴 wrong, xpact only | 40 (+4 optional) | **6** (+4 optional) |
| cases that got **worse** | | **0** |

Fixed: all 30 F01-1 cases, the F01-2 case, and 3 of the 4 F01-3 cases (`ibm-invalid-P32-ibm32i03`, `not-sa02`, `not-sa03`: their declarations are in an external file too, so F01-3 was partly the same bug).
Still wrong (separate problems, not touched): `valid-sa-096` (F01-3, internal DTD), `notation01` (F01-4), `valid-ext-sa-014`, `invalid-bo-4`, `invalid-bo-5` (F01-5), `valid-not-sa-031` (F01-6).

## Problem report (CLAUDE.md format)

| Field | |
|---|---|
| **1. Problem** | Attribute declarations (`<!ATTLIST …>`) read from an external DTD, external parameter entity or used inside an external general entity are lost: defaults are not added, and "the first declaration wins" breaks |
| **2. Environment** | Windows 11, student PC; EiffelStudio 25.12, MSVC; Python 3.14; Expat control `pyexpat` 2.7.3; both DLL builds (`Production`, `Assertions`) |
| **3. Command** | `python run.py --dll <w10-attr-defaults>\build\native-eiffel-assertions\xpact_assertions.dll --out fix-F01-1/assertions` (the same with `build\native-eiffel\xpact.dll` → `fix-F01-1/normal`) |
| **4. Expected** | the W3C `OUTPUT` file, e.g. `valid-not-sa-003`: `<doc a1="v1"></doc>` |
| **5. Actual (before)** | `<doc></doc>` ([diffs](../logs-rerun-2026-10-28/normal/diffs/)) |
| **6. Error output** | none: the document is accepted with wrong content |
| **7. Investigation** | An external file is read by a child parser (`XML_ExternalEntityParserCreate`, `native/xpact_native.c`). The bridge passes state with `inherit_external_entity_context` (parent → child) and `merge_external_entity_context` (child → parent). In `src/xp_parser.e`, `import_entity_context`, `merge_entity_context_from` and the replay snapshot `entity_context_snapshot` copy the **entity** tables only, never `attribute_decl_table` |
| **8. Cause** | ✅ **confirmed**: adding the attribute table to those three routines makes the 34 cases pass and changes nothing else (below) |
| **9. Fix** | `src/xp_parser.e` only: new `attribute_decl_context_table`, `inherited_attribute_decl_table`, `cloned_attribute_decl_table`, `copy_attribute_decl_table_into` (keeps the first binding of each attribute); called from `import_entity_context`, `install_inherited_entity_context`, `merge_entity_context_from` and `entity_context_snapshot`. Declarations are immutable, so parent and child share them |
| **10. Verification** | see the table below |

## Verification (fix branch, both builds)

| Check | Before (`293918f`) | After the fix | Log |
|---|---|---|---|
| Test 1, W3C output (assertions first) | 359 / 432 | ✅ **393 / 432**, normal = assertions | [assertions](assertions/results.tsv), [normal](normal/results.tsv) |
| DLL build + smoke | ok | ✅ ok ×2 | [assertions](logs/build-assertions.txt), [normal](logs/build-normal.txt) |
| W3C verdicts through the DLL, all 2,585 | baseline | ✅ **identical** to baseline, both builds | [verdicts/](verdicts/) |
| External files through the DLL (`dll_entity_lane.py`) | 247 / 247 | ✅ **247 / 247**, both builds | [dll-entity-lane/](dll-entity-lane/) |
| Python suite | 206 OK | ✅ 206 OK | [python.txt](logs/python.txt) |
| C# DLL tests vs Expat 2.8.1 (4,308 inputs) | recorded table | ✅ difference table **identical**, both builds | [csharp/](csharp/) |
| Jenkins W3C stage, run locally (Eiffel, 2,585 × 2 builds, `-SkipWslC`) | 2,283 + 302, 0 failed | ✅ **2,283 + 302, 0 failed, 0 errors, 0 skipped**, both builds | [summary](jenkins-w3c/summary.md), [log](logs/jenkins-benchmarks-stage.txt) |
| Dual regression lane (xpact) | 910 / 910 | ✅ **910 / 910**, both builds; lifecycle ok | [summary](dual-regression/summary.md), [log](logs/dual-regression.txt) |
| Eiffel test matrix (workbench + finalized, assertions on and off) | 4 / 4 | ✅ **4 / 4** | [log](logs/eiffel-matrix.txt) |

**Result:** ✅ fixed and verified **locally**. Not yet: commit, GitHub issue, PR, Jenkins run.

The code change: [fix-F01-1.patch](fix-F01-1.patch) (`src/xp_parser.e` only).

### Problems met during verification (not caused by the fix, kept separate)

| Problem | Cause | What I did |
|---|---|---|
| Dual lane: `xpact-core` "BUILD FAILED: Pinned Xpact-core is not cached" | ✅ confirmed, environment: the new worktree has no `build/dependencies` cache, and the lane ran with `-Offline` | xpact lane only; Xpact-core is a separate parser this fix does not touch |
| `vswhere.exe` not found in my checker build script | environment: not on PATH | `cl` was already on PATH; both checkers built and load the new DLLs |
| `run_benchmarks.ps1` rewrites `docs/benchmarks.md` | by design (records timings) | restored with `git checkout`, not part of the fix |
| The new worktree had no W3C files | `build/validation-corpora` is not in git | copied from `w9-latest` (same suite, local only) |

## Limitations

- Not committed, no issue on GitHub yet, not run on Jenkins.
- Xpact-core lane of the dual regression not run (cache missing in the new worktree).
- The 2003 xmlconf comparison and the native C tests (runtime smoke, ABI, chunked CRC, shim audit) were not rerun separately; the DLL smoke ran in each build.
- Only the DLL path shows events; the Eiffel executable used by the W3C stage checks the verdict only.
