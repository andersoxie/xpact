# First dual-implementation lane

This lane runs the existing **catalog-100-items** workload with our parser and
the pinned Finnian Xpact-core implementation. It targets the configuration
previously labelled **xpact Eiffel finalized, assertions discarded**:

- Windows x64 / EiffelStudio / MSVC.
- Finalized executables with Eiffel contracts discarded, including suppliers.
- The same 2,611 ASCII/UTF-8 bytes: one catalog and 100 items, IDs 1 through 100,
  with text `value` in each item.
- One parser reused between whole documents; no-op handlers during timing.
- No additional caller-requested GC suspension.

## Run this lane

Use the prerequisites in [Pinned implementation builds](implementation-builds.md).
From the repository root:

```powershell
.\scripts\run_dual_catalog.ps1
```

The initial count is 1,000 documents. Calibration doubles the common count until
both samples last at least one second. Both implementations then get two
untimed warmups and six sequential measurement pairs in alternating AB/BA order.
Each benchmark process has a 120-second timeout. Counts, minimum sample duration,
warmups, pairs and timeout can be selected explicitly:

```powershell
.\scripts\run_dual_catalog.ps1 -Offline -Iterations 1000 -Pairs 6 -Warmups 2 -MinSampleSeconds 1
```

`-Offline` requires an existing verified pinned checkout. Each invocation creates
a new `build/dual-catalog/<run-id>/`, prints its path, and preserves older runs.
The command builds, qualifies and measures only this lane; no other workloads
are selected by the paired driver's broader defaults.

## Qualify before measuring

The lane builds separate assertion-enabled audit and assertion-discarded
benchmark executables for **each implementation**. Each of the four binaries
must report these five cases explicitly as PASS, independent of Eiffel contracts:

| Case | Required observation |
|---|---|
| `catalog_observed` | Exact independently specified event trace: catalog/item order, ID attributes and `value` text; only adjacent text callbacks are coalesced |
| `catalog_noop` | The identical catalog succeeds through the actual timed no-op handler path |
| `observed_reuse_recovery` | Reuse the parser for catalog → same catalog again → mismatched XML → catalog → mismatched XML; consecutive reuse and recovery have clean diagnostics and expected events |
| `noop_reuse_recovery` | The same sequence through the timed handler path has correct verdicts and error reset |
| `gc_restoration` | Incoming GC on/off state is restored after valid, mismatched and empty final documents |

Adapters release their parser/input references on close and clear observations.
These checks establish those reference/state transitions; they are not an
allocator-level leak measurement. Unexpected exceptions fail the process and
qualification. Compilation and qualification finish before any measurements.

The assertion-discarded target is finalized without `-keep`. The audit target
uses `-keep` and enabled contracts. The timed command accepts only
`--iterations N` and confirms the exact number of successful documents; errors
have nonzero exit codes even when Eiffel assertions are discarded.

## GC and interpretation

Our adapter calls `XP_PARSER.parse` with its normal GC policy. The pinned raw
core parser disables collection internally and performs a full collection on
final input. Its adapter restores the caller's incoming GC state on normal and
exceptional exits. That internal collection work remains inside the timed path.

Reports identify the policies as `normal` and `core-managed-off-full-collect`.
The ratio is therefore an end-to-end comparison of these implementations with
their actual GC behavior. It does not isolate scanner performance or imply
identical internal GC policies. The common adapter boundary, parser reset/reuse,
input preparation, collection work and native process startup are timed.
Input generation is once per process; the core's UTF-8 codec is reused for the
unchanged catalog. Compilation and the observing-handler checks are untimed.
These new harness measurements should retain their provenance when compared
with older benchmark snapshots.

## Reports and failures

The top-level `run.json` progresses through running, qualified, measuring and
complete, or records failure. A successful run publishes a human-readable
`summary.md`, with detailed evidence in `report.json` and linked per-build
`build.json` manifests:

- Both implementation revisions, exact input hash/length and executable hashes.
- The four build configurations, source fingerprints, compiler versions/flags,
  helper objects, qualification identities and all named outcomes.
- Raw alternating pairs, calibration/warmup settings, median throughput and
  paired time ratio with its observed range.

`comparison/comparison.json` and `.tsv` retain the paired driver's raw samples.
The final gate checks the selected workload, complete pair count, qualified
binary hashes and finite positive measurements. Audit and benchmark builds
must use the same source revision and content fingerprints for each engine;
the wrapper's source inputs are checked again after timing. Build/qualification errors stop
timing; both implementation outcomes are retained. Measurement or final report
publication failure removes the current run's numeric reports, keeps failure
logs and leaves earlier run directories alone. Read `run.json` and require
`status=complete` before treating a run as a completed comparison.

The directed correctness set is deliberately limited to this workload and
reuse/recovery boundary. It does not establish W3C, native DLL or general XML
parity. The pinned source checkout remains unmodified.

## CI and infrastructure verification

Both main Jenkins pipelines now run this lane and the dual W3C lane under
`RUN_BENCHMARKS`, with both implementations in the plots. See
[Dual implementations in Jenkins and plots](dual-implementation-jenkins.md)
for execution, failure handling and metrics.
The Jenkins Test Result summary and test gate count only our directed controls;
core remains in the execution, timing plots and comparison artifacts.

The standalone [Jenkins pipeline](../ci/Jenkinsfile.dual-catalog) selects only
this lane on the existing Windows `built-in` agent and archives its reports and
logs even on failure. Configure a Pipeline-from-SCM job with that script path
to execute it. It disables concurrent runs of that job; timing still describes
the host conditions of the recorded run. Controller execution is separate from
the local verification recorded below.

GitHub Actions exercises the runner's protocol/failure tests on Linux. Run the
affected infrastructure checks locally with:

```powershell
python -m unittest discover -s tests/python -p test_implementation_builds.py -v
python -m unittest discover -s tests/python -p test_dual_catalog.py -v
python -m unittest discover -s tests/python -p test_compare_eiffel_benchmarks.py -v
```

The original [inventory](implementation-coverage.md) is a source snapshot from
before this lane. It remains the map for choosing subsequent suites; this lane
completes only its Windows catalog/no-additional-GC-suspension slice.

## Local verification, 25 October 2026

The command `scripts/run_dual_catalog.ps1 -Offline` completed with EiffelStudio
25.02.9.8723 Enterprise and MSVC 19.44.35229 on Windows x64. Both implementations
passed all five qualification cases in each assertion configuration: 20 named
case/configuration outcomes. The 28 build/setup, 14 lane-runner and 10 paired
driver tests also passed, including the hard-link alias checks.

Calibration selected 32,000 documents per sample. Six measured pairs gave:

| Implementation | Median elapsed ms | Median MiB/s |
|---|---:|---:|
| xpact | 4,458.339 | 17.872 |
| pinned Xpact-core | 1,809.717 | 44.030 |

The median paired xpact-time/core-time ratio was **2.4764**, with individual
ratios from **2.3505 to 2.4888**. This result includes the different internal GC
policies described above and applies to this catalog workload.

The [portable evidence snapshot](../benchmarks/results/dual-catalog-2026-10-25.json)
retains raw pairs, calibration, exact input and executable hashes, configuration,
source fingerprints and qualification outcomes. Our build used base revision
`0e45967f3cb7b866387d9a38dcf7049a59f7086e` plus this uncommitted harness change;
the dirty-tree flag and source hashes are retained rather than identifying it
as an unchanged checkout. Core remained at the locked commit. Full local build
manifests and logs are under `build/dual-catalog/20261025T145433Z-2da55487fe38/`.
The standalone Jenkins definition has not been run on the controller.
