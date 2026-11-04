# Report: mass-xpact #15: the build relinked stale C when `ec` rejected its options

> **Issue:** [CodTanium/mass-xpact#15](https://github.com/CodTanium/mass-xpact/issues/15) · **Branch:** `fix/15-ec-stale-relink`, from `student-Mass` @ `896a3ab`
> **Changed:** `scripts/build_native_eiffel.ps1` (build script only, no parser code)
> **Status:** ✅ fixed · ✅ verified (failure case and normal build)

## 1. In short

`ec` exits with code 0 even when it rejects its command line. The script then ran
`finish_freezing` and `link` on the **previous** build's generated C, and reported a new DLL that was
really the old code. Now the script also checks that `ec` regenerated `F_code\Makefile.SH` during
this run. If it didn't, the build stops before anything is linked.

## 2. The problem

| Field | |
|---|---|
| **Environment** | Windows 11, student PC2, EiffelStudio 25.12.9.8922, MSVC (`msc_vc140`) |
| **Command** | `.\scripts\build_native_eiffel.ps1 -BuildTier Production -OutputDir build\nokeep\native-eiffel`, with a draft of #14 that passed `ec` a broken argument |
| **Expected** | The script stops with a compilation error |
| **Actual** | Exit 0, `Built ...xpact.dll`, the smoke test passed, but the DLL was the old code |
| **Error output** | `ec.exe: incorrect options` / ``Unknown option `-'.``, nothing else |
| **Cause** | ✔ confirmed: `ec` returns 0 on invalid options, so `$EiffelExitCode -ne 0` never fires |

## 3. The change

- [x] Note the time just before `ec` runs.
- [x] After `ec`, require `EIFGENs\<target>\F_code\Makefile.SH` to exist and to be newer than that time,
  with 2 s of slack for file time rounding. `ec` writes this file on every finalize. `finish_freezing`
  writes `Makefile` and the `.lnk` files after it.
- [x] Otherwise throw `... generated no new C code (see the ec output above)`, before `finish_freezing` and `link`.

## 4. Verification

| Check | Command | Result |
|---|---|---|
| ✅ Failure case | A temporary copy of the script whose `ec` call gets an extra `-` option (the original bug), `-OutputDir build\t15-bad\native-eiffel -SkipSmoke` | `ec`: `incorrect options`; script **exit 1** with the new message; `Makefile.SH` time unchanged; no DLL written ([log](logs/bad-option-build.log)) |
| ✅ Normal build | `.\scripts\build_native_eiffel.ps1 -OutputDir build\t15-good\native-eiffel` (smoke test on) | `System Recompiled.`; script **exit 0**; DLL 9,869,824 bytes (with `-keep`, as on `student-Mass`); `xpact Eiffel DLL smoke: ok` ([log](logs/normal-build.log)) |

The temporary copy was deleted after the test; it isn't committed.

## 5. Limitations

- Whether `ec` also exits 0 on a real **compile error** is still unknown. If it does, the same check
  catches it, because no new `Makefile.SH` is written then either.
- A clock that jumps backwards by more than 2 s during a build would make a fresh file look stale.
  The build would then stop with this message and could simply be rerun.

## 6. How to revert

Revert this PR's commit; the script returns to checking only `ec`'s exit code.
