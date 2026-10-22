# Assertions-enabled baseline — 2026-10-14

Week 2 of the student plan: *follow parser events and run the
assertions-enabled tests; record revision, configuration, commands and known
failures.* Every number below comes from the logs in [`logs/`](logs/).
To reproduce the whole thing, run `.\run_baseline.ps1` (see [README.md](README.md)).

## 1. Revision

> Moved here from `Desktop\xpact-student-test\Assertion enabled tests` on 2026-10-15. The numbers
> below are from that original run. Section 7 of [PLAN2.md](../PLAN2.md) adds the xmlconf crash finding.

This checkout (`Desktop\xpact-student-test`) is **not a git working tree**, so
the sources are identified by content:

| | |
|---|---|
| Source fingerprint | `e2c5eafe68445b8ba3c79feaa921b2af72fef4ec9a5d9ca6e2497a0067fbd981` (SHA-256 over 119 `*.e/*.ecf/*.c/*.h/*.ps1` files; per-file hashes in [`logs/sources.sha256`](logs/sources.sha256)) |
| Closest pushed commit | `student-test` @ `b930600` on github.com/andersoxie/xpact. *Update 2026-10-20:* that branch has been deleted; its build fixes are now on `student-Mass` as #2 (`9eb18bd`), #7 (`eb6fc5d`) and #10 (`20e6bc3`), see [`reports/README.md`](../../reports/README.md). Rerunning this baseline in the git clone is task A02. |
| Local changes on top of it | `scripts/run_xmlconf_conformance.ps1` (downloads the pinned W3C ZIP; `ec` stderr guard; runs `finish_freezing`), `scripts/run_eiffel_test_matrix.ps1` (stderr guard so the lanes can be logged), and this folder |

## 2. Configuration

From [`logs/environment.log`](logs/environment.log):

| | |
|---|---|
| OS | Windows 11 Home 10.0.26300, 64-bit |
| EiffelStudio | 25.12.9.8922 win64 (`ec`), C backend default **mingw** (`ISE_C_COMPILER` empty) |
| Visual Studio | Community 2026 18.10, MSVC toolset 14.51.36231 |
| PowerShell / Python | 5.1.26100 / 3.10.6 |
| Precompiled Base | `base-safe` (mingw only) |

Assertion settings of every target used (pre / post / check / invariant):

| ECF target | Assertions |
|---|---|
| `tests\xpact_tests.ecf` → `xpact_tests_assertions` | **all on** |
| `tests\xpact_native_runtime.ecf` → `xpact_native_runtime` | **all on** |
| `tests\xpact_native_library.ecf` → `xpact_native_library_assertions` | **all on** (finalized with `-keep`) |
| `xpact.ecf` → `xpact` (CLI used by xmlconf) | **all on** (workbench) |
| `event-trace\xp_event_trace.ecf` → `xpact_event_trace` | **all on** (workbench) |

## 3. Commands and results

From [`logs/results.tsv`](logs/results.tsv):

| # | Step | Command | Exit | Result |
|---|---|---|---|---|
| 1 | event-trace | `xpact_event_trace.exe inputs\*.xml` | 0 | ✅ 7 documents traced, no contract violation |
| 2 | matrix-workbench | `run_eiffel_test_matrix.ps1 -AssertionMode On -BuildMode Workbench` | 1 | ❌ **postcondition violated** (K1) |
| 3 | matrix-finalized | `run_eiffel_test_matrix.ps1 -AssertionMode On -BuildMode Finalized` | 0 | ⚠️ "ok", but **assertions were not compiled in** (K2) |
| 4 | matrix-finalized-keep | `ec -finalize -keep … xpact_tests_assertions` + run | 1 | ❌ same postcondition violation as step 2 (K1) |
| 5 | native-runtime-smoke | `run_native_runtime_smoke.ps1 -AssertionMode On` | 0 | ✅ `xpact native runtime smoke: ok` |
| 6 | assertions-dll | `build_native_eiffel.ps1 -BuildTier Assertions` (smoke on) | 1 | ❌ DLL builds, **smoke crashes** (K3) |
| 7 | xmlconf | `run_xmlconf_conformance.ps1` | 0 | ⚠️ 1,314 / 2,168 pass, 854 mismatches (K5) |

## 4. Parser events

Full output: [`logs/event-trace-output.txt`](logs/event-trace-output.txt).
Inputs: [`event-trace/inputs/`](event-trace/inputs/). Each document is parsed
as one final input with the Eiffel parser (`XP_PARSER.parse`), all assertions on.

| Input | Result | Events delivered |
|---|---|---|
| `01-book.xml` `<book id="7"><title>Hello</title></book>` | ACCEPT | start book id="7" · start title · text "Hello" · end title · end book |
| `02-empty-root.xml` `<root/>` | ACCEPT | start root · end root |
| `03-incomplete.xml` `<root>` | REJECT "unclosed element" (1:6) | start root |
| `04-mismatched.xml` `<root><child></root>` | REJECT "mismatched end tag" (1:15) | start root · start child |
| `05-book-mismatched.xml` `<book><title>Hello</book>` | REJECT "mismatched end tag" (1:20) | start book · start title · text "Hello" |
| `06-bad-utf8.xml` `<r>` C3 28 `</r>` | **ACCEPT** ❌ | start r · text · end r (K4) |
| `07-rich.xml` (XML decl, DOCTYPE + entity, comment, PI, CDATA, attributes, empty element) | ACCEPT | 23 events, entity `&who;` expanded to "World", CDATA delivered as start-cdata · text · end-cdata |

What this shows:
- Events arrive in document order, and an entity reference arrives already expanded.
- Rejected documents deliver the events that came **before** the error, then
  fail. That is normal streaming behaviour (Expat does the same); no end or
  completion events follow the error.
- The parser accepts invalid UTF-8 (K4).

## 5. Known failures

| ID | Failure | Evidence | Status / note |
|---|---|---|---|
| **K1** | `XP_NATIVE_PARSER.parse @10 final_finished_or_suspended: Postcondition violated`, raised from `XP_TEST_ROOT.test_garbage_collection_suspension` | `matrix-workbench.log`, `matrix-finalized-keep.log` | Known (B03). Fails in workbench **and** finalized-with-`-keep`. The test runner stops at the first failure, so **tests after this one did not run** in the assertions-on lanes. *Update 2026-10-20:* root cause found in [#3](https://github.com/andersoxie/xpact/issues/3): a wrong loop variant in `XP_NATIVE_PARSER.direct_start_tag_attributes`, hidden behind this postcondition because `MEMORY.execute_without_collection` swallows exceptions ([#13](https://github.com/andersoxie/xpact/issues/13)). With the fix from pull request [#12](https://github.com/andersoxie/xpact/pull/12) (waiting for review) all four matrix cells pass, including the tests after this one. *Update 2026-10-22:* B03 also crashes `xpact_assertions.dll` on every input with `/>` (C API tests, [#37](https://github.com/andersoxie/xpact/issues/37)); with only the B03 change none of those crash. |
| **K2** | The "assertions-on / Finalized" lane does not check assertions | `run_eiffel_test_matrix.ps1` calls `ec -finalize` **without `-keep`**; with `-keep` (step 4) the lane fails like K1 | **New finding.** The green result in step 3 (and in CI) is misleading. Fix: add `-keep` to the finalized lane, as `build_native_eiffel.ps1` already does. Not changed here, because it alters what CI reports. Discuss with the supervisor first. |
| **K3** | Assertions-tier DLL smoke test crashes, exit code `-1073741784` = **`0xC0000028` STATUS_BAD_STACK** | `assertions-dll.log` | Known open issue. Earlier notes recorded `0xC0000008` (STATUS_INVALID_HANDLE): the crash code is not stable. CI hides this with `-SkipSmoke`. *Update 2026-10-22:* still `0xC0000028` with the B03 fix applied, so B03 is not its only cause ([results](../results/dll-tests-2026-10-22/README.md)). |
| **K4** | Invalid UTF-8 (`C3 28`) accepted | `event-trace-output.txt` (06), xmlconf | Known (P0, C08/C10). *Update 2026-10-22:* one case of [#39](https://github.com/andersoxie/xpact/issues/39): `C3 28`, `C0 AF`, `ED A0 80` and `F4 90 80 80` are accepted in text, attributes, names, comments, PIs and CDATA. |
| **K5** | xmlconf: 854 of 2,168 mismatches | `xmlconf-summary.txt`, `xmlconf-results.tsv` | Breakdown below. |

K5 grouped by expected type (from `logs/xmlconf-results.tsv`):

| Type | Mismatches | Meaning |
|---|---:|---|
| not-wf | 527 | malformed XML **accepted**. 129 of them need external entities, which this runner does not resolve. **This is the most important group.** |
| invalid | 197 | well-formed but DTD-invalid, accepted. **Probably not bugs**: a non-validating parser should accept these (student guide, "Read the expected outcome correctly"). This runner expects REJECT. |
| valid | 115 | valid XML **rejected**. 86 of them need external entities. |
| error | 15 | optional errors; there is no required verdict. |

## 6. Limits of this baseline

- Every document is parsed as **one final chunk**. Chunk boundaries and the
  native C API (`XML_Parse`) are not covered here (week 5, C03).
- The xmlconf runner expects REJECT for `invalid` and runs cases that need
  external entities and XML 1.1. Its 854 figure is therefore not comparable with
  the teacher's Python runner, which uses non-validating rules.
- The results are from a checkout with no git history. Use the source fingerprint to match them to a later commit.
