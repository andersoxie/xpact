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

**Status reviewed 13 November 2026:** the default profile checks 1,974 cases;
`-W3cAllCases`, selected by both main Jenkins benchmark stages, additionally
runs 309 legacy-name verdict cases and 302 no-crash-only cases. The committed
[28 October integrated run](../reports/latest-2026-10-28/README.md) records
2,283 checked verdicts plus 302 no-crash-only outcomes per assertion mode,
with no failures, errors or skips. These are dated Windows EiffelStudio results,
not a fresh run or evidence for Gobo. Historical failure tables below retain
their original dates and profiles.

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
2,585 active cases. The current profile selects 1,974 cases per Eiffel build
and reports the other 611 as skipped, each with a reason.

The profile is XML 1.0, fifth edition, with namespace processing enabled
unless a case declares `NAMESPACE="no"`. It uses the direct Eiffel parser
as a nonvalidating processor with suite-local external general and parameter
entities, including external DTD subsets. Every applicable entity-tagged case
is selected. The runner passes `--suite-root` with the canonical extracted
`xmlconf` directory; the xpact adapters enable loading and disable unread-entity
skips for that run. Other XML versions or editions and optional-error cases
remain excluded.

| Catalog type | Required result for an applicable case |
|---|---|
| `valid` | Accept. |
| `invalid` | Accept: DTD validity constraints are not checked. |
| `not-wf` | Reject. |
| `error` | Skipped: neither acceptance nor rejection is universally required. |

The one edition correction is `rmt-e2e-38`: its upstream catalog says REJECT,
but the fifth-edition profile requires ACCEPT for the exact reviewed document
and external-entity bytes. Both expectations and the reason remain in the
results; see [the E38 correction](#external-resource-coverage-27-october-2026).

These are binary acceptance/rejection checks. Canonical output comparison,
event-trace comparison and native C ABI
conformance are not covered by this lane. Passing the selected cases alone
does not establish full W3C XML conformance.

Every applicable case launches a fresh Eiffel process, which reads the
original document bytes. Timings include process startup and the file read;
they are not parser-only throughput measurements. A process crash, timeout,
missing file, or inconsistent verdict is an error, never a successful
rejection. Unexpected acceptance/rejection and harness errors return a
nonzero status after reports have been written.

Relative external identifiers resolve from the file that declared them, so a
nested DTD does not inherit the top document's directory accidentally. Resource
bytes are read without caller-side decoding or rewriting. The local loader
percent-decodes valid UTF-8 identifiers and confines paths to the suite tree;
absolute/network identifiers, query/fragment components, escapes, symbolic links
and Windows reparse points are denied. The loader checks suite-root locality
before filesystem access, rejecting UNC and mapped network roots. Missing, unreadable or denied parsed
resources produce exit 2 without an ACCEPT/REJECT marker and are harness errors.
They cannot pass a malformed-input test. NOTATION and unparsed NDATA identifiers
are declarations, not files to load.

### External resource coverage: 27 October 2026

The remaining 65 entity-tagged cases are enabled. The selected profile now has
**1,974 cases: 958 require ACCEPT and 1,016 require REJECT**, with 611 explicit
exclusions (584 other-version/edition cases and 27 optional errors). The old
internal-only `not-wf-not-sa-002` hash exception is no longer needed because
entity metadata no longer excludes binary tests.

One of these 65 inputs, `rmt-e2e-38`, has an obsolete catalog expectation.
Its `E38.ent` declares version 1.1 but contains only `<foo/>`, which uses XML 1.0
syntax. [Fourth-edition erratum E10](https://www.w3.org/XML/xml-V10-4e-errata#E10)
reversed second-edition E38 and broadened `VersionNum` to `1.` followed by digits.
That grammar is part of [XML 1.0 fifth edition, section 2.8](https://www.w3.org/TR/2008/REC-xml-20081126/#sec-prolog-dtd),
and the [text-declaration grammar in section 4.3.1](https://www.w3.org/TR/2008/REC-xml-20081126/#sec-TextDecl)
uses the same `VersionInfo`. Acceptance is therefore required for these bytes.
The importer changes this case's profile expectation to ACCEPT only when the
case metadata, path and both original input hashes match. The upstream
`catalog_expected=REJECT` and `expectation_adjustment` are retained in TSV,
summary JSON, passing JUnit properties and dual-engine comparisons. A changed
document, entity or catalog record receives its ordinary catalog expectation.

`not-wf-sa-081` and `not-wf-sa-082` use the Windows reserved name `nul` inside
forbidden external references in attributes or attribute defaults. Their XML
defect must be rejected before a resolver request; failure to open `nul` would
be an infrastructure error rather than evidence that the XML defect was caught.
The [resource audit](../reports/w3c-external-2026-10-27/resource-audit.json)
also identifies NOTATION/unparsed identifiers that must never be fetched.

Fresh finalized builds with matching source fingerprints completed the whole
selected suite with exit 0 and no known-failure allowlist:

| Build | Passed | Wrong verdicts | Runtime errors | Skipped | ACCEPT | REJECT |
|---|---:|---:|---:|---:|---:|---:|
| Assertions discarded | 1,974 | 0 | 0 | 611 | 958 | 1,016 |
| Assertions retained | 1,974 | 0 | 0 | 611 | 958 | 1,016 |

All 65 additions passed in each build; the previous 1,909 selected cases also
passed with external loading enabled. All five directed controls passed per
build. The separate finalized Eiffel regression matrix passed 73 routines per
assertion mode (146 executions), covering DTD parameter expansion and original
positions, malformed external text/UTF-16 recovery, callback suspension and
retry, nested declaring-file bases, missing-resource recovery, declaration
precedence, no-I/O attribute/default errors and file cleanup. Its source, test
and ECF inputs were hashed before the builds and verified unchanged afterwards.

The ordinary benchmark adapter was independently rebuilt in both finalized
assertion modes and passed the same 65 additions. Both entry points and modes
also passed 25 CLI boundary fixtures each (100 checks), including UNC suite-root
denial before resource I/O, missing/denied resources becoming errors, explicit
and default attribute errors remaining XML rejections, and an actual Windows
directory junction being denied. The exact junction was removed while its
target file remained intact. A mapped remote-drive branch was reviewed but
could not be exercised because the machine had no mapped remote drive.
The 36 canonical runner, 26 dual-runner and 33 build-runner tests passed.

The [summary and build identities](../reports/w3c-external-2026-10-27/summary.json),
[all 5,170 catalog rows](../reports/w3c-external-2026-10-27/results.tsv),
[65-case before/after matrix](../reports/w3c-external-2026-10-27/additional-cases.tsv),
[Eiffel regression evidence](../reports/w3c-external-2026-10-27/eiffel-regressions.json),
[benchmark adapter results](../reports/w3c-external-2026-10-27/benchmark-adapters.json)
and [CLI boundary checks](../reports/w3c-external-2026-10-27/cli-boundary-checks.json)
retain commands, hashes and outcomes. All 3,386 extracted suite files were
compared byte-for-byte with the checksum-verified archive after execution.
Earlier diagnostics and the pre-local-root-guard snapshot are preserved
separately. The 26 October results below cover the previous 1,909-case profile.
The pinned core implementation remains a no-loader comparison; its expanded
comparison, native DLL/.NET integration and Jenkins controller were not run.

### Expanded coverage verified: 26 October 2026

The 182 additions are enabled and all 33 observed failures are fixed. A fresh
run of the checksum-verified pinned suite completed with these results:

| Build | Passed | Wrong verdicts | Runtime errors | Skipped |
|---|---:|---:|---:|---:|
| Finalized, assertions discarded | 1,909 | 0 | 0 | 676 |
| Finalized, assertions retained | 1,909 | 0 | 0 | 676 |

Both runs include all original 1,727 selected cases and all 182 additions. The
181 added valid/invalid documents accept; `not-wf-not-sa-002` rejects. No
known-failure allowlist was used. Each build accepted 957 documents and rejected
952, retaining all 2,585 catalog rows. The 676 exclusions comprise 65 malformed
external-resource cases, 584 version/edition exclusions and 27 optional errors.

That campaign enabled an explicit nonvalidating skip option in both xpact
W3C adapters. Skips report callbacks and preserve well-formedness checking of
the document. An unread parameter entity suppresses later entity/attribute
declarations unless standalone; reset restores per-document state. Default
external-entity rejection, resolver denial, and literal-reference errors remain
unchanged. Changing the option releases the completed-DOCTYPE cache.

DTD parsing now carries an explicit text-declaration context. Only the entry to
an actual external resource can allow its leading text declaration; an internal
subset, internal parameter replacement or conditional-section body cannot.
This fixed the reserved `xml` target acceptance without mutable context state
that could survive failure or reuse. That campaign's one metadata exception
required the known input hash, path and metadata, rather than trusting its ID.

Fresh Windows x64 finalized builds used EiffelStudio 25.02.9.8723 Enterprise
and MSVC 19.44.35229, with `-keep` only for the assertion-enabled W3C target.
The 70 Eiffel regression tests passed in each assertion mode, including policy
changes, malformed input after a skip, callback abort/recovery, standalone
handling, declaration-state reset, cache ownership/release, and legal external
text declarations through final and prefix parsing. All five directed W3C
controls passed per build. The 32 canonical runner, 26 dual-runner and 33 build
runner tests also passed. A dual-runner test initially detected concurrent
source edits; its retry after source stabilization passed.

The ordinary benchmark entry point was rebuilt separately in both finalized
assertion modes. Each benchmark adapter passed the same 33 previously failing
cases and a one-iteration benchmark smoke, confirming its new configuration
independently of the isolated W3C adapter.

The [summary and build identities](../reports/w3c-expanded-2026-10-26/summary.json),
[full case matrix](../reports/w3c-expanded-2026-10-26/results.tsv),
[before/after results for the additions](../reports/w3c-expanded-2026-10-26/additional-cases.tsv),
and [Eiffel regression evidence](../reports/w3c-expanded-2026-10-26/eiffel-regressions.json)
plus [benchmark adapter checks](../reports/w3c-expanded-2026-10-26/benchmark-adapters.json)
record the exact command and source/executable fingerprints. Full local logs
and canonical JUnit are under `build/w3c-expanded-2026-10-26/`. External-content
processing, native DLL/.NET integration, the pinned core implementation and
Jenkins controller were not rerun in this campaign.

### Skipped-case investigation: 26 October 2026

The initial investigation found **182 previously skipped cases** that could
already run as additional binary checks. At revision `687f6cf`, they exposed
**33 failures per build**. That investigation left parser code and selection
unchanged; the subsequent implementation enables these cases and fixes the
failures.

The 858 exclusions at revision `687f6cf` divide as follows. Counts use the
runner's first applicable exclusion reason, so the groups do not overlap.

| Exclusion | Cases | Investigation result |
|---|---:|---|
| External-entity metadata | 247 | 181 valid/invalid inputs can run as acceptance checks; one additional malformed input needs only internal entities. |
| Earlier XML 1.0 editions | 310 | Keep excluded from the fifth-edition profile. |
| XML 1.1 / Namespaces 1.1 | 273 | Keep excluded from the current profile. |
| Other XML version | 1 | Keep excluded from the current profile. |
| Optional error detection | 27 | Can run as robustness checks accepting either normal verdict. |

The suite's `testcases.dtd` and [W3C binary test matrix](https://www.w3.org/XML/Test/xmlconf-20130923.html)
require nonvalidating processors to accept valid and invalid documents, even
when they do not read external entities. Both freshly built xpact assertion
modes accepted **149 of the 181 entity-tagged valid/invalid cases** and rejected
**32**, all with `external entity not loaded`. The accepted cases check document
acceptance; they do not demonstrate that the external content was processed.

Four accepted cases need no external files at all: `valid-sa-070`, `v-pe02`,
`o-p28pass3`, and `o-p69pass1`. Their internal parameter entities are caught by
the same catalog metadata filter as external resources. A fifth internal-only
case, **`not-wf-not-sa-002`**, is incorrectly accepted by both assertion modes.
Its parameter entity expands to `<?xml version='1.0' encoding='UTF-8'?>` inside
the DTD, where that reserved processing-instruction target must be rejected.
The internal expansion reaches `process_internal_subset`; the XML-declaration
branch accepts it. This observed defect is independent of a file resolver.

At that revision, running the 181 acceptance cases and this rejection case would
raise binary coverage to **1,909**, with 149 additional matching verdicts and 33
additional failures. The remaining 65 malformed entity-tagged cases need external loading
or individually justified expectations: without reading their external content,
a nonvalidating processor may be permitted to accept them.

All 858 excluded inputs were also executed diagnostically in each freshly built
finalized assertion mode. No other-version/edition verdict was counted as a
conformance result. Three assertion-enabled Japanese inputs exceeded the
exploratory three-second limit; all accepted at the normal ten-second limit
in 4.2–4.3 seconds. The 27 applicable optional-error cases returned 13 ACCEPT
and 14 REJECT outcomes in each mode, with no abnormal execution. These can
become a separate robustness lane, with crashes and timeouts failing the check.

A separate assertion-enabled prototype loaded local external files using the
existing resolver interface. All 247 entity-tagged cases executed normally:
169 matched the catalog verdict, 75 differed, and three were inconclusive
because of missing-resource or nested-base limitations. These are prototype
observations, not a qualified external-entity conformance baseline. Production
coverage needs a resolver-enabled harness handling declaring-file bases,
external text declarations and encodings. The current W3C adapters explicitly
disable loading; removing all entity skips alone would not exercise it.

The [recorded build identities and totals](../reports/w3c-skips-2026-10-26/no-resolver-summary.json),
[all 1,716 observations and timeout rechecks](../reports/w3c-skips-2026-10-26/no-resolver-observations.tsv),
[reproduction script](../reports/w3c-skips-2026-10-26/probe_no_resolver.py), and
[external-loader prototype](../reports/w3c-skips-2026-10-26/external-probe/README.txt)
retain the evidence. All 3,386 extracted suite files were compared byte-for-byte
with the checksum-verified pinned archive. The 28 canonical runner tests and
25 dual-runner tests passed. The first canonical test attempt encountered a
sandbox temporary-directory permission error; rerunning with `TEMP` and `TMP`
inside `build/` passed. The original 1,727-case lane and pinned core implementation
were not rerun in this investigation; canonical output and event comparisons
were not tested.

### All cases (`--all-cases`)

With `--all-cases` the runner also runs the 611 cases outside the current profile,
instead of skipping them. Every `--engine` then needs an
`--entity-engine` with the same name: the DLL checker built from
`tests/native/xpact_w3c_case.c` against that build's DLL.

| Lane | Cases | Program | Required result |
|---|---:|---|---|
| `legacy-names` | 309 | the engine with `--legacy-names` (fourth-edition name tables, as `XP_NATIVE_PARSER` uses) | the catalog verdict |
| `optional-error` | 28 | the engine, or the DLL checker when the case has external entities | either verdict; a crash, timeout or missing verdict fails |
| `xml-1.1` | 274 | the engine, or the DLL checker when the case has external entities | either verdict; a crash, timeout or missing verdict fails |

The 247 binary external-resource cases are now included in the 1,974-case core
profile and use the Eiffel suite-local resolver. They are not 247 extra cases.
The runner retains an `external-entities` routing category for excluded binary
cases, but the current pinned profile has none in that category. The
[separate 247-case DLL check](../reports/latest-2026-10-28/README.md#external-entities-through-the-dll)
provides evidence for the child-parser API path.

```powershell
cl /nologo /Iinclude tests\native\xpact_w3c_case.c build\native-eiffel\xpact.lib /Fe:build\w3c-dll\xpact_w3c_case.exe
cl /nologo /Iinclude tests\native\xpact_w3c_case.c build\native-eiffel\xpact_assertions.lib /Fe:build\w3c-dll\xpact_w3c_case_assertions.exe
copy build\native-eiffel\xpact.dll, build\native-eiffel\xpact_assertions.dll build\w3c-dll\
python scripts\run_w3c_conformance.py --all-cases `
  --engine Finalized=EIFGENs\xpact_benchmarks\F_code\xpact_benchmarks.exe `
  --engine FinalizedAssertions=EIFGENs\xpact_benchmarks_assertions\F_code\xpact_benchmarks.exe `
  --entity-engine Finalized=build\w3c-dll\xpact_w3c_case.exe `
  --entity-engine FinalizedAssertions=build\w3c-dll\xpact_w3c_case_assertions.exe
```

`results.tsv` gains a `lane` column, `summary.md` a table per lane, and JUnit
class names end in the lane (`w3c.xml.<engine>.<lane>`; core cases keep
`w3c.xml.<engine>`). Without `--all-cases` nothing changes. With assertions
on, the three `pr-xml-*` documents previously took about 16 s each before the
entity-position fix in [#148](https://github.com/andersoxie/xpact/issues/148).
The fix is present in the integrated code; the 28 October campaign completed
with the default ten-second limit. Older revisions without the fix needed a
larger timeout; those timings are historical.

Cases whose lane accepts either verdict (`optional-error`, `xml-1.1`) only
show that the parser gave a verdict without crashing. They are reported
apart from checked verdicts: `summary.json` counts them as `no_crash_only`
(not in `passed`), `summary.md` shows a "No crash only" column, and JUnit puts
them in their own suite, `w3c-xml-<engine>-no-crash-only`.

`scripts/run_benchmarks.ps1 -W3cAllCases` does all of this for the selected
Eiffel builds: it builds the DLL tier matching each build (Finalized →
`xpact.dll`, the others → `xpact_assertions.dll`), compiles the checker into
`build\benchmarks\w3c-dll\<build>\`, and passes `--all-cases` and
`--entity-engine`. The Jenkins Benchmarks stage uses it.

### Known failures

`benchmarks/w3c-known-failures.tsv` is the explicit baseline mechanism introduced
on 2026-10-23 (columns `engine`, `case_id`, `status`, `category`). Its current
file has no active failure rows. The category
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
