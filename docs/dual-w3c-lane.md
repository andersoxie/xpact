# Dual W3C lane

This lane runs the same W3C XML catalog with our parser and the pinned Finnian
Xpact-core implementation. It extends the [dual catalog lane](dual-catalog-lane.md)
with functional acceptance/rejection checks in the same **Windows x64, Eiffel
finalized, assertions discarded** configuration.

## Run both implementations

Use the prerequisites in [Pinned implementation builds](implementation-builds.md).
From the repository root:

```powershell
.\scripts\run_dual_w3c.ps1
```

Use `-Offline` when the pinned core checkout and W3C archive are already cached.
Alternatively, supply an extracted directory containing `xmlconf.xml`:

```powershell
.\scripts\run_dual_w3c.ps1 -Offline -SuiteDirectory C:\data\xmlconf -TimeoutSeconds 10
```

The default archive is verified against the existing pinned SHA-256 and extracted
into a fresh `build/dual-w3c/<run-id>/suite/`. A supplied directory is identified
as local input; it does not acquire the archive's verified provenance. The driver
hashes every suite file, checks each case's bytes before and after execution, and
checks the full tree before each engine and before publishing. Input and output
directories must be separate. Existing run directories are never reused.

## Shared cases and expectations

The driver uses the [existing W3C importer and profile](w3c-xml-conformance.md#conformance-profile),
without a known-failure allowlist. The pinned catalog has 2,585 rows: **1,727
applicable cases per implementation** and **858 explicit exclusions per
implementation**. Every row is retained for both engines.

| Profile choice | Behavior |
|---|---|
| XML version | XML 1.0, fifth edition |
| Namespaces | Enabled unless the catalog says `NAMESPACE="no"` |
| Nonvalidating processor | Both `valid` and `invalid` require ACCEPT; `not-wf` requires REJECT |
| External resources | No external entity loader; cases requiring external entities excluded |
| Other exclusions | Other XML versions/editions and optional-error cases, with explicit reasons |

Each applicable case starts a fresh executable and reads the original file bytes,
including BOMs and UTF-16 bytes. No caller-side decoding or rewriting occurs.
The two engines run sequentially on the same catalog; one engine's wrong verdict,
crash or timeout does not prevent its counterpart from running. Elapsed times
include process startup and file reading and are not parser-only throughput.

Both adapters use their direct Eiffel parser with no-op events. Core naming mode
is selected before parser construction because it determines internal cache
classes. This lane does not cover native DLLs, .NET, canonical output, event
equality, external entity processing or all XML conformance profiles.

## Directed controls and build identity

The command first builds each implementation twice: an assertion-enabled audit
target (`-finalize -keep`) and the primary assertion-discarded target
(`-finalize`, without `-keep`). The complete W3C catalog runs only on the primary
targets. Both configurations run five explicit controls:

| Control | Observation |
|---|---|
| `raw_utf8` | Non-ASCII UTF-8 with/without BOM; malformed final input rejected |
| `raw_utf16` | Original little- and big-endian UTF-16 BOM documents |
| `namespace_switch` | Bound/unbound prefixes and multi-colon names with namespace processing on/off |
| `reuse_recovery` | Same parser: valid, repeated valid, mismatch, unbound prefix, valid; diagnostics reset |
| `gc_restoration` | Incoming collection on/off restored after valid, mismatched and empty input; owned parser/input references released on close |

A failed control or abnormal control process is recorded and makes the campaign
fail, while independent catalog cases still run. Build failure, an incorrect
identity or changed source/executable bytes prevent a verified campaign. Audit
and primary builds must share each implementation's source fingerprints.

Our parser retains its normal GC policy. The pinned core parser disables
collection internally and performs a full collection on final input. The adapter
restores the caller's incoming GC state on normal and exceptional exits. The
controls check state and owned reference cleanup; they do not measure allocator
leaks or imply identical internal GC behavior.

## Reports and exit status

The command prints its unique run directory. Read `run.json` for the final state:
`running` -> `executing` -> `complete` or `complete_with_failures`. Infrastructure
or report-persistence failure records `failed` and removes the current run's final
reports, while preserving phase logs and case diagnostics for investigation.

| File | Contents |
|---|---|
| `summary.md` / `report.json` | Both engine totals, directed controls and build provenance |
| `comparison.tsv` | One row per catalog case, both expected/actual outcomes, statuses and exit codes |
| `suite-manifest.json` | Every suite file hash and case selection/expectation |
| `conformance/` | Canonical detailed results, summary and JUnit XML |
| `work/<engine>/<case>/` | Original stdout/stderr bytes, command/result JSON and any Eiffel exception trace |
| `audit/` / `primary/` | Isolated build manifests, compiler logs and directed-control logs |

Normal ACCEPT requires exit 0; normal REJECT requires exit 1. Wrong verdicts are
failures. Crashes, launch errors, timeouts and inconsistent output are errors.
Agreement between two incorrect verdicts is still failure. Missing input files
are errors for both engines. Exclusions are skipped, never counted as passed.

The Python command returns 0 for `complete`, 1 for `complete_with_failures`, and
2 for infrastructure failure. The PowerShell wrapper throws on either nonzero
result and includes the Python exit code. A completed red campaign remains a
useful comparison, but does not establish a green conformance baseline.

## CI and runner verification

Both main Jenkins pipelines now run this lane and the dual catalog lane under
`RUN_BENCHMARKS`, with both implementations in the plots. See
[Dual implementations in Jenkins and plots](dual-implementation-jenkins.md)
for execution, failure handling and metrics.
Only our results enter the Jenkins Test Result summary and decide its test
pass/fail status; core still runs and remains in the plots and detailed reports.

The standalone [Windows Jenkins pipeline](../ci/Jenkinsfile.dual-w3c) selects only
this lane. Configure a Pipeline-from-SCM job using that script path. It runs the
runner checks, publishes our filtered JUnit and archives both implementations'
reports and per-case output even when parser results fail. No existing GitHub Actions workflow is changed.
Jenkins controller execution is separate from local verification.

```powershell
python -m unittest discover -s tests/python -p test_implementation_builds.py -v
python -m unittest discover -s tests/python -p test_w3c_conformance.py -v
python -m unittest discover -s tests/python -p test_dual_w3c.py -v
```

## Local verification, 25 October 2026

`.\scripts\run_dual_w3c.ps1 -Offline` completed the whole selected catalog using
EiffelStudio 25.02.9.8723 Enterprise and MSVC 19.44.35229 on Windows x64. The
campaign retained all **5,170 engine/case rows** and returned Python exit 1,
`complete_with_failures`, for the observed core results:

| Implementation | Passed | Wrong verdicts | Timeouts | Excluded |
|---|---:|---:|---:|---:|
| xpact | 1,727 | 0 | 0 | 858 |
| pinned Xpact-core | 1,051 | 662 | 14 | 858 |

Core's wrong verdicts comprise 339 false accepts and 323 false rejects. For
example, `rmt-ns10-025` and `rmt-ns10-026` contain unbound element/attribute
prefixes: core accepted both with namespaces enabled, while xpact rejected
them. Core rejected the original big-endian UTF-16 document `utf16b`; xpact
accepted it as required. UTF-16 does not explain the broad false-reject count:
312 of those 323 cases are in `eduni/errata-4e`, covering fifth-edition name
changes. These are observations; this change does not repair the pinned parser.

All 14 process errors were ten-second timeouts with empty stdout/stderr, on
30–295-byte malformed inputs. For example, `not-wf-sa-055` contains an unfinished
DOCTYPE/internal subset and `o-p24fail1` has mismatched XML-version quotes.
Their internal cause remains unconfirmed. They are not normal rejections or
demonstrated crashes.

Both assertion configurations gave the same directed results: xpact passed
5/5 controls, core passed 2/5 (`raw_utf8`, `gc_restoration`) and failed the UTF-16,
namespace and reuse-sequence controls. The reuse sequence includes an unbound
prefix check, so its failure does not independently establish a recovery defect.
All four binaries compiled and passed their identity checks. The 32 build,
28 canonical W3C, 25 dual W3C and 14 existing dual catalog runner tests passed
(99 tests). The wrapper and both embedded Jenkins PowerShell blocks passed
syntax parsing; Jenkins controller execution has not been performed.

The [portable evidence](../benchmarks/results/dual-w3c-2026-10-25.json) retains
configuration, compiler details, source/executable hashes, all directed outcomes,
totals and timeout IDs. Its [case comparison](../benchmarks/results/dual-w3c-2026-10-25.tsv)
contains all 2,585 catalog rows with input hashes, matching exclusions and both
verdicts/exit codes. Full raw output, build logs and reports remain locally under
`build/dual-w3c/20261025T154254Z-45fe02bb6e8c/`.

Our source is base revision `4106de4a04f1c6aaa4dad5e9fce4bfb4bd813beb` plus
this uncommitted lane change; the dirty-tree flag and content fingerprints are
retained. Core remained unmodified at the locked revision
`6c017fb5b6e04fd0ae401bc54bb3c6a3c3bd6676`. The earlier catalog baseline and
single-implementation W3C history remain separate evidence.
