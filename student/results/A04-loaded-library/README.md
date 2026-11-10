# A04: which library do the tests really load?

Task: [A04](../../github/issues/16-A04.md) · Issue [#168](https://github.com/andersoxie/xpact/issues/168) · Done 2026-10-31

## ✅ In one sentence
Every runner loads the library it should, **except one**: `run_libexpat_adapter.ps1` run without `-XpactLibrary` links the bridge-only DLL ([#179](https://github.com/andersoxie/xpact/issues/179)). Jenkins passes the option, so Jenkins is not affected.

| | |
|---|---|
| Runners checked | **16** (builds, C#, C, Expat's C tests, benchmarks, examples, package, Python, Eiffel, student tools) |
| ✅ Loaded the expected library | **15** |
| ❌ Wrong library | **1**: Expat's C tests without `-XpactLibrary` → bridge-only, error 44 ([#179](https://github.com/andersoxie/xpact/issues/179)) |
| Unknown or stale DLL anywhere | **0**: every loaded `xpact.dll` / `xpact_assertions.dll` matched a build by SHA-256 |
| Found on the way | `run_benchmarks.ps1 -Repetitions 1` fails ([#180](https://github.com/andersoxie/xpact/issues/180)); runners that rebuild the DLL (O2) |

## How it was checked
Each runner was started under [`loadwatch.py`](loadwatch.py), a small debugger (Windows debug API, no admin rights) that records **every process** the runner starts and **every DLL** each process loads, by full path. Each loaded `xpact.dll`, `xpact_assertions.dll` or `libexpat*.dll` was hashed (SHA-256) and matched against the four known builds, hashed right after that runner:

| Name | File | Meaning |
|---|---|---|
| 🟢 normal | `build\native-eiffel\xpact.dll` | Eiffel parser, assertions off |
| 🟢 assertions | `build\native-eiffel\xpact_assertions.dll` | Eiffel parser, assertions on |
| 🟠 bridge-only | `build\native\xpact.dll` | C bridge **without** the Eiffel parser: every parse returns error 44 |
| 🔵 expat-2.8.1 | `xpactGit\build\libexpat-R_2_8_1\build\libexpat.dll` | the reference |

The path alone is not enough: `XML_ExpatVersion` returns `expat_2.8.1` for xpact too, and every rebuild of the same source gives a new hash.

## Results: configuration → expected → observed

| # | Runner | Configuration | Expected | Observed | |
|---|---|---|---|---|---|
| 1 | DLL build + C smoke test | `build_native_eiffel.ps1 -BuildTier Production` | normal | normal | ✅ |
| 2 | DLL build + C smoke test | `-BuildTier Assertions` | assertions | assertions | ✅ |
| 3 | C# P/Invoke tests (`XpactDllTests.exe`) | `--dll build\native-eiffel\xpact.dll` | normal | normal (0 failures) | ✅ |
| 4 | C# P/Invoke tests | no `--dll` (default) | assertions | assertions (0 failures) | ✅ |
| 5 | Native ABI smoke tests | `run_native_abi_tests.ps1 -Target Windows` | bridge-only (by design) | bridge-only | ✅ |
| 6 | Chunked CRC harness | `-Target Xpact -Repeat 1` | normal | normal (rebuilt it, O2) | ✅ |
| 7 | Incremental shim audit | default | normal | normal (rebuilt it, O2) | ✅ |
| 8 | Expat's C tests against xpact | `-XpactLibrary build\native-eiffel\xpact.lib`, **as Jenkins** | normal | normal | ✅ |
| 9 | Expat's C tests against xpact | **no** `-XpactLibrary` (default) | normal | **bridge-only** | ❌ [#179](https://github.com/andersoxie/xpact/issues/179) |
| 10 | Jenkins Benchmarks stage | `run_benchmarks.ps1 -W3cAllCases`, both builds, 1 iteration, 2 repetitions | normal + assertions | normal + assertions (copies, same hash, O3) | ✅ |
| 11 | Large XML benchmarks | one small file, `-SkipBuild -SkipWslC` | normal | normal | ✅ |
| 12 | Contributed examples | default | no DLL (Eiffel only) | none | ✅ |
| 13 | Windows release package | `-SkipBuild` | no DLL loaded; packaged DLLs = the builds | none; `dist\…\bin\xpact.dll` = `875b5664…`, `xpact_assertions.dll` = `c255a20b…`, the same files | ✅ |
| 14 | Python test suite (206 tests) | `unittest discover tests/python` | any known build | none (Python uses its own `pyexpat`) | ✅ |
| 15 | Eiffel test matrix | all modes, assertions off and on | no DLL (Eiffel only) | none | ✅ |
| 16 | Student test 1 (W3C output) | default `--dll` | normal | normal (399/432, as before) | ✅ |

Per runner: which process loaded which file, how often, with the hash, in [`runs/<id>/loads.txt`](runs/); the console in `runs/<id>/console.txt`; all in [`results.tsv`](results.tsv) and [`results.json`](results.json).

<details>
<summary>❌ Finding A04-1 (#179): Expat's C tests without <code>-XpactLibrary</code> use the bridge-only DLL</summary>

| Field | |
|---|---|
| **Problem** | `run_libexpat_adapter.ps1 -Mode NativeSuite` without `-XpactLibrary` and without `XPACT_EXPAT_LIBRARY` links `build\native\xpact.lib`, the bridge-only build |
| **Environment** | Windows 11, `fix/168-a04-loaded-library` @ `f985102` (= `student-Mass`), VS 18 Community, Expat 2.8.1 sources |
| **Command** | `.\scripts\run_libexpat_adapter.ps1 -Mode NativeSuite -ExpatSourceDir <expat-2.8.1>\expat -OutputDir build\a04\adapter-default -SkipNativeBuild` (after `run_native_abi_tests.ps1`) |
| **Expected** | the Eiffel-backed library, as Jenkins (`XPACT_LIBRARY = build\native-eiffel\xpact.lib`) |
| **Actual** | 288 test processes load `build\native\xpact.dll` [bridge-only, `f65b09225e2c1a0d`] ([loads](runs/libexpat-adapter-default/loads.txt)) |
| **Error output** | `FAIL: test_nul_byte` … `ERROR: 44: Eiffel parser bridge is not installed (line 1, offset 0)`; `Native libexpat suite failed unexpectedly: basic_tests.c/test_nul_byte` |
| **Investigation** | Same command with `-XpactLibrary build\native-eiffel\xpact.lib` loads `normal`. `Resolve-XpactLibrary` falls back to `build\native\xpact.lib` when no library is given |
| **Cause** | ✅ confirmed: the fallback path in `Resolve-XpactLibrary` |
| **Fix** | none yet |
| **Verification** | not yet |
</details>

<details>
<summary>🟡 Finding A04-2 (#180): <code>run_benchmarks.ps1 -Repetitions 1</code> fails</summary>

With one repetition `Invoke-TimedCommand` returns a single row instead of a list, and `$AllRows.AddRange(...)` throws `Cannot convert argument "collection" … PSCustomObject … IEnumerable`. With `-Repetitions 2` the same command runs (row 10). Jenkins uses the default, 3: not affected. Cause ✅ confirmed (error type, and 2 works). Fix: none yet.
</details>

<details>
<summary>👀 Observations (no wrong library, but worth knowing)</summary>

**O1. The earlier fix checks (#154-#165) used more than one copy of the DLL, and the reports did not record hashes.**
Those checks built the assertions DLL into a second folder, `build\native-eiffel-assertions\` (`aabd160a…`), and the W3C checker used its own copy `build\w3c-dll\xpact.dll` (`83878fbb…`), while the repo runners use `build\native-eiffel\`. All four copies passed the #165 chunk probe 3/3, so the #165 verification did test fixed code. **From now on: every report records the DLL path and SHA-256.**

**O2. Some runners rebuild `build\native-eiffel\xpact.dll` themselves.**
The normal DLL had three hashes during this run: `23854731…` (built by row 1), `fedfb077…` (rebuilt by the CRC harness, row 6), `875b5664…` (rebuilt by the shim audit, row 7). Same source, so the same code, but a run that comes after them tests a different file than the one before. The hash, not the time, says which build a result belongs to.

**O3. The Benchmarks stage tests copies of the DLL.**
`run_benchmarks.ps1` copies both DLLs to `<OutputDir>\w3c-dll\Finalized\` and `…\FinalizedAssertions\`; the copies had the same hash as the builds. Most of its W3C work runs in the Eiffel program `xpact_benchmarks.exe` (1,022 processes); 45 `xpact_w3c_case.exe` processes load the DLL. W3C result: 2,585 / 2,585 for both builds, 0 failed, 0 errors.

**O4. Python and the Eiffel lanes do not use the DLL at all.**
The 206 Python tests, the Eiffel test matrix and the contributed examples load no xpact DLL; where Python parses XML it is CPython's own `pyexpat.pyd` (Expat 2.7.3). Their results say nothing about the DLL.
</details>

<details>
<summary>🔧 Problems with the check itself (fixed, not xpact)</summary>

| Problem | Cause | What was done |
|---|---|---|
| C# runs showed an "unknown" library | ✅ my filter `xpact*.dll` matched the C# program's own managed `XpactDllTests.dll` | filter now only `xpact.dll`, `xpact_assertions.dll`, `libexpat*.dll`; re-scored from the saved data ([`rescore.py`](rescore.py)) |
| Rows 8 and 9 stopped: `cmake is not on PATH` | ✅ my PATH pointed at `C:\Program Files\CMake`; here CMake is the one inside Visual Studio | PATH fixed, both rerun |
| Row 10 stopped: `-EiffelBuild "Finalized,FinalizedAssertions"` rejected | ✅ `powershell -File` passes the list as one string | dropped (both builds are the default), rerun |
| Row 8: 4 Expat tests timed out (120 s), CTest gave up at 600 s | ✅ the debugger slows the tests: the same command **without** the watcher finished in 245 s with the known result, 399 checks, 38 expected (allocator) failures ([log](runs/libexpat-adapter-jenkins/console-no-watcher.txt)) | library check unaffected; the suite result is taken from the run without the watcher |
| Most rows took ~15 min | ✅ `vctip.exe` (Visual Studio telemetry, started with `cl`/`link`) stays ~15 min and the watcher waits for every process | `VSCMD_SKIP_SENDTELEMETRY=1` for later runs; the "seconds" column of the first run includes it |
</details>

<details>
<summary>⚠️ Limitations: what this does not prove</summary>

- Hashes are taken **after** each runner. A runner that loads a DLL and then overwrites it would show the new hash. O2 shows that runners do rebuild; that no runner rebuilt the DLL *after* loading it is likely from the order of its steps, but not proven.
- **No workbench DLL** exists: `build_native_eiffel.ps1` only has `Production` and `Assertions`. Workbench is covered by the Eiffel matrix, which uses no DLL.
- **Not run:** WSL/Linux runners (`-SkipWslC`), the dual-implementation lane (needs the `Xpact-core` checkout), Jenkins itself.
- Benchmarks with 1 iteration: the library check only, not a speed measurement.
- One machine, one revision (`f985102`).
</details>

<details>
<summary>▶️ Reproduce</summary>

```powershell
dotnet build tests/dotnet/XpactDllTests -c Release
python -I student\results\A04-loaded-library\run_a04.py            # all 16, ~2-4 h under the watcher
python -I student\results\A04-loaded-library\run_a04.py --only libexpat-adapter-default
python -I student\results\A04-loaded-library\rescore.py            # re-score from build\a04\*\watch.json
```
Raw data (not in git): `build\a04\<id>\watch.json` (every process and DLL) and `console.txt`.
</details>
