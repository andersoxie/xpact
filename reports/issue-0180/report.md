# Report: issue #180: `run_benchmarks.ps1 -Repetitions 1` stopped in `AddRange`

> **Issue:** [#180](https://github.com/andersoxie/xpact/issues/180) A04-2 · found by A04 ([#168](https://github.com/andersoxie/xpact/issues/168))
> **Branch:** `fix/180-benchmarks-single-repetition`, from `student-Mass` @ `48c2fb8` · **Changed:** `scripts/run_benchmarks.ps1` (1 line + comment)
> **Status:** ✅ fixed · ✅ verified locally · 🟡 waiting for review; Jenkins is not affected (it uses the default, 3)

## In short

`Invoke-TimedCommand` collects one row per repetition in a `List[object]` and returned it as `$Rows`. With **one** repetition PowerShell unrolls the one-element list to a single object, and `$AllRows.AddRange(...)` rejects a single object. Now it returns `,$Rows`, which keeps the list a list. `run_large_xml_benchmarks.ps1` already does exactly this.

| Command | Before | After |
|---|---|---|
| `-Repetitions 1` | ❌ exit 1 after 3 s: `Cannot convert argument "collection" … for "AddRange"` | ✅ exit 0, 10 benchmark rows, W3C 2585 / 2585 for both builds |
| `-Repetitions 3` (Jenkins default) | ✅ | ✅ exit 0, 30 benchmark rows (10 × 3), W3C 2585 / 2585 for both builds |

## Problem report (CLAUDE.md format)

| Field | |
|---|---|
| **1. Problem** | `run_benchmarks.ps1 -Repetitions 1` stops after the first benchmark |
| **2. Environment** | Windows 11 (student PC), `student-Mass` @ `48c2fb8`, Windows PowerShell 5.1, Visual Studio 18 Community, EiffelStudio 25.12, both Eiffel builds (Finalized = production, FinalizedAssertions = assertions on) |
| **3. Command** | `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_benchmarks.ps1 -Iterations 1 -Repetitions 1 -SkipBuild -SkipWslC -W3cAllCases -OutputDir build\fix180\before` |
| **4. Expected** | one timed row per benchmark; the run goes on |
| **5. Actual** | exit 1 after the first benchmark |
| **6. Error output** | `Cannot convert argument "collection", with value: "@{Benchmark=catalog-100-items; …}", for "AddRange" to type "System.Collections.Generic.IEnumerable``1[System.Object]"` ([before-fix.txt](logs/before-fix.txt)) |
| **7. Investigation** | the value in the error is a single `PSCustomObject`; `Invoke-TimedCommand` ends with `$Rows`, which PowerShell unrolls when it holds one item; every caller passes the result to `AddRange`; `-Repetitions 2` and `3` work |
| **8. Cause** | ✅ **confirmed**: reproduced before the fix, gone after it (see Verification) |
| **9. Fix** | `,$Rows` instead of `$Rows` at the end of `Invoke-TimedCommand` |
| **10. Verification** | ✅ see Verification below |

## The change

```diff
-	$Rows
+	# The comma keeps a one-row list a list (-Repetitions 1); PowerShell would
+	# otherwise unroll it to a single object, which AddRange rejects.
+	,$Rows
```

All 12 calls of `Invoke-TimedCommand` in the script are `$AllRows.AddRange((Invoke-TimedCommand …))`, so none depends on the unrolled form.

## Verification

| Check | Command (all with `-Iterations 1 -SkipWslC -W3cAllCases`) | Result | Log |
|---|---|---|---|
| Bug, **old** script | `-Repetitions 1 -SkipBuild` | ❌ as reported: exit 1, `AddRange` error | [before-fix.txt](logs/before-fix.txt) |
| Fix, fresh builds | `-Repetitions 1` (builds both Eiffel targets first) | ✅ exit 0, 341 s; 10 benchmark rows; W3C Finalized and FinalizedAssertions 2585 cases, 0 failed, 0 errors, 0 unexpected | [after-fix-repetitions-1-with-build.txt](logs/after-fix-repetitions-1-with-build.txt), [rows](logs/benchmark-results-repetitions-1.tsv), [W3C summary](logs/w3c-summary-repetitions-1-with-build.md) |
| Regression, Jenkins setting | `-Repetitions 3 -SkipBuild` (on those fresh builds) | ✅ exit 0, 211 s; 30 rows; W3C as above | [after-fix-repetitions-3.txt](logs/after-fix-repetitions-3.txt) |

The runs write the timing tables into `docs/benchmarks.md`; that generated change was reverted and is not part of this fix.

## Problems met (kept separate)

**Stale benchmark executables under `-SkipBuild`** (local environment, not this fix, not Jenkins):

- **What happened:** the first runs after the fix used `-SkipBuild`. They got past the `AddRange` point, so 10 and 30 rows were written, but they ended with exit 1 in the W3C stage: 2509 of 2585 errors, `Exit code 2; missing or inconsistent verdict`, and the engine printed `usage: --conformance-file PATH [--namespaces]`.
- **Cause:** ✅ **confirmed**. The `xpact_benchmarks.exe` files in `xpactGit\EIFGENs` dated from 2026-10-23. The benchmark source changed on 2026-10-28 (`eae4529`), and the old programs did not know the options the runner now passes. After a rebuild, the same stage passed: 2585 / 2585.
- **Logs:** [after-fix-repetitions-1-stale-build.txt](logs/after-fix-repetitions-1-stale-build.txt), [after-fix-repetitions-3-stale-build.txt](logs/after-fix-repetitions-3-stale-build.txt).
- **Lesson:** use `-SkipBuild` only right after a build of the same commit. Jenkins always builds, so it is not affected.

## Limitations

- Jenkins was not run. It uses `-Repetitions 3`, a path that is checked above.
- The WSL C benchmark was skipped (`-SkipWslC`), as in A04. That code path calls the same `Invoke-TimedCommand`.
- No automated test covers `run_benchmarks.ps1`. This fix is verified by real runs only.

## Revert

`student\tools\fix.ps1 revert -Issue 180 -Commit <sha>`, or `git revert <sha>`.
