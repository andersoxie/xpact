# Report: issue #159: an external parameter entity included in an entity literal

> **Issue:** [#159](https://github.com/andersoxie/xpact/issues/159) F01-6 · found by the W3C output test ([#154 report](../issue-0154/report.md))
> **Branch:** `fix/159-external-parameter-entity-in-literal`, from `student-Mass` @ `82c82b5` · **Changed:** `src/xp_parser.e`, `src/xp_native_parser.e`, `src/xp_native_callback_handler.e`, new `src/xp_literal_check_handler.e`
> **Status:** ✅ fixed · ✅ verified locally, both builds, including Expat's own C tests · 🟡 waiting for a Jenkins run before the issue is closed

## 1. In short

| | Before (`82c82b5`) | After |
|---|---:|---:|
| ✅ W3C output exactly right | 398 / 432 | **399 / 432** |
| 🔴 wrong, xpact only | 1 (+4 optional) | **0** (+4 optional) |
| ❌ cases that got **worse** | | **0** |
| ✅ Expat's C tests (`runtests`) | 38 fails, all allocator | **the same 38** |

**All problems found by the W3C output test are now fixed** (#154–#159). What is left in that test: 29 XML 1.1 files (Expat differs too) and 4 optional errors.

`<!ENTITY e "<![CDATA[%e;]]>">` with `%e;` an external file holding `<!ATTLIST doc a1 CDATA "v1">`:

| | Entity value of `e` | Extra event |
|---|---|---|
| Expat | `<![CDATA[<!ATTLIST doc a1 CDATA "v1">⏎]]>` | none |
| xpact before | `<![CDATA[]]>` (empty) | ❌ `attlistdecl doc a1` |
| **xpact after** | ✅ `<![CDATA[<!ATTLIST doc a1 CDATA "v1">⏎]]>` | ✅ none |

([events](logs/checks/case-031-events-after.txt))

## 2. Problem report (CLAUDE.md format)

| Field | |
|---|---|
| **1. Problem** | Through the DLL, an external parameter entity referenced inside an entity value was parsed as declarations (they were reported and kept), and its text never reached the value, which stayed empty |
| **2. Environment** | Windows 11 (student PC); EiffelStudio 25.12, MSVC (`msc_vc140`); Python 3.14; Expat control `pyexpat` 2.7.3; Expat 2.8.1 source for `runtests`; both DLL builds |
| **3. Command** | `python -I reports\issue-0154\tools\run.py --dll build\native-eiffel-assertions\xpact_assertions.dll --out <folder>`; `python -I reports\issue-0159\literal_probe.py <dll>`; Expat's `runtests`: `AlotOfTests\06-expat-runtests-parity\run-native-suite.ps1 -Repo <worktree>` (local tool, as the Jenkins libexpat stage) |
| **4. Expected** | `valid-not-sa-031`: `<doc>&lt;!ATTLIST doc a1 CDATA &quot;v1&quot;&gt;&#10;</doc>` (XML 1.0 §4.4.5, "included in literal") |
| **5. Actual (before)** | `<doc></doc>` plus an extra `attlistdecl` event ([diff](../issue-0154/logs/after-normal/diffs/valid-not-sa-031.xpact.txt)) |
| **6. Error output** | none: accepted with wrong content |
| **7. Investigation** | The parent asks the application for the file (`resolve_external_entity`, `src/xp_native_callback_handler.e`), the application parses it with a child parser in "parameter literal" mode (`parse_external_parameter_literal_with_context`, `src/xp_parser.e`). That mode ran the old DTD/content parsing, so declarations were reported and merged back, and the callback returned `""` for any child parse: the text had no way back. The commit that introduced the mode (`aa2b083`) says it did not close this gap. **Expat** (checked): the text is checked like DTD text (bad tokens, a start tag, a cut-off character, a malformed text declaration all fail), the text declaration still reaches the `XmlDeclHandler`, references to parameter entities inside are expanded, and the whole text goes into the value; nothing is declared |
| **8. Cause** | ✅ **confirmed**: with the changes below `valid-not-sa-031` matches Expat event for event, and no other check changes |
| **9. Fix** | section 3 |
| **10. Verification** | ✅ section 4 |

## 3. The change

| File | Change |
|---|---|
| `src/xp_parser.e` | new `last_parameter_literal_text`. In literal mode: the text after the text declaration is kept. If it has no `%`, it is first **checked** with the old DTD/content pass, but with an `XP_LITERAL_CHECK_HANDLER`, so its declarations and content are not reported. If it has `%` references, they are expanded with the existing `append_parameter_reference_in_entity_value` (recursion is caught there), and each external one is read only once |
| `src/xp_literal_check_handler.e` (new) | silent like `XP_NULL_EVENT_HANDLER`, but forwards the text declaration and the application's stop request (Expat's `test_ext_entity_value_abort` aborts from that callback) |
| `src/xp_native_parser.e` | `merge_external_entity_context_from`: a literal child gives back its text; its declarations are **not** merged |
| `src/xp_native_callback_handler.e` | new `external_entity_replay_texts` (per callback, like the replay counts): the callback returns the child's text instead of `""`, also on the re-parse replay; cleared with the other replay tables |

## 4. Verification

Assertions build first, then the normal build, on `82c82b5` + #159.

| Check | Before | After the fix | Log |
|---|---|---|---|
| ✅ DLL build + smoke test (incl. the 11 entity-value cases and `test_invalid_tag_in_dtd`) | ok ×2 | ok ×2 | [assertions](logs/checks/build-assertions.txt), [normal](logs/checks/build-normal.txt) |
| ✅ **W3C output test** | 398 / 432 | **399 / 432**; only `valid-not-sa-031` changed; normal = assertions | [assertions](logs/after-assertions/results.tsv), [normal](logs/after-normal/results.tsv) |
| ✅ Literal probe: the smoke test's 11 cases, child error codes | 11 / 11 | **11 / 11**, and the value now holds the text | [before](logs/checks/literal-probe-before.txt), [after](logs/checks/literal-probe-after-assertions.txt) |
| ✅ **Expat's C tests (`runtests`, 399 checks)** | 38 fails (all allocator) | **the same 38** | [before](logs/checks/runtests-before-fails.txt), [after](logs/checks/runtests-after-fails.txt) |
| ✅ W3C verdicts through the DLL, all 2,585 | baseline | **identical** per case, both builds | [summaries](logs/checks/verdicts/) |
| ✅ Jenkins Benchmarks stage, run locally (`-SkipWslC`) | 2,283 + 302, 0 failed | **2,283 + 302, 0 failed, 0 errors, 0 skipped**, both builds | [summary](logs/checks/jenkins-w3c/summary.md), [console](logs/checks/jenkins-benchmarks-stage.txt) |
| ✅ External entities through the DLL | 247 / 247 | **247 / 247**, both builds | [summary](logs/checks/dll-entity-lane/summary.json) |
| ✅ Python suite | 206 OK | **206 OK** | [log](logs/checks/python.txt) |
| ✅ C# DLL tests vs Expat 2.8.1 (4,308 inputs) | recorded table | difference table **identical**, both builds | [off](logs/checks/csharp/xpact/), [on](logs/checks/csharp/xpact_assertions/) |
| ✅ Dual regression lane (xpact, built from the changed source) | 910 / 910 | **910 / 910**, both builds | [summary](logs/checks/dual-regression/summary.md) |
| ✅ Eiffel test matrix | 4 / 4 | **4 / 4** | [log](logs/checks/eiffel-matrix.txt) |
| 🟡 Jenkins | | not run yet | |

## 5. Problems met on the way (kept separate)

| # | Problem | Source | Cause | What was done |
|---|---|---|---|---|
| P1 | First version: smoke test `invalid tag in DTD callback path matched` | my change | ✅ confirmed: the text was no longer checked, Expat reports a syntax error for `<el/>` | the check pass was brought back, silently |
| P2 | Second version: 4 of the 11 smoke entity-value cases lost their error code | my change | ✅ confirmed: Expat checks bad tokens, cut-off characters and text declarations too | the old pass is used as the check, not my own scanner |
| P3 | Third version: `valid-not-sa-003` crashed the assertions build (`0xC00000FF`, no trace); 234 more cases failed after it in the same worker | my change | ✅ confirmed: `starts_xml_declaration_at` requires a non-empty input; `003-2.ent` is empty | guarded with `not l_input.is_empty`; the probe with an empty text passes |
| P4 | Fourth version: Expat `runtests` 39 fails, new `test_ext_entity_value_abort` | my change | ✅ confirmed: the silent handler also swallowed the text declaration, whose callback aborts | `XP_LITERAL_CHECK_HANDLER` forwards it and the stop request |
| P5 | Test harness: after one crash, every later case in the same worker fails as "access violation" | test tool | ✅ the worker process stays alive after an in-process crash | noted; read the first failing case, not the count |
| P6 | Dual lane: `xpact-core` not built | environment, as #154 P1 | ✅ | xpact lane only |

## 6. Limitations

- When the included text contains `%`, it is expanded but not run through the DTD check pass, and its text declaration is not reported (to avoid reading external entities twice).
- Character references inside the included text are kept as written, not expanded.
- Expat's `runtests` were run with the normal build only (as the Jenkins libexpat stage does).

## 7. Revert

After the squash merge: `.\student\tools\fix.ps1 revert -Issue 159 -Commit <merged sha>`.
