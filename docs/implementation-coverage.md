# Dual-implementation coverage inventory

Step 2 inventories the existing tests and workloads before introducing a shared
adapter. Every shared behavior case must eventually produce a result for both
`xpact` and the pinned `xpact-core`. The detailed tables preserve current case
identifiers, source locations, expectations and the boundary each case needs.

This is a **source inventory, not a new test run or a parity report**. Its source
snapshot is xpact commit `480ab3b3d847bac5be3607a80f8ad64d32727726` and Xpact-core
commit `6c017fb5b6e04fd0ae401bc54bb3c6a3c3bd6676`. The latter remains locked in
[`dependencies/xpact-core.json`](../dependencies/xpact-core.json).

## Read the matrix

| Catalog | Unit represented by a row | Coverage |
|---|---|---|
| [Eiffel tests](implementation-coverage/eiffel-tests.tsv) | Registered regression or AutoTest feature | 54 regression IDs and 13 AutoTest features |
| [Native and .NET tests](implementation-coverage/native-tests.tsv) | Native check, document, input or externally expanded family | 736 static rows covering C ABI, private bridge, runtime, CRC, shim, .NET and upstream suite boundaries |
| [Benchmarks and conformance](implementation-coverage/benchmarks.tsv) | Workload or catalog family with its expansion dimensions | 32 families: 19 shared targets, 11 reference lanes and two legacy contributed examples |
| [Infrastructure tests](implementation-coverage/infrastructure-tests.tsv) | Python unittest method | 89 methods in seven modules; framework checks run once |

Rows have different units. A native C `check()` label is an assertion inside a
fail-fast executable, not an independently isolated test. A benchmark family
expands over configurations. An upstream suite family expands over external
case IDs. Do not add these row counts together and call the total "tests run".

Each TSV has these columns:

| Column | Meaning |
|---|---|
| `suite`, `case_id` | Existing suite and case identity; use both as the key |
| `source` | Repository-relative source, with a line number where useful, or a link to the pinned core source |
| `classification` | What the assertions or workload actually exercise |
| `comparison_scope` | Whether the whole case, its semantic portion, or a reference measurement participates |
| `required_boundary` | Direct parser, native public API, private bridge, or harness needed to execute it |
| `xpact_execution`, `xpact_core_execution` | Current source wiring; **not** observed success/failure |
| `expected_behavior` | Existing expected outcome or measurement obligation, separate from observations |
| `migration_note` | Expansion rules, mixed assertions, prerequisites and limitations |

`wired` means the existing xpact entry points select that source path. It does not mean this
inventory executed or validated it. `not_wired` means the common adapter,
compatible DLL, benchmark CLI or orchestration is still missing. It must not be
translated into "unsupported parser feature". `not_applicable` is reserved for
an internal structure, infrastructure check or separate reference engine that
does not make sense as a direct execution of the other parser.

## What must run against both

| Classification | Comparison policy |
|---|---|
| `shared_behavior` | Run the same bytes, options and lifecycle scenario against both parsers and independent expectations |
| `public_api` | Run both through the API named by `required_boundary` once each has an equivalent adapter; distinguish direct Eiffel API evidence from native C/DLL evidence |
| `mixed` | Preserve the existing test; extract its observable behavior for both and retain its implementation-specific assertions separately |
| `implementation_internal` | Keep the test with its implementation; add an equivalent backend-specific check where meaningful |
| `infrastructure` | Validate the framework once, including its handling of both engines; this is not an XML verdict from either parser |

The tables use `both`, `semantic_part_both`, `xpact_only`, `core_only` and
`infrastructure_once` for these scopes. Benchmark reference rows use
`reference_only`; the older imported example uses `legacy_contributed`.
The two `implementation_probe` rows describe the separate step-1 executables:
their tiny XML obligation is shared, while build identity belongs to each
backend. Supplemental upstream tooling is identified separately in its row notes.

A shared case must not disappear because a backend currently lacks its API.
Later execution must report the missing integration boundary, an explicit
unsupported capability where established, or the observed failure. A known
failure remains a failure with an engine-specific explanation. Two equal
results are also insufficient unless they match the independent expectation.

Some existing tests assert xpact's exact diagnostic strings, private offsets,
helper methods or cache state alongside XML outcomes. Preserve those checks
locally. The future common contract must distinguish required error semantics
from implementation-specific wording and retain original diagnostics. Do not
trim text, reorder events or relax expected outcomes to manufacture agreement.

## Expansions and configuration dimensions

- The 54 registered Eiffel cases run in assertions off/on × workbench/finalized
  lanes. These are 54 identities in four configurations, not 216 distinct
  semantic scenarios. The 13 AutoTests are a separate ECF and executable.
  Across those 67 rows, 36 target both implementations directly, 16 require
  extraction of their semantic portion, nine exercise xpact internals, and six
  test infrastructure. Individual features can contain several documents,
  assertions or state transitions; preserve those subcases during extraction.
- The .NET catalog defines 41 byte inputs: seven C02 cases, four CR cases and
  five UTF-8 sequences in six contexts. Each input is combined with six callback
  sets. For a nonempty input of length `n`, the whole, every two-way split and
  bytewise plans total `n + 1`; empty input has one whole-input plan. The current
  catalog has 560 input/chunk plans and **3,360 expanded cases**. Preserve IDs
  `input/callback/whole`, `input/callback/split@k` and `input/callback/bytes`.
- The native catalog records 574 C check sites (20 ABI, 127 fake-bridge and
  427 real-DLL), 73 DLL input-table entries and eight lifecycle summaries that
  overlap those checks. It also records runtime/shim/CRC families, build probes,
  four pinned-core corpus tools and nine registered core helper/diagnostic IDs.
  The fake-bridge checks validate the shim with a simulated delegate, not the
  real Eiffel parser. Core's corpus tools compare with Expat through raw Eiffel
  events and do not establish behavior through its C dispatcher.
- The .NET pass gate checks verdicts and the enabled start/end/text observations
  on accepted documents. `ExpatError` is reference metadata, not an enforced
  error-code oracle; reported positions are not currently a position oracle.
  Its default-handler mode does not by itself establish default-text parity.
- W3C case IDs come from the pinned external catalog. Its current profile is
  XML 1.0 fifth edition, namespaces unless opted out, nonvalidating, no external
  entities, and binary verdicts only. Profile exclusions keep explicit reasons.
  Re-expand the catalog at execution time; historical result totals do not
  replace the selected catalog's case manifest.
- Upstream libexpat identities include source file and test name, plus the
  selected registration/configuration dimensions. Manifest expansion and a
  green/red parity file are not execution evidence. Retain allocator-injection
  exclusions separately from observed parser failures.
- Benchmark dimensions include input bytes, implementation, OS/compiler,
  build/assertions, callbacks, parser creation versus reuse, GC policy and
  chunk/API mode where present. A shared workload must do equivalent work.
  Functional lanes may execute concurrently in isolation; timed comparisons
  need the sequential paired method described in the benchmark catalog.

## Existing entry points and wiring gaps

| Entry point | Existing path | What remains for dual execution |
|---|---|---|
| `scripts/run_eiffel_test_matrix.ps1` | Direct xpact regression, four configurations | Extract shared cases and add a core runner; retain internal checks |
| `tests/xpact_autotest.ecf` | Thirteen generated test features | Shared semantic extraction and explicit CI coverage |
| `scripts/run_native_runtime_smoke.ps1`, `scripts/run_native_abi_tests.ps1` | Eiffel runtime, public C API and private fake-bridge checks | Separate public API parity from backend-specific installation/handle checks |
| `scripts/run_chunked_crc_corpus.ps1` | Seven generated XML documents, chunk schedules, direct/buffer API; optional libexpat reference | Core public API adapter and cross-engine event comparison |
| `scripts/run_incremental_shim_audit.ps1` | Native replay behavior and accounting audit | Share public event/lifecycle obligations; retain replay-specific work counters locally |
| `tests/dotnet/XpactDllTests` | Caller-selected DLL via `--dll`, isolated child processes | Real core DLL and per-engine orchestration; direct Eiffel smoke builds cannot substitute |
| `scripts/run_libexpat_adapter.ps1` | External manifest, expected-failure accounting and optional native execution | Core public API adapter; per-engine exclusions and observed result accounting |
| `scripts/run_benchmarks.ps1`, `scripts/run_wsl_benchmarks.ps1` | Existing Eiffel and libexpat/pyexpat lanes | Core benchmark CLI, matched workloads and explicit implementation dimension |
| `scripts/compare_eiffel_benchmarks.py` | Generic two-executable paired driver | Equivalent core executable; correctness qualification before comparisons |
| `scripts/run_large_xml_benchmarks.ps1` | Caller-supplied whole-file corpora | Core CLI; raw-byte and configuration-label audit before comparison |
| `scripts/run_contributed_examples.ps1` | Legacy imported parser and optional C counter | Keep legacy identity distinct; evaluate pinned core through its own adapter |
| `scripts/build_implementations.ps1` | Two isolated step-1 probes | Provides build viability/identity only; no common functional or benchmark CLI yet |

At the inventory snapshot, both Jenkinsfiles invoke the existing native and
libexpat harness paths, and W3C when benchmarks are enabled. The all-tests
pipeline runs the direct Eiffel regression matrix and offers the large XML
stage. Neither pipeline invokes the .NET DLL harness, AutoTest ECF, paired
comparison driver or step-1 probes. WSL Eiffel benchmarks are opt-in at this
snapshot; newer changes on another branch are not inventory evidence here.

GitHub Actions runs 76 of the 89 Python infrastructure methods by selecting the
W3C, WSL, paired-driver and implementation-build modules. The other 13 methods
belong to the three Windows libexpat harness modules selected by Jenkins.
Their native fixture prerequisites and runtime skips remain distinct from
parser pass/fail outcomes.

## Findings to carry into the next steps

- The large XML runner selects the assertions-off `xpact_benchmarks` target for
  both of its build modes, while its workbench label says contracts are enabled.
  Resolve that label/configuration mismatch before using it as an assertion-on
  comparison. This inventory does not change the runner.
- The direct benchmark's file path uses a text-file reader, whereas its
  conformance path uses raw bytes. Establish identical input-byte handling
  before comparing file workloads with core.
- `tests/python/run_w3c_conformance.py` is an older standalone duplicate of the
  canonical `scripts/run_w3c_conformance.py`; current entry points use the latter.
  Do not route a backend through the duplicate and lose engine-specific
  known-failure handling.
- The .NET harness has no `XML_ParseBuffer`, namespaces or stop/resume cases;
  its calls stay on the thread that loaded the DLL. Its crash isolation is not
  evidence of native cross-thread safety or coverage of all callback APIs.
- The native bridge and prototype/cache tests mix external behavior with private
  state. Preserve fail → reset → success → fail sequences and separately check
  release of buffers, handlers, handles and child processes when extracting
  those obligations. A harmless leftover entry is not evidence of cleanup.

## Verification and maintenance

The inventory is reconciled against the registered Eiffel names, generated
AutoTest features, Python unittest methods, native source check labels and
catalog expansion rules. Source references, TSV schemas and duplicate keys are
checked separately. No production parser, test expectation, runner behavior or
benchmark timing is changed by this step.

Support handlers, headers and ECF files are linked through the case rows rather
than counted as tests. Historical reports, old student result snapshots and
generated/downloaded build trees are not new suite registrations. The student's
seven-file event-trace baseline is a diagnostic evidence tool, not a pass gate;
its fixtures remain available under `student/baseline/event-trace/` for future
shared-case extraction.

When adding or removing a case, update its catalog row and recheck the source
registration/expansion. Keep original expectations separate from later observed
results. Adapter contract design and new runtime execution belong to steps 3
onward; the only runtime evidence carried forward from step 1 is its explicitly
limited build probes, documented in [Pinned implementation builds](implementation-builds.md).
