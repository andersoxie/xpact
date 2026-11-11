# #308 Benchmark scripts pick the Windows Store python stub

| | |
|---|---|
| Branch | `fix/308-python-stub` from `incremental-test` @ `716d8ab` |
| Environment | Student PC, Windows 11 Home; `python` on PATH = `...\WindowsApps\python.exe` (Store alias); real Python = uv CPython 3.15 |

## Problem and cause
`run_benchmarks.ps1` and `run_large_xml_benchmarks.ps1` used `(Get-Command python).Source`, which returns the Store alias. The run failed only after the Eiffel builds, with "Python was not found ...". ✅ Confirmed.

## Fix
New `scripts/resolve_python.ps1` (`Resolve-XpactPython`), called at the start of both scripts: `$env:XPACT_PYTHON` if set, else `python` from PATH; stops at once with a clear message for the Store alias, a missing path, or an interpreter that does not run. README explains it.

## Verification
| Case | Result |
|---|---|
| Store alias on PATH, no override | ✅ clear message, stops in < 1 s (was: fails after the builds) |
| `XPACT_PYTHON` = missing file | ✅ "XPACT_PYTHON points to ..., which does not exist" |
| `XPACT_PYTHON` = uv python | ✅ resolved |
| uv python first on PATH, no override | ✅ resolved |
| Full `run_benchmarks.ps1 -W3cAllCases -UseExistingNativeDll -NoDocsUpdate` with `XPACT_PYTHON` | ✅ rc 0; W3C 2,283 passed / 0 failed both builds; DLL unchanged ([log](regression.txt)) |
| Python suite | ✅ 239/239 OK |
