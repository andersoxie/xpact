# Report: issue #142, re-enable the DLL smoke tests that CI and the release script skip

Issue: [#142](https://github.com/andersoxie/xpact/issues/142)   Branch: `fix/142-reenable-smoke`   Base: `student-Mass` @ `36509b8`   Date: 2026-10-27

## In short

| | |
|---|---|
| ✅ Assertions DLL smoke | back on in both Jenkinsfiles and in `package_windows_release.ps1` |
| ✅ Production DLL smoke | back on in the libexpat adapter stage (`ci/Jenkinsfile.all-tests`) |
| ✅ Local check | all three builds print `xpact Eiffel DLL smoke: ok`, exit 0 |
| ⬜ Jenkins | not run yet; #142 stays open until the *build Eiffel-backed DLLs* step is green on Jenkins |

## Cause (confirmed)

`-SkipSmoke` was added to the assertions build to hide K3, the crash at
load (`0xC0000028`, [draft 07](../../student/github/issues/07-finding-dll-crash.md),
baseline K3). K3 was fixed in PR [#80](https://github.com/andersoxie/xpact/pull/80)
([#79](https://github.com/andersoxie/xpact/issues/79)) and checked on the student
PC in [#104](../issue-0104/report.md). After that, the skip only hid new failures.

## Change

| File | Before | After |
|---|---|---|
| `ci/Jenkinsfile.all-tests`, *Windows Native Tests* | `build_native_eiffel.ps1 -BuildTier Assertions -SkipSmoke` | `build_native_eiffel.ps1 -BuildTier Assertions` |
| `ci/Jenkinsfile.all-tests`, *libexpat adapter* | `build_native_eiffel.ps1 -SkipSmoke` | `build_native_eiffel.ps1` |
| `ci/Jenkinsfile.windows-phase1` | `build_native_eiffel.ps1 -BuildTier Assertions -SkipSmoke` | `build_native_eiffel.ps1 -BuildTier Assertions` |
| `scripts/package_windows_release.ps1` | `-BuildTier Assertions -SkipSmoke` | `-BuildTier Assertions` |

Left on purpose: `-SkipSmoke` in `run_benchmarks.ps1`, `run_large_xml_benchmarks.ps1`,
`run_chunked_crc_harness.ps1` and `run_incremental_shim_audit.ps1`. They are
measurement and audit tools that build their own DLL. In CI they run with
`-SkipBuild` after the native stage, which now runs both smoke tests.

## Verification

Student PC: Windows 11, EiffelStudio 25.12.9.8922 Standard, MSVC 19.51,
`ISE_C_COMPILER=msc_vc140`, finalized builds, branch `fix/142-reenable-smoke`.

| # | Command | Expected | Actual | |
|---|---|---|---|---|
| 1 | the *Windows Native Tests* commands: `build_native_eiffel.ps1`, then `build_native_eiffel.ps1 -BuildTier Assertions` | both smokes ok, exit 0 | `xpact Eiffel DLL smoke: ok` twice, exit 0 ([log](ci-native-stage.txt)) | ✅ |
| 2 | `scripts\package_windows_release.ps1` | both builds with smoke, package written | both smokes ok, `Packaged ...\dist\xpact-0.1.0-preview-windows-x64.zip`, exit 0 ([log](package-release.txt)) | ✅ |
| 3 | Jenkins `all-tests` on the branch | *build Eiffel-backed DLLs* green | not run (supervisor's Jenkins) | ⬜ |

A first attempt at row 1 passed its commands to `powershell -Command` with broken
quoting, so no build ran, although it exited 0. That attempt was discarded, and row 1
was rerun from a script file.

## Revert

`.\student\tools\fix.ps1 revert -Issue 142 -Commit <merge sha>`
