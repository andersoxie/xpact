# Dual implementations in Jenkins and plots

Both main Jenkins pipelines now include **Dual Implementation Benchmarks** when
`RUN_BENCHMARKS` is enabled (the default):

- [Windows Phase 1](../ci/Jenkinsfile.windows-phase1)
- [All tests](../ci/Jenkinsfile.all-tests)

The stage runs the [100-item catalog](dual-catalog-lane.md) and the
[W3C conformance profile](dual-w3c-lane.md) with both our parser and pinned
Finnian Xpact-core. The primary executables are Eiffel finalized with assertions
discarded. Assertion-enabled builds run the directed controls for each lane.
Existing benchmark tiers and plots continue separately.

## Execution and failure behavior

The stage runs before the existing Benchmarks stage. The catalog and W3C campaigns
are independent: one infrastructure failure does not hide the other's results.
Only our `xpact` results enter Jenkins' Test Result summary and decide the test
pass/fail status. Xpact-core still runs and supplies the comparison plots and
detailed artifacts. Its wrong verdicts, timeouts and directed-control failures
remain recorded there without making our test summary or build fail. Missing
own validation or infrastructure/publication failures still fail the stage.
Later stages can continue, preserving the other benchmark reports.

Each invocation owns a fresh `build/dual-ci-<build-number>-<invocation>/`
directory. Its `run.json` records the Jenkins build identity, campaign state and
each lane's status. Publication checks that identity before using the results.
`subject_summary` records our separate Jenkins status. Jenkins ingests only
`xpact-junit.xml`, containing our W3C cases and directed controls from both lanes;
`xpact-summary.json` contains the matching totals. The combined W3C JUnit XML is
archived for comparison and is never ingested into Jenkins' aggregate results.
Only completed lane reports supply numeric plot values; an incomplete lane
contributes an explicit error and no numeric series. A report-persistence
failure removes the current plot publication while retaining child diagnostics.
Older run directories are never selected as the current build's results.

The all-tests stage performs a real SCM checkout because the isolated build
manifests require Git provenance. It archives the stage's output before later
stages clear the workspace. Both pipelines archive JSON/TSV/CSV/HTML reports,
JUnit XML, compiler/qualification logs and original case stdout/stderr.
HTML publication copies only the small plot/report files; generated Eiffel
projects, executables and the downloaded suite are excluded from publication.

## Plots

The existing Jenkins Plot publisher receives two series, `xpact` and
`pinned Xpact-core`, in these groups:

| Group | Plot | Interpretation |
|---|---|---|
| Dual catalog | Median ms per 1,000 documents | Normalized time; lower is faster |
| Dual catalog | Median MiB/s | End-to-end throughput; higher is faster |
| Dual W3C conformance | Passed cases | Correct binary verdicts |
| Dual W3C conformance | Wrong verdicts | Unexpected acceptance or rejection |
| Dual W3C conformance | Process errors and timeouts | No valid verdict |
| Dual W3C conformance | Profile exclusions | Explicit skips, never passes |

Catalog calibration can change the iteration count, so raw sample elapsed time
is not used as a trend metric. Both catalog engines retain their own internal
GC behavior; core's internal GC suspension/full collection remains timed.

W3C plots show correctness counts. A parser's fast incorrect verdict is not a
throughput improvement. Per-case elapsed times remain in the detailed reports
and include process startup and file I/O.

The build also publishes **Dual Implementation Plots**, a standalone HTML report
with current comparisons, directed-control outcomes, failures and source/binary
identities. Stable plot identifiers allow Jenkins to retain trends across builds.
The report is linked from the build description and archived as
`dual-implementation-plots.html`; raw Plot inputs are listed in `plots.tsv`.

## Parameters and local reproduction

`W3C_SUITE_DIRECTORY` supplies the same extracted suite to the existing and dual
W3C runners. Keep it outside workspaces that the all-tests job clears.
`DUAL_IMPLEMENTATION_OFFLINE` requires the pinned dependency and archive to be
cached, or a supplied suite directory for W3C. The all-tests job starts with a
fresh checkout, so leave offline mode disabled unless its dependency cache has
been provisioned there. This option does not change the existing benchmark
runner's download behavior.

Run the shared stage command locally with a new output directory and an explicit
owner label:

```powershell
.\scripts\run_dual_jenkins.ps1 `
  -OutputDirectory build\dual-ci-local-review `
  -BuildId local-review `
  -Offline
```

The default catalog calibration, six pairs, two warmups and ten-second W3C
timeout match the focused lanes. The wrapper also accepts `-SuiteDirectory`,
`-TimeoutSeconds`, `-Iterations`, `-Pairs`, `-Warmups`, `-MinSampleSeconds` and
`-SampleTimeoutSeconds`. An existing output directory is rejected.

The Python runner returns 0 when our tests are green, 1 for our test failures,
and 2 for missing own validation or infrastructure/publication failure. The raw
comparison status can remain `complete_with_failures` while our Jenkins summary
is `complete`. The PowerShell wrapper throws on either nonzero result after
preserving the reports. The standalone dual catalog/W3C Jenkins definitions use
the same own-only summary policy.

Runner checks:

```powershell
python -m unittest discover -s tests/python -p test_dual_jenkins.py -v
python -m unittest discover -s tests/python -p test_dual_jenkins_reports.py -v
python -m unittest discover -s tests/python -p test_jenkins_xpact_summary.py -v
```

## Initial integration verification, 25 October 2026

The shared command completed with fresh builds and the cached pinned archive:

```powershell
.\scripts\run_dual_jenkins.ps1 `
  -OutputDirectory build/dual-ci-local-20261025T162000Z `
  -BuildId local-20261025-integration `
  -Offline
```

Both catalog implementations passed all directed controls in both assertion
configurations. Calibration selected 32,000 documents per sample and retained
six alternating measurement pairs. All 5,170 W3C engine/case records were retained.
The six plot CSVs and six inline SVGs contained these values:

| Metric | xpact | Pinned Xpact-core |
|---|---:|---:|
| Catalog median ms / 1,000 documents | 140.109 | 59.556 |
| Catalog median MiB/s | 17.772 | 41.810 |
| W3C passed | 1,727 | 1,051 |
| W3C wrong verdicts | 0 | 662 |
| W3C errors (all ten-second timeouts) | 0 | 14 |
| W3C excluded | 858 | 858 |

Before the own-only summary policy was applied, the campaign returned
`complete_with_failures` / Python exit 1 because the core W3C results were red.
The combined comparison JUnit contains 662 failures, 14 errors and 1,716 skips.
It remains archived comparison evidence. All eight
executable hashes and source fingerprints matched after execution. Re-exporting
with the final publisher reproduced every plot file byte for byte.

The 125 affected Python tests passed. Both pipelines parsed with the installed
Groovy 2.4.21, and the wrapper plus 48 embedded PowerShell blocks passed syntax
parsing. Sixteen publisher scenarios used the actual Windows PowerShell 5 owner
and readiness scripts with simulated Jenkins publishing steps: current red
results, wrong owner, invalid/missing paths, publication failures and restored
retry. HTML and archive filters were checked in those scenarios. Two existing
Sonar PowerShell strings in the all-tests pipeline also needed Groovy escaping
before that file would parse.

The [portable integration evidence](../benchmarks/results/dual-jenkins-2026-10-25.json)
records the plot values/hashes, raw catalog pairs, W3C totals and source/binary
identities. Full reports and the local HTML preview remain under the output
directory above. This verifies the shared command and publishing logic locally;
neither Jenkins controller job has been triggered for this integration.

## Own-only Jenkins summary verification

The previously executed, authenticated child reports were republished using the
own-only policy. No parser binaries were rerun for this reporting change. The
new summary contains only our implementation:

| Own summary | Count |
|---|---:|
| W3C catalog rows | 2,585 |
| Directed controls, both lanes and assertion modes | 20 |
| Passed | 1,747 |
| Skipped | 858 |
| Failures / errors | 0 / 0 |

The shared command's test gate returned **0**, while its separate comparison
status remained `complete_with_failures`. The raw combined JUnit and child
reports retained their original hashes, and all six plot CSV values remained
unchanged. Missing own cases, failed own controls, contradictory counts and
foreign or nested reference testcases are rejected rather than counted green.

The 41 affected Python tests passed. Publishing was checked in 22 simulated
Jenkins scenarios using the actual Windows PowerShell 5 readiness scripts, and
eight standalone-job gating scenarios. A further Windows PowerShell 5 check
injected a reference-only catalog control failure and confirmed exit 0 with our
complete verified results. Handled comparison diagnostics use stdout so native
stderr cannot prematurely override that gate in PowerShell 5. All four Jenkins
definitions parsed with Groovy 2.4.21; their 52 PowerShell blocks parsed too.

The [own-only summary evidence](../benchmarks/results/jenkins-xpact-summary-2026-10-25.json)
records the subject totals and retained comparison hashes. The local report is
under `build/dual-ci-own-summary-20261025T170000Z-retry-1/`. An earlier attempt
hit Windows `PermissionError [WinError 5]` while atomically replacing `run.json`;
that failed directory was preserved and the fresh retry passed. The cause of
that transient storage failure is unconfirmed; no retry workaround was added.
Jenkins controller execution remains unverified.
