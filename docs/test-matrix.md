# Test Matrix

xpact keeps two Eiffel regression lanes side by side:

| Lane | ECF target | Eiffel assertions | Purpose |
|---|---|---|---|
| Assertions off | `xpact_tests` | Disabled | Release and benchmark behavior. |
| Assertions on | `xpact_tests_assertions` | Enabled | Design by Contract audit. |

Both lanes compile the same void-safe source and run the same `XP_TEST_ROOT`
test program. The custom test assertions in `XP_TEST_ROOT.assert` run in both
lanes; the difference is whether Eiffel runtime contract checks are also active.

Each lane is run in both workbench and finalized modes:

```powershell
.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode All -BuildMode All
```

Targeted runs are also supported:

```powershell
.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode Off -BuildMode Finalized
.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode On -BuildMode Workbench
```

The Jenkins all-tests pipeline, `ci/Jenkinsfile.all-tests`, runs this matrix as
four independent cells:

- assertions off / workbench;
- assertions off / finalized;
- assertions on / workbench;
- assertions on / finalized.

The assertions-on / finalized cell is also the executable shape used for the
optimized assertion tier: native packaging builds it as `xpact_assertions.dll`
so users can run contract-audited validation without falling back to workbench
debug builds.

The rest of the pipeline builds the Windows Eiffel-backed DLL, runs native
runtime smoke tests in both assertion modes, runs ABI smoke tests, runs the
chunked CRC corpus gate for direct and parse-buffer input, expands the libexpat
adapter manifest, optionally runs the upstream libexpat native suite, and
optionally publishes benchmarks for the production-finalized and
assertion-finalized benchmark builds.

## Why Both Assertion Modes

The article argues for making contracts visible and useful. The assertion-on
lane proves those contracts are executable and still consistent with the test
suite. The assertion-off lane proves the parser behavior does not depend on
runtime contract checking and matches the way finalized release and benchmark
builds execute.
