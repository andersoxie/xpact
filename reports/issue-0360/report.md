# #360 · Pin the native DLL search path (CA5392)

| | |
|---|---|
| Status | ✅ **hardening done and verified** (2026-11-13) |
| Issue | [#360](https://github.com/andersoxie/xpact/issues/360) · found by the [security scan 2026-11-13](../security-scan-2026-11-13/README.md) |

- **Environment:** student PC, Windows 11 Home · `incremental-test` @ `d97fb95`
- **Command:** `dotnet build -c Release -p:AnalysisLevel=latest-all --no-incremental` in `website/backend`
- **Before:** 70 × CA5392 (P/Invokes without `DefaultDllImportSearchPaths`). **After:** 0.
- **Investigation / cause:** ✅ not exploitable before either: `xpact.dll` is loaded by full path (`NativeLibrary.SetDllImportResolver`), `kernel32`/`advapi32` are KnownDLLs. Hardening only, so a future import cannot pick a DLL from the working folder.
- **Fix:** `[assembly: DefaultDllImportSearchPaths(DllImportSearchPath.System32)]` in `Xpact.Api` and `Xpact.Worker` (`NativeSearchPath.cs`).
- **Verification:** analyzers 70 → 0 CA5392; `website\scripts\test.ps1` ✅ 48 / 48 (the worker still loads `xpact.dll` and parses).
