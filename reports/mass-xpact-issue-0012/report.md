# Report: mass-xpact #12: assertions DLL stopped on an invalid UTF-16 surrogate in resumed input

> **Issue:** [CodTanium/mass-xpact#12](https://github.com/CodTanium/mass-xpact/issues/12) · **Branch:** `perf/resume-utf16` (PR #8), the fix is a second commit on top of #7
> **Changed:** `src/xp_native_parser.e` (`append_decoded_utf16`)
> **Status:** ✅ fixed · ✅ verified locally, both DLL tiers · regression from [#7](../mass-xpact-issue-0007/report.md)

## 1. In short

The UTF-16 resume of #7 broke a loop contract when the new bytes hold an invalid or unfinished
surrogate. Only the **assertions** DLL checks loop variants, so only it stopped; the production DLL
gave the right result. Found by running the Expat suite on the assertions DLL for the first time
(a limitation listed in the #7 report).

| ✅ Result | Before the fix | After |
|---|---|---|
| Expat 2.8.1 `runtests`, assertions DLL | Checks 399, **Failed 40** | Checks 399, **Failed 38** (the 38 expected) |
| `test_utf16_bad_surrogate_pair`, `test_bad_cdata_utf16` (assertions) | crash `0xC00000FF` | pass |

## 2. Problem report

| Field | |
|---|---|
| **1. Problem** | The assertions DLL stops on a loop variant violation in `append_decoded_utf16`. |
| **2. Environment** | Windows 11, student PC2; EiffelStudio 25.12; MSVC (VS 18); Expat 2.8.1 sources. Assertions DLL from `perf/resume-utf16` @ `c7bf4e6`. |
| **3. Command** | `scripts\run_libexpat_adapter.ps1 -Mode NativeSuite -ExpatSourceDir <expat-2.8.1> -XpactLibrary <dir>\xpact_assertions.lib -SkipNativeBuild -SkipXpactBuild -OutputDir <out>`; one test: `<out>\cbuild\Debug\xpact_libexpat_runtests.exe --timeout 120 --test test_bad_cdata_utf16` with the DLL directory first on `PATH`. |
| **4. Expected** | Checks 399, Failed 38, as on the production DLL. |
| **5. Actual** | Checks 399, Failed 40. |
| **6. Error output** | `***Exception: test_utf16_bad_surrogate_pair exited with code 0xC00000FF`, the same for `test_bad_cdata_utf16`. Full log: [runtests-assertions-before.txt](logs/runtests-assertions-before.txt). |
| **7. Investigation** | The same test exe with each assertions DLL on `PATH`: baseline `253c81e` ✅, #2 `7c3eda4` ✅, #7 `c7bf4e6` ❌. A byte-by-byte ctypes repro stopped on the byte that completes the lone low surrogate `DC00`. |
| **8. Cause** | ✅ **Confirmed** (the fix removes it). The failure branches of the decode loop set `Result := False` without moving `i`, so the variant `l_end - i + 1` did not decrease in that iteration. |
| **9. Fix** | On failure set `i := l_end + 1`; the loop then ends by its index condition. The result and the fallback to the full replay are unchanged. |
| **10. Verification** | ✅ Section 3. |

## 3. Verification

| Check | Result | Log |
|---|---|---|
| ✅ Build + smoke test, both tiers | ok ×2 | |
| ✅ The two tests alone, assertions DLL | `Checks: 1, Failed: 0` each | |
| ✅ Expat 2.8.1 `runtests`, assertions | Checks 399, Failed 38: the same 38 allocator tests as production | [runtests-assertions.txt](logs/runtests-assertions.txt) |
| ✅ Expat 2.8.1 `runtests`, production | Checks 399, Failed 38 (unchanged) | [runtests-production.txt](logs/runtests-production.txt) |
| ✅ `XpactDllTests` (4,308 cases) | 4,308 / 4,308 ×2; `results.tsv` byte-identical to `c7bf4e6`, both tiers | |

## 4. Limitations

- [ ] Test 2 and the traces were not run again for this fix: it changes only the iteration in which
  an already failing decode stops (the DLL tests above cover the UTF-16 error cases).
