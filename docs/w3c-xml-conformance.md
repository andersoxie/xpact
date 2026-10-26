# W3C XML conformance benchmarks

For the same cases against both our implementation and pinned Finnian Xpact-core,
use the [focused dual W3C lane](dual-w3c-lane.md). It runs the full applicable
catalog with finalized assertions discarded and retains unsuppressed outcomes
for both engines.

`scripts/run_benchmarks.ps1` runs the W3C XML binary conformance tests by
default, once for each selected Eiffel build. The default builds are
`Finalized` and `FinalizedAssertions`; `Workbench` is also supported. The
W3C lane checks whether xpact accepts or rejects each applicable document and
records elapsed time separately from the catalog throughput benchmarks.
`FinalizedAssertions` is compiled with `-finalize -keep`, since EiffelStudio
otherwise discards runtime assertions during finalization.

The source is the [W3C XML Conformance Test Suite](https://www.w3.org/XML/Test/),
pinned to [the 20130923 ZIP](https://www.w3.org/XML/Test/xmlts20130923.zip).
The [W3C test matrix and case descriptions](https://www.w3.org/XML/Test/xmlconf-20130923.html)
explain the expected results for validating and nonvalidating processors.

## Run locally

Use Python 3.10 or later on `PATH`, EiffelStudio command-line tools, and the
normal Windows benchmark build prerequisites. The Python runner uses only
the standard library.

```powershell
.\scripts\run_benchmarks.ps1 -EiffelBuild Finalized,FinalizedAssertions
```

The runner downloads the pinned archive to
`build/validation-corpora/w3c-xml-20130923/xmlts20130923.zip` when absent.
It verifies this SHA-256 on every reuse and extracts the original files
before loading the catalog:

```text
f9510b3532926e1b4c2e54855b021e4b8a66ec98a5337dcf4ff07e8a41968deb
```

For an offline run, provide an extracted directory containing `xmlconf.xml`:

```powershell
.\scripts\run_benchmarks.ps1 `
  -W3cSuiteDirectory C:\data\w3c-xml-20130923\xmlconf `
  -W3cTimeoutSeconds 10
```

`-W3cTimeoutSeconds` limits each parser process to 10 seconds by default.
The normal benchmark `-Iterations` and `-Repetitions` options do not repeat
the conformance cases. `-SkipBuild` reuses existing benchmark executables;
these must have been compiled with the conformance command support.
`-SkipW3cConformance` explicitly omits the suite for a local throughput run.
The Jenkins pipelines do not pass this switch.

To rerun only conformance against an already built executable:

```powershell
python .\scripts\run_w3c_conformance.py `
  --engine "Finalized=EIFGENs/xpact_benchmarks/F_code/xpact_benchmarks.exe" `
  --suite-dir C:\data\w3c-xml-20130923\xmlconf `
  --timeout 10
```

Repeat `--engine NAME=EXE` to test additional builds. Omit `--suite-dir` to
use the verified download/cache. `--cache-dir` selects another archive cache
and `--output-dir` selects another report directory. An explicitly supplied
local suite directory is reported as `source_mode: local-directory`; its
contents are not verified against the archive checksum.

## Conformance profile

The runner reads `xmlconf.xml` and its local included catalogs. It does not
treat every XML file in the archive as a test. The pinned catalog contains
2,585 active cases. The current profile selects 1,727 cases per Eiffel build
and reports the other 858 as skipped, each with a reason.

The profile is XML 1.0, fifth edition, with namespace processing enabled
unless a case declares `NAMESPACE="no"`. It uses the direct Eiffel parser
as a nonvalidating processor without an external entity loader. Cases for
other XML versions or editions, cases requiring external entities, and
optional-error cases are outside this profile.

| Catalog type | Required result for an applicable case |
|---|---|
| `valid` | Accept. |
| `invalid` | Accept: DTD validity constraints are not checked. |
| `not-wf` | Reject. |
| `error` | Skipped: neither acceptance nor rejection is universally required. |

These are binary acceptance/rejection checks. Canonical output comparison,
event-trace comparison, external entity processing, and native C ABI
conformance are not covered by this lane. Passing the selected cases alone
does not establish full W3C XML conformance.

Every applicable case launches a fresh Eiffel process, which reads the
original document bytes. Timings include process startup and the file read;
they are not parser-only throughput measurements. A process crash, timeout,
missing file, or inconsistent verdict is an error, never a successful
rejection. Unexpected acceptance/rejection and harness errors return a
nonzero status after reports have been written.

### Known failures

`benchmarks/w3c-known-failures.tsv` lists the parser gaps that were recorded
on 2026-10-23 (columns `engine`, `case_id`, `status`, `category`). The category
column records what was observed, not the cause. `run_benchmarks.ps1` passes
the file to the runner with `--known-failures` by default
(`-W3cKnownFailures ""` turns it off).

- A listed failure or error is still reported: `junit.xml` shows it as a
  failure marked `[known: ...]`, and `summary.md` counts it under *Known*.
  It no longer makes the command fail.
- Any failure or error that is not listed is *Unexpected* and fails the run.
- A listed case that now passes, has another status, or is missing from the
  catalog also fails the run, as a `harness` error named
  `known-failures:<engine>:<case>`. Remove or update its row.

After a parser fix, rerun with `--write-known-failures <file>`, compare the
written file with the list, and remove the fixed rows.

## Reports and Jenkins

Reports are written under `<OutputDir>/w3c-xml-conformance/`, which defaults
to `build/benchmarks/w3c-xml-conformance/`:

| File | Contents |
|---|---|
| `results.tsv` | Per-case engine, catalog ID, path, expected and actual verdict, status, elapsed time, and diagnostic message. |
| `summary.json` | Source/profile metadata and per-engine passed, failed, error, skipped, accepted, rejected, known, unexpected, and timing totals. |
| `summary.md` | Human-readable result totals, including *Known* and *Unexpected*. |
| `junit.xml` | Per-case success, failure, error, and skip results for Jenkins. |

Both `ci/Jenkinsfile.all-tests` and `ci/Jenkinsfile.windows-phase1` include
the suite under `RUN_BENCHMARKS`, enabled by default. They run the Python
runner unit tests before executing the benchmarks and test both finalized
assertion modes. Set `W3C_SUITE_DIRECTORY` to an extracted suite directory
for an offline Jenkins agent. Keep that directory outside workspaces cleared
by the all-tests pipeline.

Unexpected conformance results fail the benchmark command; known failures
make the published JUnit report show failures, which Jenkins marks as
UNSTABLE rather than FAILURE. The Jenkins
`post` block publishes `junit.xml` even after that failure, and the pipelines
archive all four report files. Conformance cases are published independently
of the existing throughput TSV-to-JUnit conversion. Previous conformance
reports are cleared before execution to avoid publishing stale results.
See [the test matrix](test-matrix.md) for the other verification lanes.

The runner's isolated regression tests can also be run locally:

```powershell
python -m unittest discover -s tests/python -p test_w3c_conformance.py
```

## Initial integration run: 6 October 2026

The verified archive was run through `run_benchmarks.ps1` with both rebuilt
finalized targets. The 22 Python runner regression tests passed. The suite
exposed existing parser failures; the benchmark command correctly returned
a failure status and retained all 5,170 case records:

| Build | Passed | Wrong verdict | Runtime errors | Skipped |
|---|---:|---:|---:|---:|
| Finalized | 1,491 | 236 | 0 | 858 |
| FinalizedAssertions | 270 | 97 | 1,360 | 858 |

Observed gaps include UTF-16 input rejection, undeclared element-prefix
acceptance with the null event handler, and a loop-variant contract failure
in `XP_PARSER.normalized_input` when assertions are retained. These results
are recorded as failures, not an expected-failure baseline. Parser fixes
are separate work. Jenkins pipeline execution itself was not performed as
part of this local integration check.

## Known-failures baseline: 23 October 2026

The Jenkins build of `main` at `cf12dee` failed at this lane with the same
totals as a local run of the same parser code (`student-Mass` at `63f67f3`):

| Build | Passed | Wrong verdict | Runtime errors | Skipped |
|---|---:|---:|---:|---:|
| Finalized | 1,491 | 236 | 0 | 858 |
| FinalizedAssertions | 1,444 | 236 | 47 | 858 |

Of the 236 wrong verdicts, 220 accept input that must be rejected and 16
reject input that must be accepted; both builds fail the same cases. The 47
runtime errors occur only with assertions retained and match the 22 October
crash list in `reports/issue-0028/w3c-after-fix/crashes-assertions-on.tsv`.
These 519 results form the first known-failures list.

## Upstream catalog accommodations

The pinned root catalog has a Latin-1 comment despite its UTF-8 declaration,
and an `xml:base` value of `eduni/namespaces/misc/` that should resolve to
`eduni/misc/`. The importer accommodates both defects in memory only when
the root catalog SHA-256 matches the known upstream file:

```text
a10d3fc409fc0de5ea1758d2e4fe6efcbc51df6d1942c80f299dbbe085b2fd52
```

Child catalogs retain their own declared encodings. Test documents, catalogs,
directory structure, and upstream notices remain unchanged on disk. Catalog
includes and test paths must remain inside the local suite directory; the
catalog importer does not fetch remote entities.
