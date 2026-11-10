# Report: issue #151: integrate the #146 / #148 fixes with `main` (#150)

Issue: [#151](https://github.com/andersoxie/xpact/issues/151)   Branch: `fix/151-integrate-146-148-with-main`   Base: `student-Mass`   Date: 2026-10-27
Status: ✅ PR #152 merged into `student-Mass` (2026-10-28) · ⬜ Jenkins not run · the issue stays open until Jenkins has run

> **Update 2026-10-28:** rerun on the final branch (with the #148 report and the dual regression lane, #153): the same results. All 2,585 W3C cases at 10 s: 0 failed, 0 errors, 0 skipped. See [latest-2026-10-28](../latest-2026-10-28/README.md).

> 📄 **Short version for the student and the supervisor:** [summary.md](summary.md), with answers to the supervisor's three questions.

This answers the supervisor's requests of 2026-10-27:

> 1. *Jobba vidare med dem som fallerar: kör lokalt, återskapa och rätta.* (Continue with the failing cases: run them locally, reproduce them and fix them.)
> 2. *Undersök om det finns fler som ska köras med den versionen (1.0) som vi supportar.* (Check whether more cases should be run with the version we support, 1.0.)
> 3. *Undersök vilken version av XML vi på lång sikt bör supporta, eller om man måste supporta flera parallellt.* (Find out which XML version we should support long term, or whether several must be supported in parallel.)

---

## 1. In short: before → after

| # | Run | Tree | Assertions off | Assertions on | Data |
|---|---|---|---|---|---|
| before 1 | W3C core profile | `student-Mass` @ `ec1705d` (no #146, no #150) | ✅ 1,727 / 1,727, 858 skipped | ✅ 1,727 / 1,727, 858 skipped | [summary](runs/before-1-student-mass-ec1705d/summary.md), [report](runs/before-1-student-mass-ec1705d/report.md) |
| before 2 | W3C core profile | `main` @ `1714f31` (#150) | ✅ 1,974 / 1,974, 611 skipped | ⚠️ **1,971** + 3 **timeouts**, 611 skipped | [summary](runs/before-2-main-1714f31/summary.md), [results](runs/before-2-main-1714f31/results.tsv) |
| before 3 | native DLL, 247 external-entity cases | `main` @ `1714f31` | ⚠️ **246** + 1 **crash** | ⚠️ **240** + 4 **crashes** + 3 **timeouts** (30 s) | [lane](runs/before-3-main-dll-entity-lane/) |
| **after 1** | W3C **all** 2,585 cases (`--all-cases`) | this branch | ✅ 2,283 checked + 302 no-crash-only, **0 failed, 0 errors, 0 skipped** | ✅ the same | [summary](runs/after-1-integrated-all-cases/summary.md), [results](runs/after-1-integrated-all-cases/results.tsv) |
| **after 2** | native DLL, 247 external-entity cases | this branch | ✅ **247 / 247** | ✅ **247 / 247** | [lane](runs/after-2-integrated-dll-entity-lane/) |
| **after 3** | Eiffel matrix + Python | this branch | ✅ matrix 4 / 4 · Python 192 OK | | [console](runs/after-3-regression-console.txt) |

**Conclusion:** #150 and #146 / #148 fix **different code paths**. #150 fixes the Eiffel resolver path. #146 fixes the native, Expat-compatible DLL path (child parsers). #148 fixes the speed of internal entity references. Where #146 duplicated #150, the **teacher's version was kept**.

---

## 2. Commits

| Commit | Change | Why |
|---|---|---|
| Merge `main` (#150) into #146 | resolves 7 + 4 + 7 + 1 conflicts (parser, harness, runner, docs) | see §3 |
| Fix slow internal entity references (#148, cherry-picked `ee51655`) | `note_position` keeps the reference position | `main` times out on the `pr-xml-*` cases (before 2, before 3) |
| Remove the #146 F4 entity-origin table now done in `main` | −48 lines | one implementation of WFC "Entity Declared" |
| Accept a 1.x text declaration in an external entity (drop #146 F6b) | −3 lines | erratum [E10](https://www.w3.org/XML/xml-V10-4e-errata#E10) reverses E38; `rmt-e2e-38` must be accepted |
| Map `main`'s standalone entity error to `XML_ERROR_ENTITY_DECLARED_IN_PE` | 1 line | keeps Expat error 24 in the DLL |
| Route in-profile entity cases to the core lane in the `--all-cases` test | test only | after #150, core entity cases run in the Eiffel harness with `--suite-root` |
| Add the #151 report | this folder | |

The final source files are byte-identical to the tested ones: `src/xp_parser.e` `7fc9ba6`, `src/xp_native_parser.e` `d77fe87`, `tests/python/test_w3c_conformance.py` `dbbdb4a`, `scripts/run_w3c_conformance.py` `549c228`, `benchmarks/xp_benchmark_root.e` `18c6dcb`, `docs/w3c-xml-conformance.md` `72f2d8e` (git blob hashes).

## 3. Which fix was kept, and why

| Fix | What | Needed on top of `main`? | Kept | Evidence |
|---|---|---|---|---|
| **F1** | recursion through an external entity in a child parser | ✅ **yes**: `main` DLL crashes with stack overflow `0xC00000FD` on `not-wf-ext-sa-001`, both builds | student's (push the entity before resolving; children inherit active entities) | before 3 → after 2 |
| **F2** | `%pe;` inside declarations in an external DTD | ❌ no: #150 has a more general expansion (`dtd_subset_with_parameter_reference`) | **teacher's** | after 1 core 1,974 / 1,974 |
| **F3** | count only the first top-level element in an external entity | ✅ **yes**: `main` assertions DLL crashes (`0xC0000028`) on `valid-ext-sa-005`, `valid-ext-sa-006`, `ext01` | student's | before 3 → after 2 |
| **F4** | standalone document using an externally declared entity | ❌ no: #150 has `general_entity_external_origin_table`, merged from child parsers too | **teacher's**, plus the error-24 mapping | after 1, after 2 |
| **F5** | text declaration without `encoding=` | ❌ already in `main` | `main` | |
| **F6a** | `<?xml` not at the start of an external entity | ❌ no: #150 has `a_allow_text_declaration` | **teacher's** | |
| **F6b** | reject `version="1.1"` in an external entity (E38) | ❌ **wrong for the 5th edition** | **removed** | `rmt-e2e-38` ACCEPT |
| **F7** | pass the parser's base to `ExternalEntityRefHandler` | ✅ yes, for Expat parity (not visible as a verdict) | student's | |
| **#148** | slow internal entity references | ✅ **yes**: timeouts on `main` (10 s Eiffel, 30 s DLL, assertions on) | student's | before 2 / 3 → after 1 / 2 |
| `--all-cases` lanes | run the 611 out-of-profile cases | ✅ yes: answers question 2 | student's, plus the teacher's catalog adjustments | after 1 |

### Merge decisions
- [x] `include_external_entity_in_content`: the teacher's structure (declaration base, element floor, asynchronous check), with F1's order (`push_entity` before resolving).
- [x] `include_external_entity_in_literal`: the teacher's (WFC: No External Entity References always applies).
- [x] DTD subset loop and the PE-in-declaration helpers: the teacher's. The student's F2 helpers were dropped.
- [x] Benchmark harness: both `--suite-root` (teacher) and `--legacy-names` (student).
- [x] Runner: the teacher's `catalog_expected` and `expectation_adjustment` plus the student's lanes. In-profile entity cases run in core with `--suite-root`; only **out-of-profile** entity cases go to the DLL checker.
- [x] Docs: the teacher's coverage sections first, then the student's `--all-cases` section.

---

## 4. Question 2: more cases to run as XML 1.0?

The teacher's profile excludes **611** cases (script: [tools/breakdown.py](tools/breakdown.py)):

| Group | Cases | What it is | Can it be run as XML 1.0 (5th edition)? | After 1 |
|---|---:|---|---|---|
| `EDITION="1 2 3 4"`, `not-wf` | 309 | IBM and xmltest **name-character** tests: names that were illegal before the 5th edition | They have a W3C verdict **for editions 1–4**. Under 5th-edition rules most become well-formed (#146 measured 302 ACCEPT, 7 REJECT). | ✅ **`legacy-names`** lane, 4th-edition name tables (as the DLL and Expat use): **309 / 309** checked |
| `x-rmt-008` | 1 | the 4th-edition variant of a version-number test (`error`) | no required verdict | no crash ✅ |
| XML 1.1 / Namespaces 1.1 | 273 | written for XML 1.1 processors | No 1.0 verdict exists. Per 1.0 5th edition §2.8, a 1.0 processor processes `1.x` as 1.0. | ✅ **`xml-1.1`** lane: no crash in 274 / 274 (137 ACCEPT, 137 REJECT) |
| `rmt-e2e-50` | 1 | NEL (`U+0085`) as a line end: a 1.1 feature | REJECT is correct for a 1.0 processor | REJECT ✅ |
| `TYPE="error"` | 27 | optional errors (EUC-JP, Shift_JIS, ISO-2022-JP; URI fragments in system IDs; …) | no binary verdict; the project could choose one per case | ✅ **`optional-error`** lane: no crash in 28 / 28 |

**Recommendation:**
- [ ] Keep the 1,974-case core profile as the **checked** XML 1.0 5th-edition verdicts.
- [ ] Count the **309 legacy-name cases as checked verdicts** for the 4th-edition rules the DLL uses (already done in the `legacy-names` lane).
- [ ] For the **27 optional errors**, decide per case what xpact *should* do and record it as a project expectation.
- [ ] Keep the **274 XML 1.1** cases as "no crash only". Optionally, derive 1.0 verdicts for 1.1 cases that use no 1.1 feature.

## 5. Question 3: which XML version long term?

| Version | Status | Support |
|---|---|---|
| **XML 1.0, 5th edition** (W3C Rec, [26 Nov 2008](https://www.w3.org/TR/2008/REC-xml-20081126/)) | the current XML 1.0 | Expat, libxml2, .NET, MSXML, Xerces, browsers |
| XML 1.0, editions 1–4 | replaced; the main difference is the **name-character tables** | Expat still uses the older tables |
| **XML 1.1, 2nd edition** (W3C Rec, 2006) | NEL line ends, C0 controls, its own name rules (now also in 1.0 5th ed.) | among the major parsers mainly Xerces (Java); not Expat, libxml2, .NET XmlReader, MSXML or browsers (sources below) |

**How "several versions" works:** it is **per document and per entity**, not two parsers running side by side. The `version` in the XML or text declaration selects the rules: line ends, allowed characters, names. XML 1.0 5th ed. §2.8 says an XML 1.0 processor should process `version="1.x"` **as 1.0**. It accepts documents without 1.1 features and rejects those that use them.

**xpact today:**
- the Eiffel parser: XML 1.0 **5th edition** (core lane)
- the native DLL: **4th-edition name tables** for Expat compatibility (`legacy-names` lane)
- `1.1` documents: processed as 1.0 (`rmt-e2e-38` ACCEPT, `rmt-e2e-50` REJECT)

**Recommendation:**
- [ ] **Target XML 1.0 5th edition** as the one supported version.
- [ ] Keep the **4th-edition name tables** only as a documented Expat-compatibility mode of the DLL.
- [ ] **Do not implement XML 1.1** unless a user needs NEL or C0 control characters. Keep processing `1.1` as 1.0 (§2.8).
- [ ] ⚠️ *Unverified:* the parser-support statements come from mostly older sources (2004–2010). Check current Expat and libxml2 release notes before quoting them as current.

Sources: [XML 1.0 5th ed.](https://www.w3.org/TR/2008/REC-xml-20081126/) · [4th-ed. errata E10](https://www.w3.org/XML/xml-V10-4e-errata#E10) · [xml-dev 2010: 1.1 support](https://lists.xml.org/archive/lists/xml-dev/months/201011/messages/127) · [libxml2 list 2010: "Unsupported version '1.1'"](https://lists.gnome.org/archives/xml/2010-July/msg00015.html) · [Firefox: XML 1.1 Won't Fix](https://bugs.launchpad.net/bugs/316373) · [Library of Congress: XML 1.1](https://loc.gov/preservation/digital/formats/fdd/fdd000264.shtml) · [xml-dev 2004: 1.1 Recommendation](https://xml.org/archive/lists/xml-dev/months/200402/messages/179)

---

## 6. Configuration

| Item | Value |
|---|---|
| Machine | student PC, Windows 11 Home 10.0.26200 |
| Eiffel | EiffelStudio 25.12.9.8922 win64, `ISE_C_COMPILER=msc_vc140`, finalized `-keep` |
| C | MSVC, Visual Studio 18 Community (`vcvars64.bat`) |
| Python | 3.15.0 (uv); `python` on `PATH` is only the Microsoft Store stub |
| W3C suite | `xmlts20130923.zip`, SHA-256 verified by the runner |
| Builds | Finalized (assertions discarded) and FinalizedAssertions (assertions on); `xpact.dll` and `xpact_assertions.dll` |
| `main` baseline | `origin/main` @ `1714f31` in a separate, detached worktree |
| This branch | `fix/146-option-a-w3c-all-cases` @ `d4a3299` + merge of `main` @ `1714f31` + #148 `ee51655` + 4 commits |

## 7. Commands and results

| # | Command (from the repository root) | Tree | Result |
|---|---|---|---|
| 1 | `.\scripts\run_benchmarks.ps1 -OutputDir build\w3c-run-20261027 -Iterations 100 -Repetitions 1 -SkipWslC -SkipNativeXpactC`, then `python scripts\run_w3c_conformance.py --known-failures benchmarks\w3c-known-failures.tsv --engine … --engine …` | `student-Mass` | before 1 |
| 2 | `.\scripts\run_benchmarks.ps1 -OutputDir build\w3c-main-20261027 -Iterations 100 -Repetitions 3 -SkipWslC -SkipNativeXpactC` | `main` | before 2 (exit 1: 3 unexpected timeouts) |
| 3 | `.\scripts\build_native_eiffel.ps1 -BuildTier Production` / `Assertions`; `cl /O2 /I include tests\native\xpact_w3c_case.c <lib>`; `python tools\dll_entity_lane.py <runner> <suite> <out> Finalized=<checker> FinalizedAssertions=<checker>` | `main` | before 3 |
| 4 | `.\scripts\run_benchmarks.ps1 -OutputDir build\w3c-integrate-20261027 -Iterations 100 -Repetitions 3 -SkipWslC -SkipNativeXpactC -W3cAllCases` | this branch | after 1 (exit 0) |
| 5 | as 3, with the DLLs and checkers built by 4 | this branch | after 2 |
| 6 | `.\scripts\run_eiffel_test_matrix.ps1`; `python -m unittest discover -s tests/python -p "test_*.py"` | this branch | after 3 |

All absolute paths must be given to `tools/dll_entity_lane.py` (see P4).

## 8. Problems met (kept separate)

### P1: logging with `*>` stops scripts at the first `ec` call (environment / my command)
1. **Problem:** `run_benchmarks.ps1` and `run_eiffel_test_matrix.ps1` stop right away when their output is redirected.
2. **Environment:** Windows PowerShell 5.1, student PC.
3. **Command:** `.\scripts\run_eiffel_test_matrix.ps1 *> log`
4. **Expected:** the compile runs, and the output goes to the log.
5. **Actual:** exit 1.
6. **Error output:** `ec.exe : Eiffel Compilation Manager ... NativeCommandError`
7. **Investigation:** the same scripts run normally without redirection.
8. **Cause:** *suspected*: PowerShell 5.1 turns redirected native stderr into error records, and the scripts use `$ErrorActionPreference = "Stop"`.
9. **Fix:** none. Workaround: don't redirect.
10. **Verification:** the runs without redirection completed.

### P2: `run_benchmarks.ps1 -Repetitions 1` crashes in `AddRange` (script bug)
1. **Problem:** with one repetition, the catalog benchmark step throws an error before the W3C step.
2. **Environment:** `student-Mass` @ `ec1705d`, student PC.
3. **Command:** `.\scripts\run_benchmarks.ps1 -Iterations 100 -Repetitions 1 -SkipWslC -SkipNativeXpactC`
4. **Expected:** the benchmarks run with one repetition, then the W3C lane.
5. **Actual:** `MethodArgumentConversionInvalidCastArgument`.
6. **Error output:** `Cannot convert argument "collection", with value: "@{Benchmark=catalog-100-items; ...}", for "AddRange" to type "System.Collections.Generic.IEnumerable`1[System.Object]"`
7. **Investigation:** the value is one `PSCustomObject`, not an array.
8. **Cause:** *suspected*: one result is not wrapped in an array.
9. **Fix:** none. Workaround: `-Repetitions 3` (runs 2 and 4 used it).
10. **Verification:** runs 2 and 4 got past this step. ⬜ It needs its own issue.

### P3: `vswhere.exe` not found by `vcvars64.bat` (environment)
As in #146: add `C:\Program Files (x86)\Microsoft Visual Studio\Installer` to `PATH`. Cause ✅ confirmed in #146.

### P4: the first DLL-lane run reported 177 false failures (my test script, not xpact)
1. **Problem:** 70 / 247 on the first run.
2. **Command:** `tools/dll_entity_lane.py` with a **relative** suite path.
3. **Cause:** ✅ confirmed: `run_case` starts the checker in a temporary working folder, so a relative `--entity-root` pointed nowhere. `valid-not-sa-001` by hand: ACCEPT.
4. **Fix:** absolute paths. **Verification:** 247 / 247.
5. `run_w3c_conformance.py` itself is not affected.

### P5: one Python test failed after the merge (test assumption, fixed)
`test_all_cases_runs_out_of_profile_cases_in_their_lanes` expected an in-profile entity case to go to the DLL checker. After #150 it runs in core. ✅ Confirmed. The test was updated (commit 6), giving 41 / 41 and then 192 / 192.

## 9. Limitations

- [ ] Jenkins has not run this branch.
- [ ] The `main` timeouts were seen on the **student PC**; the supervisor's machine may be faster. They are real slowness, not wrong verdicts.
- [ ] The in-profile DLL external-entity lane is not in `run_w3c_conformance.py` yet; it is checked only by [tools/dll_entity_lane.py](tools/dll_entity_lane.py). **Suggestion:** add it to the runner.
- [ ] Binary verdicts only; canonical output (`OUTPUT`) is not compared.
- [ ] The C# Expat comparison (#121) and the native ABI, CRC and shim checks were **not** rerun on this branch.
- [ ] `results.tsv` files contain absolute paths of the student PC.

## 10. Next steps

- [x] Review and merge the pull request into `student-Mass` (the student merges). *Done: PR #152.*
- [x] Run Jenkins on the result, then close #151. *Done: Jenkins passed (PR #177); #151 closed 2026-10-31.*
- [x] PR #147 (#146) and PR #149 (#148) are contained in this branch: close them after this one is merged, or merge them first (git will see the same changes). *Done: both closed 2026-10-28.*
- [ ] Open an issue for P2.
- [ ] Add the in-profile DLL entity lane to the runner.
