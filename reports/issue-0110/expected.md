# #110 expected results (written 2026-10-26 before the runs)

Code: student-Mass @ e8c5cb3 (contains main @ de01371, the supervisor's #101).
Folder: C:\Users\masou\Desktop\Lia\xpact3.0\xpact-codex-w3c-xml-conformance-benchmarks (synced).
Setting: ISE_C_COMPILER=msc_vc140 for every Eiffel build. Python 3.14.0.

| # | Check | Expected | Why |
|---|---|---|---|
| 1 | run_eiffel_test_matrix.ps1 -AssertionMode All -BuildMode All | 4 x "xpact Phase 1 tests: ok", exit 0, MSVC only | passed before #101 (#104 and the MSVC rerun); #101 adds 533 test lines, which the supervisor ran on Jenkins |
| 2 | build_native_eiffel.ps1 (Production) | DLL smoke ok, exit 0 | as in #104 |
| 3 | build_native_eiffel.ps1 -BuildTier Assertions | DLL smoke ok, exit 0 | as in #104 |
| 4 | XpactDllTests on xpact_assertions.dll | 3,360/3,360, 0 crash | as in #104 |
| 5 | XpactDllTests on xpact.dll | 3,360/3,360, 0 crash | as in #104 |
| 6 | run_benchmarks.ps1 -EiffelBuild Finalized,FinalizedAssertions -SkipWslC | W3C 1,727 passed, 0 failed, 0 errors, both builds | as in #104 |
| 7 | python -m unittest discover -s tests/python (3.14) | all pass except the long-path test(s) in this deep folder, if Windows long paths are still off | #104: 15 problems with 3.13 here, caused by paths over 260 characters |

If #101 changes behaviour, the place to look first is src/xp_parser.e (input normalization, text positions, DOCTYPE).
