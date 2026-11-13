# #302 run_benchmarks.ps1 rebuilds the tested DLLs and rewrites docs/benchmarks.md

| | |
|---|---|
| Branch | `fix/302-benchmarks-keep-dll` from `incremental-test` @ `2935a8a` |
| Environment | Student PC, Windows 11 Home, EiffelStudio 25.12, uv CPython 3.15 first on PATH |
| Command | `run_benchmarks.ps1 -EiffelBuild Finalized,FinalizedAssertions -W3cAllCases -SkipWslC -UseExistingNativeDll -NoDocsUpdate -W3cSuiteDirectory <xmlconf>` |

## Problem
Without these switches the script calls `build_native_eiffel.ps1` (W3C checker, native C benchmark) and replaces `build\native-eiffel\*.dll`; it also rewrites `docs/benchmarks.md`. Seen twice (#273, #274): DLL `3AB5C4E8…` became `34FA35DD…` (same source, other binary). Cause ✅ confirmed (script lines).

## Fix
- `-UseExistingNativeDll`: no DLL rebuild (Eiffel benchmark programs are still built); prints the SHA-256 of the DLLs it uses; the existing "DLL not found" checks stop the run if one is missing.
- `-NoDocsUpdate`: the page goes to `build\benchmarks\benchmarks.md` only. Without it, a copy is written there as well.
- Defaults unchanged (the Jenkinsfiles and docs rely on them). README and `docs/w3c-xml-conformance.md` explain the switches and list the 5 other scripts that rebuild the DLL by default.

## Verification ([log](verification.txt))
| Check | Result |
|---|---|
| DLL SHA-256 before / after | `ADAE03D2…` `75F43A5B…` / the same ✅ |
| `docs/benchmarks.md` before / after | `74E10125…` / the same ✅ |
| W3C 2,585 cases, both builds | 2,283 passed, 0 failed (baseline) ✅ |

## Limitation
The other 5 scripts still rebuild by default (each has a skip switch); documented, not changed.
