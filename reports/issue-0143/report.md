# Report: issue #143, 7 native Python tests skip because Visual Studio's CMake is not found

Issue: [#143](https://github.com/andersoxie/xpact/issues/143)   Branch: `fix/143-vs-cmake`   Base: `student-Mass` @ `3daef15`   Date: 2026-10-27

## In short

| | |
|---|---|
| ✅ Cause | the CMake lookup checked only `PATH` and `%ProgramFiles%\CMake`; Visual Studio installs CMake in its own folder |
| ✅ Fix | also ask `vswhere` for the CMake bundled with the Visual Studio that has the C++ tools |
| ✅ Result | Python suite: **178 run, 0 skipped, OK** (before: 7 skipped) |

## Cause (confirmed)

`test_libexpat_isolation.py` and `test_libexpat_test_defaults.py` skip their native
classes when `CMAKE` is `None`. On the student PC there is no stand-alone CMake.
Visual Studio 18 has one at
`Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe`, which neither
lookup covered. With that folder put on `PATH` by hand, the libexpat tests ran
(13, OK, 0 skipped). That confirmed the missing lookup was the only reason for the skips.

## Change

Both files: after the existing two lookups, on Windows, run
`vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find .../cmake.exe`
and use the first result. If none is found, the tests still skip as before. The
lookup uses the same `vswhere` and the same C++ tools component as the tests' `setUpClass`.

## Verification

Student PC: Windows 11, Visual Studio 18 Community (MSVC 19.51), no `cmake` on
`PATH`, Python 3.14.0.

| # | Command | Expected | Actual | |
|---|---|---|---|---|
| 1 | before: `python -m unittest discover -s tests/python -p "test_*.py" -v` | 7 skipped | `Ran 178 tests`, `OK (skipped=7)` ([log](python-all-before.txt)) | ✅ reproduced |
| 2 | after: the same command | 178 run, 0 skipped | `Ran 178 tests`, `OK`; all 7 native tests `ok` ([log](python-all-after.txt)) | ✅ |

The 7 tests that now run:
`NativeIsolationTests` (6: registration, failure aggregation, setup/teardown phase,
crash and timeout markers, cancelled coordinator, callback assertion) and
`NativeTestDefaultTests.test_factory_and_reset_defaults_match_each_test_configuration`.

Not checked: whether Jenkins skipped these tests too (that depends on its CMake).
The *libexpat adapter* stage runs `test_libexpat_*.py` and will use the same lookup.

## Revert

`.\student\tools\fix.ps1 revert -Issue 143 -Commit <merge sha>`
