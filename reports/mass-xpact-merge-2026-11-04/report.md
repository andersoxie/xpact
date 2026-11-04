# Post-merge check: `student-Mass` @ `8ccf51b` (2026-11-04)

> **What:** the speed-work PRs merged into `student-Mass` on 2026-11-04, tested together as one build.
> **Status:** ✅ verified · open problem: [mass-xpact#20](https://github.com/CodTanium/mass-xpact/issues/20) (pre-existing, see below)

## 1. In short

| | Check | Result |
|---|---|---|
| ✅ | Both tiers build | `System Recompiled.`; production 1,549,824 bytes (no `-keep`, inlining), assertions 9,965,056 bytes; smoke test `ok` on both |
| ✅ | DLL tests (4,308 cases), both tiers | **4,308 / 4,308** pass; `results.tsv` byte-identical to the #11 build (`perf/resume-text-runs`), both tiers |
| ✅ | Expat 2.8.1 `runtests`, both tiers | `Checks: 399, Failed: 38` on both; the **same 38 test names** as before the merges (the allocator tests) |
| ℹ️ | Difference from the old baseline (`253c81e`) | One case, `utf8-bad-continuation-text/none/bytes`: rejected on call **5** instead of 6 (see section 3) |

## 2. What was merged

In merge order. `main` is untouched (`733688e`).

| PR | Issue | Change |
|---|---|---|
| [#6](https://github.com/CodTanium/mass-xpact/pull/6) | [#5](https://github.com/CodTanium/mass-xpact/issues/5) | Test 2 harness runs cases in parallel |
| [#10](https://github.com/CodTanium/mass-xpact/pull/10) | [#9](https://github.com/CodTanium/mass-xpact/issues/9) | W3C runner `--jobs` |
| [#19](https://github.com/CodTanium/mass-xpact/pull/19), [#22](https://github.com/CodTanium/mass-xpact/pull/22) | | Session notes; every speed report on `student-Mass` |
| [#4](https://github.com/CodTanium/mass-xpact/pull/4) | [#2](https://github.com/CodTanium/mass-xpact/issues/2) | Chunked parsing resumes instead of re-parsing the buffer |
| [#8](https://github.com/CodTanium/mass-xpact/pull/8) | [#7](https://github.com/CodTanium/mass-xpact/issues/7), [#12](https://github.com/CodTanium/mass-xpact/issues/12) | UTF-16 input resumes too; assertions regression fixed |
| [#13](https://github.com/CodTanium/mass-xpact/pull/13) | [#11](https://github.com/CodTanium/mass-xpact/issues/11) | Long text runs continue instead of re-parsing |
| [#23](https://github.com/CodTanium/mass-xpact/pull/23) | [#15](https://github.com/CodTanium/mass-xpact/issues/15) | Build stops when `ec` generated no new C |
| [#16](https://github.com/CodTanium/mass-xpact/pull/16) | [#14](https://github.com/CodTanium/mass-xpact/issues/14) | Production DLL finalized without `-keep` (3.5× faster) |
| [#18](https://github.com/CodTanium/mass-xpact/pull/18) | [#17](https://github.com/CodTanium/mass-xpact/issues/17) | Eiffel inlining for the production DLL (15–20 % faster) |

#16 and #23 change neighbouring lines of `build_native_eiffel.ps1`. Git merged them without a conflict, and the merged script has both changes. Still open: [#21](https://github.com/CodTanium/mass-xpact/pull/21), static `STRING_8` input (draft, parked).

## 3. Details

**Environment:**
- Windows 11, student PC2, 16 logical CPUs.
- EiffelStudio 25.12.9.8922, `msc_vc140`, MSVC (VS 18).
- Branch `student-Mass` @ `8ccf51b`, checked out as `verify/student-Mass-8ccf51b`.

**Commands:**
- `.\scripts\build_native_eiffel.ps1 -OutputDir build\sm-8ccf51b\native-eiffel` ([log](logs/build-production.log)), and the same with `-BuildTier Assertions` ([log](logs/build-assertions.log)).
- DLL SHA-256: production `9908800d…0aab84`, assertions `7b34b4f2…3cad59`.
- `XpactDllTests.exe --dll <dll> --out <dir> --jobs 8` ([production](logs/dlltests-production-summary.txt), [assertions](logs/dlltests-assertions-summary.txt)).
- `xpact_libexpat_runtests.exe --timeout 600`, with the DLL first on `PATH`, default GC settings ([production](logs/expat-runtests-production.txt), [assertions](logs/expat-runtests-assertions.txt), [expected 38](logs/expat-expected-failures-38.txt)). It ran 70 s for production and 480 s for assertions.

**The one difference from the old baseline** ([diff](logs/dlltests-diff-vs-baseline.txt)):
- Input `<r>\xc3(</r>` fed one byte per call. The UTF-8 sequence becomes invalid at the 5th byte, `(` after `\xc3`.
- The old parser reported the error on call 6; the merged one reports it on call 5, the earliest possible.
- Verdict, error code (4), line, column and byte index are unchanged.
- It comes from the parser chain #4 / #8 / #13: the #11 build already has it.
- It wasn't mentioned in those PRs' reports.

## 4. Known problem, not caused by these PRs

[mass-xpact#20](https://github.com/CodTanium/mass-xpact/issues/20): heap corruption in `test_deep_nested_attribute_entity` under GC stress (`EIF_MEMORY_SCAVENGE=65536`, `EIF_FULL_COLLECTION_PERIOD=1`) and heavy machine load.

| | Build, same load (12 runs in parallel) | Crashes |
|---|---|---|
| ⚠️ | `student-Mass` as it was before these merges | 2 in 12 |
| ⚠️ | With #16 | 2 in 12 |
| ⚠️ | With the parser chain | 1 in 12 |

So none of the merged PRs causes it ([report](../mass-xpact-issue-0020/report.md)). It wasn't seen in the normal Expat runs above.

## 5. Limitations

- [ ] Test 2, the traces/CRC harness and the Eiffel test matrix were not rerun on the merged build. Each was run on the individual PR branches; see their reports.
- [ ] The GC-stress problem (#20) is open and its cause unknown.
