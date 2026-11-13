# XPact code-review TODO

This file records the implementation, testing, and performance work identified
during the July 2026 review. Items are ordered by risk and expected impact.
Correctness and trustworthy test results should be established before benchmark
numbers are used to guide lower-level optimization.

## Current disposition — 13 November 2026

The checklist below preserves the July review, including its unchecked boxes,
review-time observations and source line references. It is not a current list of
unfixed defects. Later work has superseded several findings; the linked reports
record the revisions and scenarios actually verified.

| July finding | Current implementation and evidence | Remaining boundary |
|---|---|---|
| Final-input shortcuts and malformed UTF-8 | [Parser repairs](reports/issue-0079/report.md) and [permanent regressions](reports/issue-0128/report.md) cover the reported incomplete, mismatched and malformed-byte inputs. The latter also records mutations that make the tests fail. | These checks do not establish every handler/chunk/encoding combination listed below. |
| `XML_Content` allocation and lifetime | `XP_NATIVE_CALLBACK_HANDLER.content_model_array` now allocates nodes and copied names in one block through the parser allocator, matching `XML_FreeContentModel`. | Allocation-failure propagation, retained-model lifetime tests and the broader allocator/memory-tool matrix remain unqualified here. |
| Test failures disappear with assertions off | Both Eiffel test runners use explicit nonzero exits; [B01](reports/issue-0045/report.md) and [B02](reports/issue-0046/report.md) record exit-status and deliberate-failure checks. | Those reports are dated evidence, not a fresh run of every current lane. GC-state probes do not qualify exception propagation through `execute_without_collection`. |
| Native-suite expected failures | The [adapter gate](adapters/libexpat/README.md) now parses individual failure names and rejects unexpected failures, crashes, inconsistent counts and incomplete runs. | An individual unexpected pass in a mixed failing run is not yet detected. |
| `XML_ParserReset` and reuse callbacks | The native implementation clears handlers/context, rejects child resets and preserves required configuration; the reuse benchmark re-registers callbacks. `xpact_bridge_smoke.c` covers these transitions. | The entire lifecycle/state matrix below is not claimed complete. |
| Position rescans and later materialization | [Parser profiling](docs/parser-profile-performance.md), [PubMed position work](docs/pubmed-position-performance.md) and [DOCTYPE work](docs/pubmed-doctype-performance.md) record the October fixes and their measured scope. | Native input copying, broader allocation work and scaling across all parser modes remain separate concerns. |
| Persistent incremental parsing | [Incremental-core](docs/incremental-core-prototype.md) and [Expat-port](docs/expat-port-spike.md) prototypes exist. | The production native shim still uses accumulated-buffer replay; the prototypes are not its replacement. |
| Comparable compiler benchmarks | [The WSL guide](docs/wsl-benchmarks.md) records the 13 November EiffelStudio/Gobo comparison, source identity, input and build settings. [Assertion qualification](docs/gobo-assertions.md) records fixed Gobo issues and the remaining literal-`ensure False` difference. | These direct parser timings do not qualify native DLL equivalence, every benchmark-plan item, or a new Jenkins job build. |

Use the [project overview](README.md), [native compatibility status](docs/libexpat-api-compatibility.md)
and [drop-in verification](docs/drop-in-verification.md) for the active scope.
Unmentioned July items remain historical investigation requests, not newly
confirmed defects or completed work.

## Historical July checklist

## P0: correctness and memory safety

### Prevent the native final-input shortcut from skipping validation

Relevant code:

- [`src/xp_native_parser.e`](src/xp_native_parser.e#L816)
- [`src/xp_native_parser.e`](src/xp_native_parser.e#L1077)

The direct-start-element path can emit the first start tag and treat it as the
completed parse without validating the rest of final input. During review, the
native DLL returned success with error code 0 for incomplete or mismatched XML,
including `<root>` and `<root><child></root>`.

- [ ] Disable direct prefix emission for final input until it is backed by a
      complete, resumable validator.
- [ ] Ensure an emitted start event never substitutes for parsing the remaining
      input.
- [ ] Add valid, incomplete, mismatched, and trailing-junk cases for start-only,
      end-only, start/end, character-data, and default-handler configurations.
- [ ] Exercise both final and non-final calls and every relevant chunk boundary.

Acceptance criteria: malformed final input must return the same status, error
code, and error position as the supported libexpat baseline.

### Fix `XML_Content` allocation and lifetime

Relevant code:

- [`src/xp_native_callback_handler.e`](src/xp_native_callback_handler.e#L1335)
- [`native/xpact_native.c`](native/xpact_native.c#L1161)

Content models are allocated with CRT `malloc`, contain pointers owned by
temporary Eiffel `C_STRING` objects, and are later freed through Expat's custom
allocator. This can produce dangling names and allocator-mismatch heap
corruption when `XML_ParserCreate_MM` is used.

- [ ] Allocate the model and copied names as one self-contained block through
      the parser's configured allocator.
- [ ] Propagate allocation failure as the appropriate Expat error.
- [ ] Test retaining and reading the model after the declaration callback.
- [ ] Test freeing it with a custom allocator and injected allocation failures.
- [ ] Run the native tests under ASan or Application Verifier.

### Validate UTF-8 as Unicode scalar values

Relevant code:

- [`src/xp_parser.e`](src/xp_parser.e#L2689)
- [`src/xp_parser.e`](src/xp_parser.e#L4440)
- [`src/xp_attributes.e`](src/xp_attributes.e#L220)

Current validation detects truncated sequences but accepts several malformed
forms because lead and continuation bytes are tested independently. Review-time
probes included lone continuation bytes, overlong encodings, bad continuation
bytes, and malformed bytes in names.

- [ ] Introduce one strict decoder returning a code point and byte width.
- [ ] Reject bad continuations, overlong encodings, surrogates, and values above
      U+10FFFF.
- [ ] Apply XML `Char`, `NameStartChar`, and `NameChar` rules to decoded code
      points rather than individual bytes.
- [ ] Differential-test malformed UTF-8 in text, names, attributes, comments,
      processing instructions, CDATA, and DTD content.
- [ ] Repeat each case with the sequence split at every byte boundary.

## P0: make failures observable

### Make every test lane capable of failing its process

Relevant code:

- [`tests/xp_test_root.e`](tests/xp_test_root.e#L55)
- [`tests/xpact_tests.ecf`](tests/xpact_tests.ecf#L6)
- [`tests/xp_native_runtime_smoke.e`](tests/xp_native_runtime_smoke.e#L32)

The assertions-off lane relies on a `check` instruction to signal accumulated
failures, but `check` is compiled out in that configuration.

- [ ] Exit unconditionally with a nonzero status after any recorded failure, or
      migrate the runner to a test framework with explicit failure reporting.
- [ ] Add a meta-test that deliberately fails and verify that every build lane
      reports a nonzero exit status.
- [ ] Keep both assertions-on and assertions-off lanes in CI.
- [ ] Investigate the current assertions-on failure of
      `final_finished_or_suspended` during the GC-suspension test.

### Make expected-failure accounting exact

Relevant code:

- [`scripts/run_libexpat_adapter.ps1`](scripts/run_libexpat_adapter.ps1#L401)
- [`adapters/libexpat/expected-failures.tsv`](adapters/libexpat/expected-failures.tsv)

The adapter currently accepts any failing `ctest` run whenever the expected
failure list is nonempty.

- [ ] Collect the actual failed test names.
- [ ] Require the actual and expanded expected-failure sets to be identical.
- [ ] Fail on unexpected failures and unexpected passes.
- [ ] Require every upstream test to match exactly one parity rule, with no
      overlapping or stale patterns.

### Reject invalid benchmark samples

Relevant code:

- [`benchmarks/xp_benchmark_root.e`](benchmarks/xp_benchmark_root.e#L42)
- [`scripts/run_benchmarks.ps1`](scripts/run_benchmarks.ps1#L51)

- [ ] Exit nonzero when any benchmark parse fails.
- [ ] Emit and validate structured results containing status, iteration count,
      parsed bytes, callback count, input hash, and semantic event checksum.
- [ ] Never publish timing from a failed or semantically different parse.

## P1: Expat compatibility and API state

### Implement exact `XML_ParserReset` semantics

Relevant code:

- [`native/xpact_native.c`](native/xpact_native.c#L228)
- [`benchmarks/xpact_native_c_benchmark.c`](benchmarks/xpact_native_c_benchmark.c#L166)

The current reset preserves handlers and user context, clears namespace-triplet
state, and can allow reset of a child parser. The reuse benchmark depends on the
preserved-handler behavior.

- [ ] Clear and preserve fields exactly as specified by Expat.
- [ ] Reject reset of subordinate parsers.
- [ ] Re-register benchmark callbacks after every valid reset.
- [ ] Test reset with handlers, user data, namespaces, triplets, base URI,
      external entities, suspension, and completed parsers.

### Complete the compatibility audit

- [ ] Parse an XML declaration using the XML grammar; do not treat
      `<?xml-stylesheet ...?>` as a declaration
      ([`src/xp_native_parser.e`](src/xp_native_parser.e#L1492)).
- [ ] Either implement allocation/amplification protection accurately or return
      unsupported instead of unconditional success
      ([`native/xpact_native.c`](native/xpact_native.c#L1291)).
- [ ] Preserve namespace separator, namespace handlers, and triplet mode in
      external-entity child parsers
      ([`native/xpact_native.c`](native/xpact_native.c#L910)).
- [ ] Test the complete initialized/parsing/suspended/finished state matrix for
      `XML_Parse`, `XML_GetBuffer`, `XML_ParseBuffer`, encoding changes, stop,
      resume, and reset.
- [ ] Make bridge uninstall reject live parsers or use ref-counted immutable
      bridge generations.

## Performance: remove the algorithmic cliffs first

### 1. Keep scan-position accounting monotonic

Relevant code:

- [`src/xp_parser.e`](src/xp_parser.e#L1837)
- [`src/xp_parser.e`](src/xp_parser.e#L5891)
- [`src/xp_parser.e`](src/xp_parser.e#L894)
- [`src/xp_parser.e`](src/xp_parser.e#L917)
- [`src/xp_parser.e`](src/xp_parser.e#L5862)

After the no-event scanner encounters `&`, `force_current_position` disables
lazy accounting. Each later closing tag moves the reported position from the
element name backward to `<`, which recomputes line and column by rescanning the
entire document prefix.

On the reviewed 504,561-byte PubMed document, 6,672 closing tags after the first
entity caused approximately 1,726,021,612 cumulative character visits: more
than 3,400 full-input equivalents. Review-time timings were approximately
6.86-7.79 seconds for XPact versus 0.096-0.101 seconds for warm pyexpat runs.

- [ ] Separate the monotonic tokenizer cursor from callback/error token
      positions.
- [ ] Store token-start byte, line, and column without moving the scan cursor
      backward.
- [ ] Calculate earlier locations only on query/error paths; consider a newline
      offset index if random position lookup is required.
- [ ] Consume predefined and numeric entity references in the no-event path
      without permanently forcing eager position tracking.
- [ ] Avoid realizing the final line/column position unless the caller asks for
      it.
- [ ] Add a counter for total bytes examined by position accounting and require
      O(N) growth for N/2N/4N inputs.

This is the first performance change to implement. Callback allocation should
not be blamed or optimized based on timings that still include these prefix
rescans.

### 2. Remove whole-buffer copies from the native bridge

Relevant code:

- [`src/xp_native_bridge_installer.e`](src/xp_native_bridge_installer.e#L376)
- [`src/xp_native_parser.e`](src/xp_native_parser.e#L776)
- [`src/xp_native_parser.e`](src/xp_native_parser.e#L829)

- [ ] For synchronous final parsing, expose a lifetime-scoped, pointer-backed
      byte source instead of copying C input into multiple Eiffel strings.
- [ ] Define ownership and reentrancy rules for stop/resume and callbacks.
- [ ] Count bytes copied and assert the expected value in fast-path tests.

### 3. Implement true incremental parsing

Relevant code:

- [`src/xp_native_parser.e`](src/xp_native_parser.e#L783)
- [`src/xp_native_parser.e`](src/xp_native_parser.e#L865)

Chunked native parsing currently accumulates and reparses the complete prefix on
every call, producing another O(N squared / chunk-size) path.

- [ ] Retain tokenizer state, element/entity stacks, decoder state, and only the
      unfinished-token tail between calls.
- [ ] Test chunk sizes 1, 64, 4096, and full-buffer over multiple document sizes.
- [ ] Record cumulative bytes decoded and parsed; require linear scaling.

### 4. Reduce residual callback and allocation overhead

Relevant code:

- [`src/xp_native_callback_handler.e`](src/xp_native_callback_handler.e#L654)

- [ ] Profile again after position tracking and input copying are fixed.
- [ ] Reuse per-parser scratch storage for encoded names, attribute pointer
      vectors, and managed buffers.
- [ ] Guard all diagnostic event construction when production diagnostics are
      disabled.
- [ ] Preserve synchronous Expat callback semantics; do not batch callbacks if
      that changes parser queries, stop/resume, or reentrant behavior.
- [ ] Keep token slices for documents with an external DOCTYPE when no loaded DTD
      declaration actually requires name/attribute materialization.

## Benchmark and regression plan

- [ ] Move steady-state timing inside each executable, after input loading and
      warm-up; report startup-inclusive timing separately.
- [ ] Use the same OS, compiler settings, Expat version, input bytes, and
      create/reuse lifecycle for every implementation.
- [ ] Add direct Eiffel tokenizer, direct Eiffel eventful, native tokenizer,
      native callback, and libexpat equivalents with the same semantic digest.
- [ ] Cover text-heavy, tag-heavy, attribute-heavy, namespace, DTD/entity,
      non-ASCII, large-token, valid, and malformed corpora.
- [ ] Benchmark multiple sizes and entity positions near 5% and 95% to expose
      nonlinear behavior deterministically.
- [ ] Calibrate repetitions to at least one second of in-process work; report
      median and dispersion rather than a single sample.
- [ ] Track input bytes, bytes copied, bytes reparsed, position-rescanned bytes,
      allocations, callback transitions, and peak retained input.
- [ ] Add the generated AutoTest suite to CI and add randomized/property-based
      differential tests against the supported libexpat version.
- [ ] Introduce a statistically tolerant CI regression gate only after benchmark
      correctness and reproducibility are established.

## Recommended implementation sequence

1. Fix final-input validation, `XML_Content` ownership, and UTF-8 validation.
2. Make all test and benchmark failures reliably observable.
3. Fix monotonic position accounting and establish linear-scaling counters.
4. Correct reset, namespace-child, parser-state, and security API semantics.
5. Remove native input copies and implement persistent incremental state.
6. Profile again, then optimize callback allocation and remaining materialization.
7. Establish stable performance-regression thresholds from the corrected
   benchmark suite.

