# Fix report: issue #74, native build scripts override the machine's MSVC backend

Issue: [#74](https://github.com/andersoxie/xpact/issues/74)   Branch: `fix/74-keep-msvc-backend`   Base: `student-Mass` @ `82ad4cb`   Date: 2026-10-23

## In short

| | |
|---|---|
| ⚠️ Problem | `build_native_eiffel.ps1` and `run_native_runtime_smoke.ps1` **always** set `ISE_C_COMPILER=msc_vc140`, overriding the backend a machine already uses |
| 🔎 Status | A risk, **not seen failing**: Jenkins stopped earlier ([#73](https://github.com/andersoxie/xpact/issues/73)). Found while checking every student build change against the Jenkins machine |
| ✔ Cause (confirmed) | The two assignments added in `eb6fc5d` (#7, PR #8) and `20e6bc3` (#10, PR #11) |
| 🔧 Fix | Keep a backend that is already MSVC (`msc*`); switch only an unset or non-MSVC backend to `msc_vc140` |
| ✅ Verified here | 8 of 8 cases pass (2 failed before); both builds unchanged on the student PC |

## 1. Problem

| | |
|---|---|
| Environment | Any machine with `ISE_C_COMPILER` set to an MSVC backend other than `msc_vc140`, e.g. `msc` |
| Command | `scripts\build_native_eiffel.ps1`, `scripts\run_native_runtime_smoke.ps1` |
| Expected | A machine that already builds with an MSVC backend keeps it, as before the student fixes; the scripts only need *some* MSVC backend (for the `.lnk` link response file and MSVC CRT symbols) |
| Actual | Always `msc_vc140` |
| Cause | Confirmed from the code. Whether `msc_vc140` works on the Jenkins machine (EiffelStudio 25.02 Enterprise, VS 2022) is **unknown**; which backend Jenkins has set is also **unknown** |

Why `msc_vc140` was chosen in #7: the plain `msc` backend does not link with
Visual Studio 18 on the student PC. That is still handled: the student PC has
`ISE_C_COMPILER` unset, so it still gets `msc_vc140`.

## 2. Fix

```powershell
$OldCompiler = $env:ISE_C_COMPILER
# Keep an MSVC backend the machine already selects (for example "msc" on the
# Jenkins machine); switch only an unset or non-MSVC backend to "msc_vc140".
if ($OldCompiler -notlike "msc*") {
	$env:ISE_C_COMPILER = "msc_vc140"
}
```

The old value is still restored in the existing `finally` block.

## 3. Expected results (written before testing)

| # | Check | Expected |
|---|---|---|
| 1 | Backend test, old code | `msc` is replaced by `msc_vc140` (the problem) |
| 2 | Backend test, new code | unset → `msc_vc140`, `mingw` → `msc_vc140`, `msc` → `msc`, `msc_vc140` → `msc_vc140` |
| 3 | `build_native_eiffel.ps1 -BuildTier Production` on the student PC | unchanged: DLL built, smoke ok, exit 0 |
| 4 | `run_native_runtime_smoke.ps1` on the student PC | unchanged: both cells ok, exit 0 |

## 4. Verification

Student PC (Windows 11, EiffelStudio 25.12.9.8922 Standard, VS 18),
`ISE_C_COMPILER` and `ISE_EIFFEL` unset. Each command in a fresh `powershell -NoProfile`.

[test-compiler-choice.ps1](test-compiler-choice.ps1) takes the two
statements out of each script (save the old value, select the backend) and
runs them for four starting values, without compiling:

| Starting value | Expected | Old code | New code |
|---|---|---|---|
| (unset) | `msc_vc140` | ✅ | ✅ |
| `mingw` | `msc_vc140` | ✅ | ✅ |
| `msc` | `msc` | ❌ `msc_vc140` | ✅ |
| `msc_vc140` | `msc_vc140` | ✅ | ✅ |

Same for both scripts. Logs: [before.txt](before.txt) (2 failures, exit 1), [after.txt](after.txt) (0 failures, exit 0).

| # | Command | Actual | Exit | Log |
|---|---|---|---|---|
| 3 | `. .\scripts\import_msvc_environment.ps1; .\scripts\build_native_eiffel.ps1 -BuildTier Production` | `Built ...\xpact.dll (Production)`, `xpact Eiffel DLL smoke: ok` | 0 | [after-build-native-production.txt](after-build-native-production.txt) |
| 4 | `. .\scripts\import_msvc_environment.ps1; .\scripts\run_native_runtime_smoke.ps1` | both cells `xpact native runtime smoke: ok` | 0 | [after-native-runtime-smoke.txt](after-native-runtime-smoke.txt) |

## 5. Limitations

- ⏳ **Not run on Jenkins**, and a build with `msc` itself was not run (it does
  not link on the student PC's Visual Studio 18, which is why #7 chose
  `msc_vc140`). Only the selection logic is tested for `msc`.
- Independent of #73; both touch the same two scripts in different places.

## How to revert

```powershell
.\student\tools\fix.ps1 revert -Issue 74 -Commit <merged sha>
```
