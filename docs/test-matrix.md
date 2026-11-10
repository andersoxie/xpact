# Test Matrix

For the case-by-case inventory used to prepare dual xpact/Xpact-core execution,
see [Dual-implementation coverage inventory](implementation-coverage.md).

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
chunked CRC corpus gate for direct and parse-buffer input, runs the
incremental shim audit, runs SonarQube analysis using the Jenkins tool named
`Sonar` and `sonar.projectKey=xpact`, expands the libexpat adapter manifest,
optionally runs the upstream libexpat native suite, and optionally publishes
benchmarks for the production-finalized and assertion-finalized benchmark builds.

Both Jenkins pipelines include the W3C XML conformance suite when
`RUN_BENCHMARKS` is enabled (the default). The benchmark command runs the suite
against the selected Eiffel builds, including both finalized assertion modes
in Jenkins, and fails on unexpected parser results. Runner unit tests execute
before the benchmarks. Unsupported catalog configurations are reported as
skipped cases rather than passes.

The same parameter also enables [both implementations in the focused catalog
and W3C lanes](dual-implementation-jenkins.md). A separate stage publishes the
paired catalog performance plots and W3C outcome plots before the existing
benchmark tiers. Core failures remain in those comparisons; only our tests enter
the Jenkins Test Result summary and decide its test pass/fail status.

By default the runner downloads the pinned W3C archive and verifies its SHA-256
checksum. Set the Jenkins `W3C_SUITE_DIRECTORY` parameter to an existing suite
directory for offline agents; this directory must be outside workspaces that
the all-tests pipeline clears before each stage. Both pipelines publish the
per-case JUnit report even when conformance fails, and archive the detailed
results and summaries under `build/benchmarks/w3c-xml-conformance/`.

## Why Both Assertion Modes

The article argues for making contracts visible and useful. The assertion-on
lane proves those contracts are executable and still consistent with the test
suite. The assertion-off lane proves the parser behavior does not depend on
runtime contract checking and matches the way finalized release and benchmark
builds execute.
