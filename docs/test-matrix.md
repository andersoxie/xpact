# Test Matrix

For the case-by-case inventory used to prepare dual xpact/Xpact-core execution,
see [Dual-implementation coverage inventory](implementation-coverage.md).

The Windows EiffelStudio regression matrix keeps two lanes side by side:

| Lane | ECF target | Eiffel assertions | Purpose |
|---|---|---|---|
| Assertions off | `xpact_tests` | Disabled | Release and benchmark behavior. |
| Assertions on | `xpact_tests_assertions` | Enabled | Design by Contract audit. |

Both lanes compile the same void-safe source and run the same `XP_TEST_ROOT`
test program. The custom test assertions in `XP_TEST_ROOT.assert` run in both
lanes; the difference is whether Eiffel runtime contract checks are also active.
The ECF enables void safety and uses EiffelStudio's safe Base precompile.
Finalized runs use `-finalize -keep` so the target's requested assertions survive
finalization.

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

The optimized assertion tier uses the same finalized/assertions-on mode with
the separate native-library ECF target, producing `xpact_assertions.dll`
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

## Linux Compiler Qualification

The separate `RUN_WSL_EIFFEL_BENCHMARKS` stage defaults to both EiffelStudio and
Gobo, with finalized assertions requested or discarded. It builds the same
parser and harness sources, but it is not the complete `XP_TEST_ROOT` regression
matrix. Setup, toolchain versions and normal-GC comparisons are recorded in
[the WSL benchmark guide](wsl-benchmarks.md).

The 13 November 2026 bounded assertion probes passed all 21 cases per compiler
on Linux for EiffelStudio 25.02 and Gobo `26.11.12+ca6541c`; Gobo also passed its
21 cases on Windows. Separate library-scope and GC-state probes passed for Gobo
on both platforms. A further Linux probe still differs for an empty routine's
literal `ensure False` with assertions off. See
[the qualification and its limits](gobo-assertions.md); requested assertion flags
alone do not prove equivalent enforcement across compilers.

## Why Both Assertion Modes

The article argues for making contracts visible and useful. The assertion-on
lane checks that the enabled contracts remain consistent with the covered test
scenarios. The assertion-off lane checks those same scenarios without ordinary
runtime contract monitoring, as used by finalized release and benchmark builds.
Neither lane alone establishes correctness for every input or compiler.
