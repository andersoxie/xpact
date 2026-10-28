# Report: issue #154 (and #155): attribute defaults across external files

> **Issues:** [#154](https://github.com/andersoxie/xpact/issues/154) F01-1 · [#155](https://github.com/andersoxie/xpact/issues/155) F01-2 · found together with [#156](https://github.com/andersoxie/xpact/issues/156)–[#159](https://github.com/andersoxie/xpact/issues/159)
> **Branch:** `fix/154-attribute-defaults-external`, from `student-Mass` @ `293918f` · **Changed:** `src/xp_parser.e` only (+52 lines)
> **Status:** ✅ fixed · ✅ verified locally, both builds · 🟡 waiting for a Jenkins run before the issues are closed

## 1. In short

xpact accepted these documents (the right **verdict**) but reported the wrong **content**: default attribute values declared in a separate DTD file were lost.

| | Before | After |
|---|---:|---:|
| ✅ W3C output exactly right | 359 / 432 | **393 / 432** |
| 🔴 wrong, xpact only | 40 | **6** |
| 🟡 optional (either answer allowed) | 4 | 4 |
| ⚪ Expat differs too (XML 1.1 files) | 29 | 29 |
| ❌ cases that got **worse** | | **0** |

| Problem | Cases | Status |
|---|---:|---|
| F01-1 [#154](https://github.com/andersoxie/xpact/issues/154): defaults from an external DTD / parameter entity lost, "first declaration wins" broken | 30 | ✅ 30 / 30 fixed |
| F01-2 [#155](https://github.com/andersoxie/xpact/issues/155): defaults lost inside an external general entity | 1 | ✅ 1 / 1 fixed |
| F01-3 [#156](https://github.com/andersoxie/xpact/issues/156): tokenized attribute values not normalized | 4 | 🟡 3 / 4 fixed as a side effect (their declarations are in an external file); `valid-sa-096` left |
| F01-4 [#157](https://github.com/andersoxie/xpact/issues/157), F01-5 [#158](https://github.com/andersoxie/xpact/issues/158), F01-6 [#159](https://github.com/andersoxie/xpact/issues/159) | 5 | ⬜ not touched (separate problems) |

## 2. The test that found it

The W3C suite gives an expected **output file** (`OUTPUT`, James Clark canonical XML) for 432 of its 2,585 cases. The old W3C run checks only accept/reject. [`tools/run.py`](tools/run.py) parses each of those 432 documents through the DLL with the Expat C API, writes the events as canonical XML and compares byte for byte. Expat (`pyexpat`) runs the same way as a control: if only xpact differs, the problem is in xpact.

```
W3C suite (xmlconf), 2,585 cases
├── old test: accept / reject? ───────► ✅ all right (unchanged by this fix)
└── test 1: content right? (432 with an answer file)
      ├── 393 ✅ right                     (was 359)
      ├──  29 ⚪ XML 1.1 files, Expat differs too
      ├──   4 🟡 optional errors
      └──   6 🔴 wrong: #156 (1), #157, #158, #159   (was 40)
```

## 3. Problem report (CLAUDE.md format)

| Field | |
|---|---|
| **1. Problem** | `<!ATTLIST>` declarations in an external DTD or external parameter entity do not reach the main document; elements inside an external general entity do not see the document's declarations |
| **2. Environment** | Windows 11 (student PC); EiffelStudio 25.12, MSVC (`msc_vc140`); Python 3.14; Expat control `pyexpat` 2.7.3; both DLL builds (`Production`, `Assertions`) |
| **3. Command** | `python -I reports\issue-0154\tools\run.py --dll build\native-eiffel-assertions\xpact_assertions.dll --out <folder>` from the repository root (and with `build\native-eiffel\xpact.dll`) |
| **4. Expected** | the `OUTPUT` file, e.g. `valid-not-sa-003`: `<doc a1="v1"></doc>`; `valid-sa-097`: `<doc a1="v1"></doc>` (the external `a2 #IMPLIED` comes first and wins) |
| **5. Actual (before)** | `valid-not-sa-003`: `<doc></doc>`; `valid-sa-097`: `<doc a1="v1" a2="v2"></doc>`; `valid-ext-sa-013`: `<e>` with no attributes ([all diffs](logs/before/diffs/)) |
| **6. Error output** | none: the document is accepted with wrong content ([per case](logs/before/results.tsv)) |
| **7. Investigation** | Small repros: [`mini/ext-dtd.xml`](mini/ext-dtd.xml) + [`mini/ext.dtd`](mini/ext.dtd) (F01-1), [`mini/ext-ent.xml`](mini/ext-ent.xml) + [`mini/e.ent`](mini/e.ent) (F01-2). An external file is read by a child parser (`XML_ExternalEntityParserCreate`, `native/xpact_native.c`). The bridge passes state with `inherit_external_entity_context` (parent → child) and, after a parameter entity, `merge_external_entity_context` (child → parent). In `src/xp_parser.e`, `import_entity_context`, `merge_entity_context_from` and the replay snapshot `entity_context_snapshot` (used when the parent re-parses the buffer, see F05-1) copy only the **entity** tables, never `attribute_decl_table` |
| **8. Cause** | ✅ **confirmed**: adding the attribute table to exactly those routines makes the 34 cases pass and changes nothing else (section 5) |
| **9. Fix** | see section 4 |
| **10. Verification** | ✅ see section 5 |

## 4. The change

`src/xp_parser.e`, following the existing entity-table code:

| Where | What |
|---|---|
| `attribute_decl_context_table` (new, `{XP_PARSER}`) | gives the child or parent access to `attribute_decl_table` |
| `inherited_attribute_decl_table` (new) | the parent's declarations, kept for the child like `inherited_entity_table` |
| `import_entity_context` | parent → child: also clones the attribute declarations (**F01-2**) |
| `install_inherited_entity_context` | puts them back after the reset at parse start |
| `merge_entity_context_from` | child → parent: also merges the attribute declarations (**F01-1**) |
| `entity_context_snapshot` | the replay snapshot also keeps them |
| `copy_attribute_decl_table_into`, `cloned_attribute_decl_table` (new) | copy per element, **keeping the first binding** of each attribute (XML 1.0 §3.3) |

`XP_ATTRIBUTE_DECL` objects are never changed after creation, so parent and child share them; only the lists are copied.

## 5. Verification

Assertions build first, as `CLAUDE.md` asks; then the normal build.

| Check | Before (`293918f`) | After the fix | Log |
|---|---|---|---|
| ✅ DLL build + smoke test | ok ×2 | ok ×2 | [assertions](logs/checks/build-assertions.txt), [normal](logs/checks/build-normal.txt) |
| ✅ **Test 1, W3C output** | 359 / 432 | **393 / 432**, 0 worse, normal = assertions | [assertions](logs/after-assertions/results.tsv), [normal](logs/after-normal/results.tsv), [diffs left](logs/after-normal/diffs/) |
| ✅ W3C verdicts through the DLL, all 2,585 | baseline | **identical** per case, both builds | [summaries](logs/checks/verdicts/) |
| ✅ Jenkins Benchmarks stage, run locally (`-SkipWslC`) | 2,283 + 302, 0 failed | **2,283 + 302, 0 failed, 0 errors, 0 skipped**, both builds | [summary](logs/checks/jenkins-w3c/summary.md), [console](logs/checks/jenkins-benchmarks-stage.txt) |
| ✅ External entities through the DLL (`dll_entity_lane.py`) | 247 / 247 | **247 / 247**, both builds | [summary](logs/checks/dll-entity-lane/summary.json) |
| ✅ Python suite | 206 OK | **206 OK** | [log](logs/checks/python.txt) |
| ✅ C# DLL tests vs Expat 2.8.1 (4,308 inputs) | recorded table | difference table **identical**, both builds | [off](logs/checks/csharp/xpact/), [on](logs/checks/csharp/xpact_assertions/) |
| ✅ Dual regression lane (xpact) | 910 / 910 | **910 / 910**, both builds, lifecycle ok | [summary](logs/checks/dual-regression/summary.md) |
| ✅ Eiffel test matrix (workbench + finalized, assertions on/off) | 4 / 4 | **4 / 4** | [log](logs/checks/eiffel-matrix.txt) |
| 🟡 Jenkins | | waiting for the supervisor | |

Repeat: build with `scripts\build_native_eiffel.ps1 -BuildTier Assertions -OutputDir build\native-eiffel-assertions` (and `-BuildTier Production`), then the command in section 3. The tool finds the repository and the W3C files under `build\validation-corpora` from its own location (`XPACT_REPO` overrides).

## 6. Problems met (kept separate, none caused by the fix)

| # | Problem | Source | Cause | What was done |
|---|---|---|---|---|
| P1 | Dual lane: `xpact-core` "BUILD FAILED: Pinned Xpact-core is not cached" | environment | ✅ confirmed: new worktree without `build/dependencies`, lane run with `-Offline` | xpact lane only; Xpact-core is a separate parser, not touched by this change |
| P2 | The test tool reported **every** xpact case as `CRASH 0x00000001` | my test tool | ✅ confirmed: a relative `--dll` path; `os.add_dll_directory` accepts absolute paths only (`WinError 87`) | `tools/harness/pool.py` resolves the path; rerun matches the recorded result case by case |
| P3 | `vswhere.exe` not found when building the DLL-lane checker | environment | not on `PATH` (as #151 P3) | `cl` was already on `PATH`; both checkers built against the new DLLs |
| P4 | `run_benchmarks.ps1` rewrites `docs/benchmarks.md` | by design | records its timings | restored, not committed |

## 7. Limitations

- Only the DLL path shows events; the Eiffel executable used by the W3C stage checks the verdict only.
- The Xpact-core half of the dual lane and the native C checks (runtime smoke, ABI, chunked CRC, shim audit) were not rerun; the DLL smoke test ran in each build.
- No Jenkins run yet.

## 8. Revert

After the squash merge: `.\student\tools\fix.ps1 revert -Issue 154 -Commit <merged sha>`.

## 9. Next

- [ ] Jenkins run on `student-Mass`, then close #154 and #155
- [ ] #156: normalize the declared default value of tokenized types (`valid-sa-096`)
- [ ] #157, #158, #159, one at a time
- [ ] Add test 1 as a lane next to the W3C verdict run
