# Report: issue #179: Expat's C tests used the bridge-only xpact library by default

> **Issue:** [#179](https://github.com/andersoxie/xpact/issues/179) A04-1 · found by A04 ([#168](https://github.com/andersoxie/xpact/issues/168), which DLL each runner loads)
> **Branch:** `fix/179-adapter-default-eiffel-library`, from `student-Mass` @ `f985102` · **Changed:** `scripts/run_libexpat_adapter.ps1`, `tests/python/test_libexpat_adapter.py` (new test), `adapters/libexpat/README.md`
> **Status:** ✅ fixed · ✅ verified locally · 🟡 waiting for review; Jenkins is not affected (it passes the library itself)

## 1. In short

`build\native\xpact.dll` is the **bridge-only** build: the C layer of the Expat API **without** the Eiffel parser, so every parse answers error 44, "Eiffel parser bridge is not installed". The Eiffel-backed library is `build\native-eiffel\xpact.dll`.

`run_libexpat_adapter.ps1 -Mode NativeSuite` picked the bridge-only build whenever it was not told otherwise:

| Command | Before | After |
|---|---|---|
| `-Mode NativeSuite` (as in `docs/phase-1.md`) | ❌ builds the **bridge-only** DLL, links it, every test fails with error 44 | ✅ builds the Eiffel DLL, links it: 399 checks, 38 expected failures, exit 0 |
| `-Mode NativeSuite -SkipNativeBuild` (no `-XpactLibrary`) | ❌ links `build\native\xpact.lib` when it exists | ✅ links `build\native-eiffel\xpact.lib`; 208 of 208 test processes load the Eiffel DLL |
| `-XpactLibrary build\native-eiffel\xpact.lib -SkipNativeBuild` (Jenkins) | ✅ | ✅ unchanged code path |
| no Eiffel library built yet | ❌ silently used the bridge (or `libxpact.so`, also bridge-only) | ✅ stops: "no xpact library: build … with scripts\build_native_eiffel.ps1, or pass -XpactLibrary …" |

## 2. Problem report (CLAUDE.md format)

| Field | |
|---|---|
| **1. Problem** | Expat's C tests run against the bridge-only xpact library unless `-XpactLibrary` is given |
| **2. Environment** | Windows 11 (student PC), `student-Mass` @ `f985102`, Visual Studio 18 Community (MSVC, bundled CMake), Expat 2.8.1 sources (`R_2_8_1`), PowerShell 5.1, Python 3.14.0 |
| **3. Command** | `.\scripts\run_libexpat_adapter.ps1 -Mode NativeSuite -ExpatSourceDir <expat-2.8.1>\expat -SkipNativeBuild` (or without `-SkipNativeBuild`) |
| **4. Expected** | the Eiffel-backed library, as Jenkins (`XPACT_LIBRARY = build\native-eiffel\xpact.lib`) |
| **5. Actual** | 288 test processes load `build\native\xpact.dll` [bridge-only, SHA-256 `f65b09225e2c1a0d…`] (A04, [loads](../../student/results/A04-loaded-library/runs/libexpat-adapter-default/loads.txt) on the A04 branch) |
| **6. Error output** | `FAIL [chunksize=0 deferral=0]: test_nul_byte` … `ERROR: 44: Eiffel parser bridge is not installed (line 1, offset 0)`; `Native libexpat suite failed unexpectedly: basic_tests.c/test_nul_byte` |
| **7. Investigation** | `Resolve-XpactLibrary` returned `build\native\xpact.lib` (else `build\native\libxpact.so`) when no library was given; `Invoke-NativeSuite` without `-SkipNativeBuild` ran `build_native.ps1 -Target Windows`, which builds exactly that bridge. Both files come from `native/xpact_native.c` alone |
| **8. Cause** | ✅ **confirmed**: the default library path and the default build step both pointed at the bridge-only build |
| **9. Fix** | see 3 |
| **10. Verification** | ✅ see 4 |

## 3. The change

`scripts/run_libexpat_adapter.ps1`:
1. `Resolve-XpactLibrary`: the default is `build\native-eiffel\xpact.lib`; the `build\native` fallbacks are gone. An explicitly passed library is used as before.
2. `Invoke-NativeSuite` without `-SkipNativeBuild`: builds with `build_native_eiffel.ps1` instead of `build_native.ps1 -Target Windows`.
3. The message when no library is found says how to build one.
4. The log names the library it uses: `libexpat native suite: xpact library <path>` (A04: every run should say which build it tested).

`tests/python/test_libexpat_adapter.py`: the CMake stand-in records its arguments; new test `test_default_library_is_the_eiffel_backed_build_never_the_bridge` runs the adapter without a library and checks that CMake is configured with `-DXPACT_LIBRARY=…\build\native-eiffel\xpact.lib`, never `…\build\native\xpact.lib`.

`adapters/libexpat/README.md`: a paragraph on the default.

## 4. Verification

| Check | Command | Result | Log |
|---|---|---|---|
| New test, **old** script | `python -m unittest tests.python.test_libexpat_adapter.NativeSuiteGateTests.test_default_library_is_the_eiffel_backed_build_never_the_bridge` with the script of `f985102` | ❌ fails as it should: `'-DXPACT_LIBRARY=…\build\native\xpact.lib' unexpectedly found` | [adapter-test-old-script.txt](logs/adapter-test-old-script.txt) |
| Adapter tests, fixed script | `python -m unittest tests.python.test_libexpat_adapter -v` | ✅ 7 / 7 | [adapter-tests-fixed.txt](logs/adapter-tests-fixed.txt) |
| The documented default command, real Expat suite | `run_libexpat_adapter.ps1 -Mode NativeSuite -ExpatSourceDir … -OutputDir build\fix179\default` (no other options; `XPACT_EXPAT_LIBRARY` unset) | ✅ exit 0, 375 s: built `build\native-eiffel\xpact.dll` (Production), used `build\native-eiffel\xpact.lib`, **Checks: 399, Failed: 38**, all 38 expected (allocator), as before | [default-command.txt](logs/default-command.txt) |
| Which DLL really loads | same with `-SkipNativeBuild`, under A04's `loadwatch.py` | ✅ 208 × `xpact_libexpat_runtests.exe` → `build\native-eiffel\xpact.dll` [`21b5ca2c…`]; bridge-only `f65b0922…`: **0** (before: 288) | [watched-loads.txt](logs/watched-loads.txt), [watched-command.txt](logs/watched-command.txt) |
| Regression: whole Python suite | `python -m unittest discover -s tests/python -p "test_*.py"` | ✅ 207 tests OK (206 before + the new one) | [python-suite.txt](logs/python-suite.txt) |

Under the watcher the suite itself ends with exit 1: 4 heavy tests time out (`test_deep_nested_entity`, …) because the debugger slows them down. This is the same as in A04 before the fix, and the run without the watcher (row 3) has no timeouts. The watched run is used only for the library check.

## 5. Problems met (kept separate)

- The first version of the new test only looked at the new log line, so on the old script it failed for the wrong reason (the line did not exist). It now checks the argument CMake actually receives, and fails on the old script at the bug itself.

## 6. Limitations

- The "no Eiffel library built" branch (error message) is not exercised on this PC, because `build\native-eiffel\xpact.lib` exists. The test covers it with an `else` branch that runs only on a machine without the build.
- Unix: the old fallback `build\native\libxpact.so` is gone. That file is also bridge-only (`gcc … native/xpact_native.c`), so it could not pass either. On Unix the library must be passed explicitly, as the README already said.
- Jenkins was not run. Its command passes `-XpactLibrary` and `-SkipNativeBuild`, a code path this change does not touch.

## 7. Revert

`student\tools\fix.ps1 revert -Issue 179 -Commit <sha>`, or `git revert <sha>`.
