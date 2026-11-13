# Report: issue #175: an empty system literal was reported as NULL

> **Issue:** [#175](https://github.com/andersoxie/xpact/issues/175) G03-6 · found by G03 ([#169](https://github.com/andersoxie/xpact/issues/169))
> **Branch:** `fix/175-empty-system-literal`, from `student-Mass` @ `02a6575`
> **Changed:** `src/xp_parser.e` (2 lines + 2 comment lines)
> **Status:** ✅ cause confirmed · ✅ fixed · ✅ verified locally, both builds

## In short

An external ID always has a system literal: `SYSTEM 'x'` or `PUBLIC 'p' 'x'`, XML 1.0 [75]. When the literal was empty (`''`), xpact passed **NULL** to the application instead of `""`, so an external entity with an empty system ID looked like an internal entity. Expat passes `""`. The probe found the same mistake in the DOCTYPE start handler too. It is one cause, so it is one fix.

| Declaration | Before | After | Expat 2.8.1 |
|---|---|---|---|
| `<!ENTITY e SYSTEM ''>`, and the parameter, `PUBLIC 'p' ''` and `NDATA` forms | ❌ systemId NULL | ✅ `""` | `""` |
| `<!DOCTYPE d SYSTEM ''>` | ❌ systemId NULL | ✅ `""` | `""` |
| `<!NOTATION n SYSTEM ''>` | ✅ `""` | ✅ `""` | `""` |
| `SYSTEM 'x'` (control) | ✅ `'x'` | ✅ `'x'` | `'x'` |

## Problem report (CLAUDE.md format)

| Field | |
|---|---|
| **1. Problem** | an empty system literal reaches the application as NULL, not `""` |
| **2. Environment** | Windows 11 (student PC), `student-Mass` @ `02a6575`, EiffelStudio 25.12, Visual Studio 18 Community (MSVC), Python 3.14.0, .NET 10. Before: DLLs of `02a6575` (`xpact.dll` `6c593af8d4ce181c…`, `xpact_assertions.dll` `5488caa40859c94c…`), kept in `build\fix175\baseline`. After: `scripts\build_native_eiffel.ps1 -BuildTier Production` and `-BuildTier Assertions`, smoke ok ([build log](logs/build-after-fix.txt)). Reference: `libexpat.dll` Expat 2.8.1 (`36a2532e2181ab8b…`). |
| **3. Command** | `python -I reports\issue-0175\tools\probe.py <xpact dll> build\libexpat-R_2_8_1\build\libexpat.dll` |
| **4. Expected** | `systemId ""`, as Expat |
| **5. Actual (before)** | `systemId NULL` for entities and for the DOCTYPE ([probe before](logs/probe-before-assertions.txt): 2 / 7 the same as Expat) |
| **6. Error output** | none; the documents are accepted |
| **7. Investigation** | The native layer (`xp_native_callback_handler.e`, `on_entity_decl`) passes whatever string it gets; NULL comes from the parser. In `xp_parser.e`, the entity declaration passes the system ID through `optional_string`, which turns `""` into Void (line 5352). The DOCTYPE sets it only `if not l_system_id.is_empty` (line 2208). `NOTATION` passes it directly, so it was already right. |
| **8. Cause** | ✅ **confirmed**: both places treated "empty" as "absent", although a system literal is never absent after `SYSTEM` or `PUBLIC` |
| **9. Fix** | see "The change" |
| **10. Verification** | ✅ see below |

## The change

`src/xp_parser.e`:
- Entity declaration: `l_system_id` is passed as it is, instead of `optional_string (l_system_id)`. The public ID and the notation name still use `optional_string`, because they really can be absent (Expat passes NULL for those).
- DOCTYPE: the system ID is passed when the declaration has an external ID (`l_has_external_subset`, set exactly when `SYSTEM` or `PUBLIC` was read), not only when it is not empty.

## Verification

| Check | Before | After | Log |
|---|---|---|---|
| ✅ DLL builds and smoke test | ok × 2 | ok × 2 | [build](logs/build-after-fix.txt) |
| ✅ Probe, 7 declarations, = Expat | 2 / 7 | **7 / 7**, both builds | [assertions](logs/probe-after-assertions.txt), [normal](logs/probe-after-normal.txt) |
| ✅ G03, 93 cases × 14 ways | 59 match | **60 match**: `ibm-valid-P11-ibm11v02.xml` "events differ" → match; no other case changed status, both builds | [assertions](logs/g03-after-assertions.txt), [runs](logs/g03-after-assertions/) |
| ✅ W3C verdicts through the DLL, all 2,585 | baseline | **identical per case**, both builds | [verdicts](logs/verdicts/) |
| ✅ W3C output test, 432 cases | 399 / 432 | **399 / 432, identical per case** | [after](logs/output-after-assertions/summary.json) |
| ✅ C# DLL tests vs Expat 2.8.1, 4,308 cases | 3,423 identical | **3,423, no case changed** | [normal](logs/csharp-vs-expat-normal.txt), [assertions](logs/csharp-vs-expat-assertions.txt) |
| ✅ Expat's C tests (`runtests`) | 399 checks, 38 expected failures | **the same**, exit 0 | [log](logs/expat-runtests.txt) |
| ✅ Eiffel test matrix | 4 / 4 | **4 / 4** | [log](logs/eiffel-matrix.txt) |
| ✅ Python suite | 210 OK | **210 OK** | [log](logs/python-suite.txt) |
| ✅ Test 2, W3C in pieces, 2,585 documents | 2,561 stable | **2,561 stable, no document changed status**, both builds | [assertions](logs/chunked-fix175-assertions-summary.json), [normal](logs/chunked-fix175-normal-summary.json) |
| ✅ W3C benchmark stage, run locally (`run_benchmarks.ps1 -Iterations 1 -Repetitions 1 -SkipWslC -W3cAllCases`; rebuilds every program) | 2,283 + 302, 0 failed | **2,283 + 302, 0 failed, 0 errors**, both builds, exit 0 | [log](logs/w3c-benchmark-stage.txt) |
| ✅ Final DLLs (rebuilt by the benchmark stage, same source: `xpact.dll` `fe37de50f7d84611…`, `xpact_assertions.dll` `691131ca94a4e911…`) | | probe **identical** | |

## Limitations

- An empty **public** literal (`PUBLIC '' 'x'`) is not changed or checked here; the issue and the probe cover the system literal.
- Jenkins was not run (not needed, student decision 2026-10-31).

## Revert

`student\tools\fix.ps1 revert -Issue 175 -Commit <merged sha>`, or `git revert <sha>`.
