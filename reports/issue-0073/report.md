# Fix report: issue #73, Jenkins DLL build cannot find the Eiffel include folder

Issue: [#73](https://github.com/andersoxie/xpact/issues/73)   Branch: `fix/73-eiffel-include-fallback`   Base: `student-Mass` @ `82ad4cb`   Date: 2026-10-23

## In short

| | |
|---|---|
| 🔴 Problem | Jenkins stopped at "Build Eiffel-Backed DLL": `Cannot find Eiffel runtime include directory.` Every later stage was skipped |
| ✔ Cause (confirmed) | Our own fixes **replaced** the Jenkins machine's fallback `C:\El2502E` with the student PC's path, instead of adding it |
| 🔧 Fix | Both scripts now search a list: `ISE_EIFFEL` → `C:\El2502E` → EiffelStudio 25.12 Standard → the EiffelStudio whose `ec` is on `PATH` |
| ✅ Verified here | 14 of 14 lookup cases pass (8 failed before, including the exact Jenkins error); DLL and runtime smoke still build on the student PC |
| ✅ Verified on Jenkins | Found 2026-10-26: the supervisor's run on `main` @ `cf12dee` (which contains this fix) passed "Build Eiffel-Backed DLL" with `C:\El2502E`. See section 7 |

## 1. Problem (error report)

| | |
|---|---|
| Environment | Supervisor's Jenkins: EiffelStudio 25.02.9.8723 Enterprise (win64), VS 2022 Build Tools (cl 19.44.35229), Windows 11 |
| Revision | `main` @ `9e1747d` ("Merge pull request #72 from andersoxie/student-Mass"); same files as `student-Mass` @ `82ad4cb` |
| Command | `scripts\build_native_eiffel.ps1`, Jenkins stage "Build Eiffel-Backed DLL" (`ci/Jenkinsfile.windows-phase1`) |
| Expected | The include folder is found, as before the student fixes |
| Actual | `Cannot find Eiffel runtime include directory.` at `scripts\build_native_eiffel.ps1:46`; build FAILURE |
| Error output | [jenkins-log-2026-10-23.txt](jenkins-log-2026-10-23.txt) (complete console output) |

## 2. Investigation

1. The thrown line is the end of `Get-IseInclude`, which tried `ISE_EIFFEL`
   and then one fixed fallback path.
2. `git log -S "El2502E"` shows which commits changed that fallback:
   - `9eb18bd` (#2) in `build_native_eiffel.ps1`: `C:\El2502E\...` →
     `C:\Program Files\Eiffel Software\EiffelStudio 25.12 Standard\...`
   - `20e6bc3` (#10, PR #11) did the same in `run_native_runtime_smoke.ps1`.
3. `El2502E` = EiffelStudio **25.02 Enterprise**, the version the Jenkins log
   prints. So the old path was the Jenkins install, and both fixes removed it.
4. Every other student change to `scripts/`, `ci/` and the `.ecf` files since
   `main`'s base `fee611a` was checked for the same kind of problem
   (machine-specific values):

   | Change | Issue | Machine-specific? |
   |---|---|---|
   | Include fallback in 2 scripts | #2, #10 | ❌ **yes: this report** |
   | `ISE_C_COMPILER` forced to `msc_vc140` in 2 scripts | #7, #10 | ⚠️ yes, overrides the machine's backend: **separate finding [#74](https://github.com/andersoxie/xpact/issues/74)** |
   | `base_pre` precompile removed from 2 `.ecf` | #7, #10 | no (slower build only) |
   | MSVC import: skip if loaded, PATH de-duplicated, VS Installer on PATH | #4, #51 | no; the Jenkins log shows "Loaded Visual Studio C++ x64 environment" |
   | Test matrix `-keep`, MSVC for `msc*` workbench, run from repo root | #48, #53, #55 | no |
   | `run_w3c_conformance.py` on Python 3.10 | #32 | no |

   A search of tracked code for user-specific paths (`masou`, `C:\Users`,
   `Desktop`, `Program Files`) found only these two fallbacks (the CMake
   paths in `run_libexpat_adapter.ps1` were already in `main`).

**Cause: confirmed** from the diffs. That `ISE_EIFFEL` is unset on Jenkins is
**suspected** (otherwise it would have been used first); not seen.

## 3. Fix

`Get-IseInclude`, the same in both scripts:

| Order | Root searched | Why |
|---|---|---|
| 1 | `$env:ISE_EIFFEL` | the standard EiffelStudio variable, as before |
| 2 | `C:\El2502E` | EiffelStudio 25.02 Enterprise, the Jenkins machine (**restored**) |
| 3 | `C:\Program Files\Eiffel Software\EiffelStudio 25.12 Standard` | the student PC (kept) |
| 4 | four folders above `ec.exe` on `PATH` | any other install; `ec` is on `PATH` on Jenkins (it runs `ec` in "Eiffel Tests") |

A root counts only if `studio\spec\win64\include` exists in it. When none is
found the error now lists every folder searched.

## 4. Expected results (written before testing)

| # | Check | Expected |
|---|---|---|
| 1 | Lookup test, **old** code | the Jenkins case fails with the Jenkins error |
| 2 | Lookup test, new code | all 7 cases pass in both scripts |
| 3 | `build_native_eiffel.ps1 -BuildTier Production` on the student PC | DLL built, `xpact Eiffel DLL smoke: ok`, exit 0 |
| 4 | `run_native_runtime_smoke.ps1` on the student PC | both cells `xpact native runtime smoke: ok`, exit 0 |

## 5. Verification

Student PC (Windows 11, EiffelStudio 25.12.9.8922 Standard, VS 18 / MSVC),
`ISE_EIFFEL` and `ISE_C_COMPILER` unset, `C:\El2502E` does not exist.
Each command in a fresh `powershell -NoProfile`.

**The lookup test** [test-get-iseinclude.ps1](test-get-iseinclude.ps1) takes
`Get-IseInclude` out of each script, replaces the two known roots with fake
folders in a temporary directory, and runs 7 cases:

| # | Case | Old code | New code |
|---|---|---|---|
| 1 | **Jenkins**: no `ISE_EIFFEL`, only `C:\El2502E`, no `ec` | ❌ `Cannot find Eiffel runtime include directory.` | ✅ El2502E |
| 2 | Student: no `ISE_EIFFEL`, only 25.12 Standard | ✅ | ✅ |
| 3 | valid `ISE_EIFFEL` wins | ✅ | ✅ |
| 4 | `ISE_EIFFEL` without include folder is skipped | ❌ | ✅ |
| 5 | both installs: `C:\El2502E` first | ❌ (25.12) | ✅ |
| 6 | no known install, `ec` on `PATH` | ❌ | ✅ |
| 7 | nothing: clear error | ✅ | ✅ (lists the folders searched) |

Logs: [before.txt](before.txt) (8 failures, exit 1), [after.txt](after.txt) (0 failures, exit 0).

**The real builds**, run like the Jenkins stage (MSVC imported first):

| # | Command | Actual | Exit | Log |
|---|---|---|---|---|
| 3 | `. .\scripts\import_msvc_environment.ps1; .\scripts\build_native_eiffel.ps1 -BuildTier Production` | `Built ...\build\native-eiffel\xpact.dll (Production)`, `xpact Eiffel DLL smoke: ok` | 0 | [after-build-native-production.txt](after-build-native-production.txt) |
| 4 | `. .\scripts\import_msvc_environment.ps1; .\scripts\run_native_runtime_smoke.ps1` | assertions-on and assertions-off: `xpact native runtime smoke: ok` | 0 | [after-native-runtime-smoke.txt](after-native-runtime-smoke.txt) |

## 6. Limitations

- ~~Not run on Jenkins.~~ Done: see section 7.
- If Jenkins gets past this stage, it reaches the compiler setting of
  [#74](https://github.com/andersoxie/xpact/issues/74) next; that is a separate fix.
- Not related, also in the same Jenkins log: SonarQube `HTTP 401` (server
  token, supervisor) and the "Eiffel Tests" stage showing no test output.
- The assertions tier of the DLL was not rebuilt: its smoke test crashes for
  a known, unrelated reason (K3, draft 07).

## 7. Verified on Jenkins (found 2026-10-26)

The fix (`63f67f3`, PR #75) reached `main` with the supervisor's merge of
`student-Mass` (PR #78, `cf12dee`, 2026-10-23); `git merge-base --is-ancestor 63f67f3 cf12dee` is true.
The supervisor then ran Jenkins on `main` @ `cf12dee`. That log was saved for
#79 as [`../issue-0079/jenkins-log-cf12dee-before.txt`](../issue-0079/jenkins-log-cf12dee-before.txt);
it was not connected back to #73 until 2026-10-26.

| Line | Log | Meaning |
|---|---|---|
| 135 | `[Pipeline] { (Build Eiffel-Backed DLL)` | the stage that failed on 2026-10-23 |
| 204 | `"C:\El2502E\studio\spec\win64\lib\msc_vc140\finalized.lib" ...` | the Jenkins install was found |
| 216, 218 | `Built ...\build\native-eiffel\xpact.dll (Production)`, `xpact Eiffel DLL smoke: ok` | production DLL built and smoke test passed |
| 292 | `Built ...\build\native-eiffel\xpact_assertions.dll (Assertions)` | assertions DLL built |
| 296-305 | `Native ABI Smoke`: `xpact public ABI smoke: ok` | the later stages run |
| 1232 | `Finished: FAILURE` | from the W3C check, a separate problem: [#79](https://github.com/andersoxie/xpact/issues/79) |

**Result:** expected (stage passes with `C:\El2502E`) = actual. #73 closed 2026-10-26.
The supervisor did not comment on #73; the evidence is the log only.

## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 73 -Commit <merged sha>
```
