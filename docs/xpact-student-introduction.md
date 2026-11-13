# Xpact student introduction

A ten week university assignment

Prepared for a student who has completed one year of university study

Original assignment: 27 September 2026. Current-status review: 13 November 2026.

The W3C suite has now been run, and the repository includes pinned Xpact-core
builds plus shared catalog, W3C and chunked-regression lanes. Start with
[the current build map](implementation-builds.md), [W3C results](w3c-xml-conformance.md)
and [the student evidence index](../student/README.md). The task register below
preserves assignment IDs and proposed work; it is not a list of defects that
all remain open. Recorded results always belong to their stated revision,
compiler, profile and assertion mode.

## Your assignment

We are developing xpact, an XML parser written mainly in Eiffel. A parser reads structured text, checks whether it follows the rules of its format, and reports its contents to another program. Our aim is to offer an interface compatible with libexpat, an established XML parser, while using Eiffel contracts to make the implementation easier to check.

Your assignment is to help us build confidence in the parser through clear tests and reproducible results. The main question is: **How can we demonstrate that xpact handles valid and invalid XML consistently, with assertions enabled?**

You will learn the project, run examples, reproduce selected problems, and improve testing and verification with guidance. We do not expect prior knowledge of Eiffel, C interfaces, XML internals or performance measurement. These subjects can be learned as they become relevant.

## A useful outcome after ten weeks

- A setup guide that another developer can follow.
- A recorded baseline identifying the source revision, build settings and test commands.
- A focused collection of tests for malformed input, callbacks and input split into chunks, including selected W3C cases with recorded sources and expectations.
- One small, reviewed improvement to the test framework or verification scripts, or a well-supported explanation of a blocker with usable regression tests.
- A final report and demonstration explaining the findings and remaining work.

If time permits, extend coverage in the existing Xpact-core comparison lanes using the same inputs and independent expectations. Pinned builds and catalog, W3C and chunked-regression adapters are implemented; a core native DLL adapter, complete parser replacement and production release remain wider project work. Your contribution should be small enough to understand, explain and verify yourself.

## How to use this guide

Read the project explanation and first-week instructions before exploring the larger backlog. The ten-week plan is a starting point to agree with your supervisor. Adjust it to the university's learning outcomes and available study time. Later sections distinguish student-sized work from changes that need an experienced developer.

The project is still under development. A failing test can be a useful finding. Record what happened and ask for help understanding it; do not hide a failure to obtain a green result.

<!-- pagebreak -->

## Understanding the project

### A small XML example

```xml
<book id="7"><title>Hello</title></book>
```

Here, `book` and `title` are elements. The `id` attribute adds information to the book. `Hello` is text. An event-based parser reports events in order: start book, start title, text Hello, end title, end book. A callback is a function supplied by the application to receive one of these events.

The document `<book><title>Hello</book>` has mismatched tags. A parser should report an error. If the input ends after `<book>`, the result depends on whether the caller says more input will follow. An unfinished document can be acceptable temporarily, but must be rejected when the caller marks the input as final.

### Why chunks matter

A file or network message may arrive in pieces. For example, the first chunk could be `<bo` and the second `ok/>`. An incremental parser remembers enough state to continue correctly. The final result should agree with parsing the same bytes in one call, although the boundaries between text callbacks may differ.

Our production native adapter currently retains accumulated input and reparses it. Xpact-core has a more developed design for keeping parsing state and consuming completed input. That makes it a candidate for an integration experiment.

### Three names to keep separate

| Name | Role in this assignment |
| --- | --- |
| xpact | Our parser, native interface, build scripts and tests. This is the main working repository. |
| Xpact-core | A separately developed Eiffel parser. We are evaluating whether its incremental engine could be used within xpact. |
| libexpat | The reference implementation used to compare the supported API and parsing behavior. Use the agreed version, currently 2.8.1, for formal comparisons. |

### Where the code runs

A C application calls the exported `XML_Parse` function. The native bridge passes the request into Eiffel. The Eiffel parser checks the XML and sends events back through the callback adapter. Most XML rules belong in Eiffel; the bridge connects the two languages.

The public API describes the available functions. The ABI describes how compiled programs call those functions and exchange data. Matching function names alone does not prove compatibility: event contents, errors, memory ownership and parser state also matter.

<!-- pagebreak -->

## Contracts and unknown input

Eiffel supports Design by Contract. A **precondition** states what a routine expects from its caller. A **postcondition** states what it guarantees when it returns successfully. An **invariant** describes a condition that must hold at specified boundaries for an object's state. Runtime assertions check these conditions while the program executes.

For example, a parser may promise that successful completion leaves no unclosed elements. If the implementation reports success while that condition is false, a contract can reveal a programming error. Contracts only check the properties that have been written; they cannot prove every aspect of XML correctness.

### The direction for production builds

Our intended policy is to **keep assertions enabled in production**, including optimized builds, and make that exact configuration the required test and benchmark target. An optimized or finalized build does not have to disable assertions.

This direction has not yet been implemented throughout the build scripts. The current default tier named `Production` disables assertions, while a separate `Assertions` tier enables them. Updating the defaults, packaging, tests and documentation is an identified task. Record the configuration actually used, rather than relying on an artifact's name.

Assertions-enabled verification is the assignment's primary target. The proposed production policy has not replaced the current scripts: both assertion modes remain tested and the default native `Production` tier still disables assertions. Record that distinction when discussing release defaults or benchmark results.

### How failures are handled

| Situation | Expected treatment |
| --- | --- |
| Malformed XML, invalid UTF-8 or a resource limit exceeded | The parser explicitly validates the input and returns an appropriate error. |
| A violated internal contract | Treat it as a possible implementation defect. Preserve a reproduction and investigate the cause. |
| A test's expected result differs from the actual result | The test run must report failure and return a nonzero process exit status. |

Unknown input makes explicit validation essential. Assertions add checks on the implementation; they do not replace the parser's normal error handling. Failures at the C and Eiffel boundary also need deliberate handling so that an affected parse cannot continue as if it succeeded. Changes to that behavior need experienced review.

### Your role

Use assertions-enabled builds for the main assignment. When a contract fails, save the smallest input that reproduces it, the exact command, the source revision and the error output. Discuss whether the parser, the contract or the test expectation needs correction. Do not disable a contract simply to make the test pass.

<!-- pagebreak -->

## Getting started

### Your first working session

Ask your supervisor to walk through one successful parse and one rejected document. Locate the test that checks each result. Then change a small XML input and predict the outcome before running it. This gives you a concrete example to connect to the larger codebase.

Use a separate Git branch for your assignment. Learn to inspect changes, make a small commit and read a diff before changing parser internals. Keep a short work log of questions, commands, results and decisions.

### Tools and the first build

The current native build path uses Windows, PowerShell, EiffelStudio and Microsoft C++ build tools. Git records source changes. Your supervisor should help you obtain a working compiler environment before you troubleshoot parser behavior.

From the repository root, in a shell prepared for the compiler tools, the existing commands below select assertions explicitly. A command finishing is not proof that all tests passed: save the output and inspect failures with your supervisor.

```powershell
.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode On -BuildMode Workbench
.\scripts\run_eiffel_test_matrix.ps1 -AssertionMode On -BuildMode Finalized
.\scripts\build_native_eiffel.ps1 -BuildTier Assertions
```

The native command creates the separate assertions-enabled library. The test harness must link to or load that library when it is the subject of a test. Confirm this with the supervisor; some scripts still default to the assertions-off artifact.

### A short map of the repository

| Start here | What to look for |
| --- | --- |
| `README.md` and `docs/design-overview.md` | Project purpose and the connection between the Eiffel parser and C interface. |
| `tests/xp_test_root.e` | Small parser examples and the custom test runner. |
| `src/xp_parser.e` and `src/xp_event_handler.e` | XML parsing and the events delivered to applications. |
| `src/xp_native_parser.e` and `tests/native/` | Chunk handling and tests through the C interface. |
| `scripts/` and `adapters/libexpat/` | Build commands, test automation and comparison with Expat. |
| `TODO_CODE_REVIEW.md` | Detailed existing findings and acceptance criteria. |

Record the Git commit, compiler version, assertion settings, command, loaded library and exit status for your first baseline. If the build is blocked, describe the exact failing step; a documented environment problem is preferable to silently using an old binary.

<!-- pagebreak -->

## A proposed ten week plan

Agree the scope with your supervisor at the beginning and review it each week. This is the original proposed schedule, not a current completion checklist. Testing and verification are the required work; extending the already implemented Xpact-core lanes is optional. See the dated work and current-status links in [the student plan](../student/PLAN.md).

| Week | Main activity | Evidence to bring to review |
| --- | --- | --- |
| 1 | Learn basic XML, the project structure and Git workflow. Build with help. | Setup notes and one successful example parse. |
| 2 | Follow parser events and run the assertions-enabled tests. | Baseline log with revision, configuration, commands and known failures. |
| 3 | Learn how the test runner reports failure. Reproduce a deliberately failing test. | A bounded failure-reporting fix or a precise proposal with evidence. |
| 4 | Design small regressions and select 50–100 applicable W3C XML cases with your supervisor. | An input matrix with reviewed expected outcomes. |
| 5 | Run selected small inputs with different callbacks and chunk boundaries. | Repeatable regressions and small bug reproductions. |
| 6 | Pair on one manageable test-framework or verification-script improvement. | Before-and-after results and a reviewed change. |
| 7 | Compare xpact and libexpat; expand to more applicable W3C cases as time permits. | A table of matches, differences and untested cases. |
| 8 | Consolidate results and add selected SVG or libxml2 cases. Core integration remains optional. | Shared fixtures and comparison output, or documented integration requirements. |
| 9 | Analyse results and draft the report. Try selected PubMed files if correctness checks permit. | Draft report and result tables tied to specific builds. |
| 10 | Demonstrate the work, address review comments and hand it over. | Final report, tests, code or proposals, setup guide and follow-up list. |

### Keep the work achievable

At the end of week 2, select one main improvement and a small input set. At the end of week 5, review what can realistically be completed. Reserve weeks 9 and 10 for explanation, review and handover.

Parser repairs remain the responsibility of experienced developers; your main contribution is tests, clear reproductions and verification of reviewed fixes. Use the existing Xpact-core adapters where their boundaries fit the chosen case, and document missing capabilities instead of treating the core native interface as already integrated.

A suggested weekly update is half a page: what you tried, what the evidence shows, what is blocked and what you will do next. Agree the university's required report format and supervision arrangements at the start.

<!-- pagebreak -->

## XML collections for verification

A corpus is a collection of inputs used for repeatable tests. Start with the W3C XML conformance suite: it provides descriptions and expected behavior for specific XML rules. Add varied real documents after the initial tests work. Large documents are useful for streaming and memory measurements, but many similar records do not provide the same coverage as different syntax cases.

### Recommended collections

The following counts were checked on 27 September 2026. Pin each downloaded release or source revision so that another developer can obtain the same inputs.

| Collection | Verified scale | Purpose and recommended order |
| --- | --- | --- |
| [W3C XML suite](https://www.w3.org/XML/Test/) | 2,585 active test cases | Start here for syntax, encodings, entities and namespaces. Includes cases that must be rejected. |
| [Xpact-core fixtures](https://github.com/andersoxie/Xpact-core/tree/9fe21cc66897a9a5b2160ab4344802bdecc2898c/tools/data) | 44 assets across data and data-large | Use selected regressions. Includes dependencies, malformed input and entity-expansion cases. |
| [W3C SVG suite](https://www.w3.org/Graphics/SVG/Test/20110816/) | 433 test entries | Add document variety. These are rendering tests; their expected pictures do not specify XML parser results. |
| [libxml2 inputs](https://github.com/GNOME/libxml2/tree/master/test) | Eligible count not measured | Add selected parser regressions. Exclude unrelated HTML, schema, XPath and expected-output files. |
| [PubMed baseline](https://ftp.ncbi.nlm.nih.gov/pubmed/baseline/) | 1,334 compressed XML files | Select a few for large-file tests after correctness checks. The full baseline is unnecessary for this assignment. |
| [DBLP snapshots](https://dblp.org/xml/release/) | About 1 GB compressed for the live dataset when checked | Optional later streaming stress test. Pin a dated snapshot. |

### What the Xpact core results mean

Xpact-core's 44 checked-in assets total about 6.9 MB. Its separate report of 152,335 passed comparisons comes mainly from files on the author's Linux and Windows machines. That collection is not included in the repository, and a matching rejection also counts as a successful comparison. Treat the report as historical evidence, not as a downloadable set of 152,335 unique valid documents.

### Start with a manageable subset

As a D1 beginner activity, inspect the inventory and identify inputs, dependencies and expected outputs. This prepares task G01. With your supervisor, choose 50–100 applicable W3C cases, including accepted and rejected inputs. Mapping their expectations and comparing xpact with Expat are D2 guided activities under G01 and G03. Expand only when the results are understandable and repeatable.

Keep source notices with fixtures. One Core fixture has a GPLv2+ notice; the repository's MIT label does not describe every asset. Record download sources and hashes instead of committing large datasets. The detailed research and provenance are in `docs/xml-validation-corpora.md`.

<!-- pagebreak -->

## Using the XML collections

### The prepared W3C collection

The W3C 20130923 ZIP has been downloaded and extracted, preserving the original bytes and directory structure. The 1.5 MB archive contains 3,078 `.xml` files, including catalogs and expected outputs. Its 2,585 active catalog cases comprise 812 valid, 242 invalid, 1,498 not-well-formed and 33 optional-error cases. Those are inventory counts before profile selection. The suite has since been executed: the [28 October integrated run](../reports/latest-2026-10-28/README.md) recorded 2,283 checked verdicts plus 302 no-crash-only outcomes per finalized assertion mode, with no failures, errors or skips. The [W3C guide](w3c-xml-conformance.md) separates the current profile, all-cases extension and earlier failures.

Paths below are relative to the repository root. The `build` directory is ignored by Git, so another checkout needs the download and setup steps.

- Extracted catalog directory: `build/validation-corpora/w3c-xml-20130923/xmlconf/`.
- File inventory: `build/validation-corpora/w3c-xml-20130923/inventory.json`.
- Downloaded archive: `build/comparison/xmlts20130923.zip`.

### Read the expected outcome correctly

The [W3C test matrix](https://www.w3.org/XML/Test/xmlconf-20130923.html) distinguishes well-formed XML from XML that also satisfies DTD validity rules. Expat is a nonvalidating parser: it checks XML syntax without requiring DTD validity.

| Catalog type | Expected treatment for the supported nonvalidating configuration |
| --- | --- |
| valid | Accept applicable cases and check reported content. |
| invalid | Normally accept: the XML is well formed but violates DTD validity rules. |
| not-wf | Reject, subject to the catalog's external-entity requirements. |
| error | Detection is optional; do not impose one universal accept or reject result. |

Select XML version, edition, namespace mode and external-entity policy from the catalog. Exclude unsupported XML 1.1 cases from an XML 1.0 conformance score and explain every skip. Preserve local dependencies and disable network entity resolution. The root catalog has a misencoded comment; its import needs a documented accommodation, described in the corpus note. Do not silently rewrite test input bytes.

### Comparing engines and testing large files

Keep assertions enabled for the main student verification. Under G03, compare xpact and Expat through both parse APIs with recorded callback and chunk settings. Count accepted, rejected, skipped, crashed, timed-out and not-run cases separately. A correct rejection passes a negative test. Save mismatch traces and require every selected engine to run. F02 now has implemented direct Eiffel comparison lanes; extending them to more fixtures or the native DLL boundary remains optional D3 work.

For later D3 large-file work, `build/large-xml-corpus/` already contains `pubmed26n0001.xml` at about 195 MB, `pubmed26n1380.xml` at about 10 MB and a derived sample of about 0.5 MB. Use practical chunk sizes for these files; reserve one-byte chunks for small fixtures. Record the sample's parent and extraction method. Apply G07 and G09 to comparable runs with elapsed time, completed parses and peak memory. Preserve the data sources and their usage notices.

<!-- pagebreak -->

## Tasks identified in our implementation

The following sections summarize the original review priorities and their current disposition. The complete task register preserves every task's identifier and difficulty; it does not mark all of them as still open. P0 denotes correctness or test reliability; P1 denotes compatibility or performance. Priority and difficulty are different. The assertion policy awaits implementation. See [the review disposition](../TODO_CODE_REVIEW.md#current-disposition--13-november-2026) for evidence and remaining boundaries.

### Assertions enabled in production

Update build defaults, release packaging, CI and benchmark scripts to use the assertions-enabled production configuration. CI means automated checks run when code changes. Make the documentation describe the same policy. A student can inventory and test the settings; an experienced developer should approve release and exception-handling changes.

### P0 reliable test and benchmark outcomes

Make every recorded test failure produce the documented failure status. The upstream native-suite runner now extracts actual failing names and checks the expected-failure list, rejecting unexpected failures, incomplete runs and crashes. Audit this existing behavior before proposing B04 work; see [the parity gate](libexpat-parity.md). Reject benchmark results from failed or semantically different parses. A bounded remaining failure-reporting gap can still be suitable student work.

### P0 malformed final input and UTF8

The original review found final-input validation and malformed UTF-8 defects. Later parser repairs and permanent regressions cover the reported incomplete, mismatched and malformed-byte inputs; see [the repair report](../reports/issue-0079/report.md) and [regression evidence](../reports/issue-0128/report.md). Broader combinations of XML context, handlers and split sequences still need their own evidence.

Earlier probes of an existing June DLL accepted `<root>` and `<root><child></root>` with a start handler, and accepted malformed UTF-8. Source inspection found corresponding faulty paths. Reproduce these cases against a fresh, identified build before reporting current results. The student can own reproductions and tests; decoder design needs experienced review.

### P0 content model memory ownership

An `XML_Content` model describes an element's allowed content. The implementation now owns its nodes and copied names in one block allocated through the parser allocator. Allocation-failure propagation and the broader retained-model/custom-allocator test matrix remain unqualified here. Review those boundaries with an experienced developer, with supervised student test support.

### P1 API behavior and parser state

Reset now clears handlers and context, rejects child resets and preserves required configuration; reuse benchmarks re-register callbacks, and bridge smoke tests cover those transitions. The complete state matrix remains broader: check namespace inheritance, XML declaration recognition, encoding changes, stop and resume, buffer APIs, security settings and bridge removal with live handles. Start student work with one narrow, reproducible case.

### P1 repeated work and memory use

October profiling and position/materialization fixes are documented in [the performance history](performance-analysis.md). Extend scaling checks across parser modes rather than assuming the original rescan defect still reproduces. Native input copies and whole-prefix replay remain broader work; isolated incremental prototypes exist but are not the production shim. Large parsing-engine changes remain outside the student's minimum scope.

<!-- pagebreak -->

## Tasks involving Xpact core and comparison

### The optional student extension

Xpact-core is already available through [pinned builds](implementation-builds.md), the [catalog lane](dual-catalog-lane.md), the [W3C lane](dual-w3c-lane.md) and the [chunked regression lane](dual-regression-lane.md). Extend those adapters and shared fixtures where needed. Mark unsupported features explicitly, retain pinned-core failures, and compare with independent expectations and libexpat where applicable.

The implemented lanes provide documented commands and a pinned Xpact-core build for their subsets. They do not replace xpact's production parser or complete the core native ABI. Attempt further integration only after the main verification deliverables are stable, with supervisor help for the adapter boundary.

### The wider integration roadmap

Xpact-core's current source contains incremental parsing, DTD processing, namespaces and encoding codecs; parts of its README describe an older state. It offers useful scanner and buffer ideas. We should evaluate it behind our existing interface before deciding on adoption.

An experienced developer should lead a small optional backend using `XT_XML_PARSER_BASE` and raw events. The higher-level `XT_XML_PARSER` trims and collects text, which can change the content expected by Expat callers. Pin the dependency to a known commit and resolve the differing private parser structures before sharing memory.

### Findings to address before integration

- Correct the character-data dispatcher to use the supplied buffer, and save the index needed to restore temporarily inserted NUL bytes.
- Complete missing default, external-entity, skipped-entity and other callbacks; establish position reporting and stop/resume behavior.
- Restore the caller's garbage-collector state on every exit path, including errors and abandoned streams.
- Test encoding boundaries, especially split byte-order marks, odd UTF-16 chunks, surrogate pairs and both byte orders.
- Define limits for large tokens, deep entities and growing name caches; examine predictable name-hash collisions.

These are findings from source review, not reproduced Xpact-core runtime results. The student's role can be to document a small case or run a reviewed test. Native pointers, shared layouts, memory lifetimes and garbage-collector changes need experienced ownership.

### The shared validation work

Use the same harness to compare libexpat 2.8.1, current xpact and an integrated candidate. A harness is the program or script that runs tests and records results. Compare success or failure, errors, positions and event content and order. Allow only the callback segmentation differences permitted by the API.

Extend the existing CRC infrastructure rather than start over. CRC is a compact checksum of event data; it helps find differences but is not a complete proof of compatibility. The current Jenkins CRC lane checks xpact across chunks without necessarily comparing another engine. Xpact-core's corpus checks bypass its new C dispatcher, so native tests remain necessary.

<!-- pagebreak -->

## Performance and project terminology

Only compare timings after the agreed correctness checks pass. Use identical inputs, callback work, lifecycle, machine and build settings. Record throughput, peak memory and bytes copied or reparsed. Historical speed claims are not a fresh comparison between these implementations.

Later work includes a reproducible Linux Eiffel-backed library, broader compiler and consumer ABI coverage, replacement testing in a real Expat-using application, an allocator-compatibility decision, AutoTest and fuzzing in CI, and measured performance-regression limits. Student stretch work could add chunk cases or automate results. Adoption and release decisions remain with the project maintainers.

### Terms you will meet

Use this as a reference while reading the backlog. You do not need to master every term before starting the assignment.

| Term | Meaning in this project |
| --- | --- |
| Test fixture | A saved input and the setup needed to run a repeatable test. |
| Regression test | A test retained to catch a previously discovered problem if it returns. |
| Differential testing | Give the same input to different implementations and compare their results. A difference needs investigation before it is called a defect. |
| Fuzzing | Automatically generate or change inputs to find unexpected behavior. Save the inputs and seeds needed to reproduce failures. |
| Unicode and UTF | Unicode identifies characters. UTF-8 and UTF-16 encode them as bytes. A chunk can end partway through an encoded character. |
| DTD and entity | A DTD declares XML names, attributes or entities. An entity is named replacement content; expansion can increase the amount of work. |
| Namespace | A way to distinguish XML names that belong to different vocabularies, using namespace identifiers and optional prefixes. |
| CDATA | An XML section where most characters that normally begin markup are treated as ordinary text. |
| Garbage collector or GC | Runtime machinery that reclaims managed memory no longer needed. Disabling it changes runtime behavior and needs careful restoration. |
| Pointer and NUL byte | A pointer refers to a memory location. A NUL byte has value zero and often marks the end of a C string. |
| Allocator and lifetime | An allocator obtains and releases memory. Lifetime describes how long that memory remains valid for its users. |
| Token and slice | A token is a recognized piece of XML, such as a tag. A slice refers to part of an existing buffer instead of copying it. |
| Reentrant callback | A callback that calls into parser-related code while another parse call is still active. Shared state must remain consistent. |
| Parity and CI | Parity means agreement on defined behavior. Continuous integration, or CI, runs automated checks when code changes. |

<!-- pagebreak -->

## Working method and handover

### One issue at a time

Start with a small input and a written expectation. Run it against an identified build. If it fails, reduce the input while preserving the failure. Add a regression test and discuss the cause. Review any required parser repair with its developer, then rerun the focused tests and affected existing checks. Keep your own changes concentrated on tests and verification.

For each result, keep the input or its hash, source revision, compiler and assertion settings, callback configuration, chunk sizes, expected and actual outcomes, command and exit status. Separate confirmed observations from possible explanations. A green manifest or a count of test definitions is not evidence that those tests passed.

### A first test matrix

| Input or case | Expectation when input is final |
| --- | --- |
| `<root/>` | Accepted. Start and end events are delivered if requested. |
| `<root>` | Rejected because the document is incomplete. |
| `<root><child></root>` | Rejected because the end tag is mismatched. |
| Invalid UTF-8 inside text | Rejected as invalid input. Store exact bytes, not a lossy text copy. |

Repeat selected cases without callbacks and with start, end and text callbacks. Try the whole input and small chunks. In a short fixture, testing every possible split position helps reveal boundary errors. Keep malformed-input and fuzz tests bounded; agree resource limits with your supervisor.

### Completion and the university report

The minimum outcome is a reproducible baseline, an agreed regression set, one reviewed contribution or demonstrated blocker, and a clear handover. A useful report explains the question, background, method, results, limitations and next steps. Include commands and input identifiers so another person can check the work. Discuss what you learned as well as what changed.

The wider roadmap remains: stronger coverage; remaining xpact correctness fixes; extending the implemented Xpact-core comparisons to missing boundaries; three-way compatibility tests; and fair performance measurement. Assertions-enabled production remains a proposed policy; current native production defaults and each benchmark's actual assertion settings must be stated explicitly.

### Reading and source references

1. xpact repository and onboarding: https://github.com/andersoxie/xpact. Start with `README.md`, `docs/design-overview.md` and `docs/test-matrix.md`.
2. Existing backlog: `TODO_CODE_REVIEW.md`. Comparison reviewed local commit `d2b75ede229d3ce03adf48fe5811ea4ae1dfb566`.
3. Xpact-core source: https://github.com/andersoxie/Xpact-core/tree/9fe21cc66897a9a5b2160ab4344802bdecc2898c. Read the actual source alongside its README.
4. Expat reference source: https://github.com/libexpat/libexpat/tree/R_2_8_1. Use the supervisor's pinned build for comparisons.
5. Eiffel contract introduction: https://www.eiffel.org/doc/eiffelstudio/I2E-_Design_by_Contract_and_Assertions.
6. XML corpus research, sources and download details: `docs/xml-validation-corpora.md`.

<!-- pagebreak -->

## Complete task register

These 63 task definitions cover the earlier code review, implementation comparison, assertions policy and XML corpus work. They preserve assignment IDs, not current completion status: for example, pinned core builds, comparison lanes and native-suite failure-name checks now exist. Check the linked implementation guides and dated [student plan](../student/PLAN.md) before selecting remaining work. Historical failures need reproduction; completing all 63 tasks is outside the ten-week assignment.

### Difficulty and student responsibility

| Level | Meaning |
| --- | --- |
| D1 Beginner | Read, run prepared examples, document and report. Suitable early independent work after orientation. |
| D2 Guided | Write bounded tests, scripts or analyses with review. The main level for the student's contribution. |
| D3 Advanced | Significant comparison design, parser knowledge or integration. An experienced developer guides the work closely. |
| D4 Expert | Native memory, runtime, security or major parser-state changes. An experienced developer owns the implementation. |

Difficulty describes the complete task, not the student's ability. For D3 and D4 tasks, a useful D2 contribution may be a fixture, reproduction or verification of a reviewed fix. A03 concerns the production policy; F02 is the optional student extension. Other integration and release tasks provide context for later work.

### A Orientation and assertion policy

| ID | Level | Task and completion evidence |
| --- | --- | --- |
| A01 | D1 | Learn XML events, contracts, Git and the repository layout. Trace one accepted and one rejected document to the corresponding test and parser path. |
| A02 | D2 | Reproduce fresh assertions-enabled workbench and finalized builds. Record tool dependencies and blocked steps; produce setup instructions another developer can follow. |
| A03 | D3 | Make assertions-enabled finalized builds the production default. Align ECF configuration, scripts, artifact names and selection, packaging, CI, benchmark defaults, examples and documentation. |
| A04 | D2 | Verify the actual library loaded by tests, benchmarks and packaged examples. Test both workbench and finalized assertion-enabled builds and every other configuration still supported. |
| A05 | D4 | Define C and Eiffel boundary failure handling. Invalid input must produce parser errors; internal contract failures must not leave an affected parse continuing as successful. |
| A06 | D1 | Maintain revision, configuration, input, command and result records, weekly notes and minimized reproductions. Deliver the university report, demonstration, setup guide and handover. |

### B Reliable results

| ID | Level | Task and completion evidence |
| --- | --- | --- |
| B01 | D2 | Make accumulated failures in the main and native runtime test runners return nonzero process status, independently of Eiffel check instructions. |
| B02 | D2 | Add deliberately failing meta-tests. Verify failure propagation through every supported build and assertion configuration and its CI wrapper. |
| B03 | D3 | Reproduce and resolve the final_finished_or_suspended contract failure reported during GC-suspension testing. Determine whether code, contract or test is wrong without suppressing the check. |
| B04 | D2 | Extract actual failed upstream test names. Require exact agreement with expanded expected failures; reject unexpected failures and passes. Report crashes and incomplete runs separately. |
| B05 | D2 | Require each upstream test to match exactly one parity rule. Reject missing coverage, overlapping rules and stale expected-failure patterns. |
| B06 | D2 | Make benchmark executables fail when parsing fails. Prevent publication of timing from failed or semantically different parses. |
| B07 | D2 | Emit and validate structured results with parse status, completed iterations, parsed bytes, callback count, input hash and semantic event checksum. |

### C Parser correctness and memory safety

| ID | Level | Task and completion evidence |
| --- | --- | --- |
| C01 | D3 | Disable the unsafe final-input prefix shortcut until complete resumable validation exists. An emitted start event must never substitute for parsing the remaining input. |
| C02 | D2 | Add valid, incomplete, mismatched and trailing-junk cases. Cover no callbacks, start-only, end-only, paired element, character-data and default-handler configurations. |
| C03 | D2 | Repeat final-input regressions with final and non-final calls and relevant chunk boundaries. Compare status, error code and position with the pinned Expat baseline. |
| C04 | D4 | Allocate XML_Content nodes and copied names as self-contained storage through the configured parser allocator. Remove borrowed temporary names and allocation/free mismatches. |
| C05 | D4 | Propagate content-model allocation failure through the correct parser error path. Verify cleanup when allocation fails partway through. |
| C06 | D3 | Test retaining and reading models after callbacks, freeing with a custom allocator and injected allocation failures. Student fixture work requires supervision. |
| C07 | D3 | Run native ownership and lifetime tests under AddressSanitizer or Application Verifier. Retain diagnostics and use them to verify reviewed repairs. |
| C08 | D4 | Introduce one strict UTF-8 decoder returning a Unicode scalar value and byte width. Reject bad continuations, overlong encodings, surrogates and values above U+10FFFF. |
| C09 | D3 | Apply XML Char, NameStartChar and NameChar rules to decoded code points consistently in parsing, attributes and name validation. |
| C10 | D2 | Differential-test malformed UTF-8 in text, names, attributes, comments, processing instructions, CDATA and DTD content. Split multibyte sequences at every byte boundary. |

### D API compatibility and state

| ID | Level | Task and completion evidence |
| --- | --- | --- |
| D01 | D3 | Implement exact XML_ParserReset preservation and clearing rules. Reject reset of subordinate parsers. |
| D02 | D2 | Re-register benchmark callbacks after valid reset. Test handlers, user data, namespaces, triplets, base URI, external entities, suspension and completed parsers. |
| D03 | D3 | Parse XML declarations using the XML grammar. Distinguish xml-stylesheet and other processing instructions from the XML declaration. |
| D04 | D4 | Implement allocation and amplification protection accurately or report unsupported behavior. Remove success responses that promise ineffective protection. |
| D05 | D3 | Preserve namespace separator, handlers and triplet mode in external-entity child parsers. Verify inheritance through callback results. |
| D06 | D3 | Test initialized, parsing, suspended and finished states for Parse, GetBuffer, ParseBuffer, encoding changes, stop, resume and reset. |
| D07 | D4 | Make bridge uninstall safe while parser handles exist. Reject unsafe removal or use immutable reference-counted bridge generations with defined lifetime rules. |

### E Parsing work and memory use

| ID | Level | Task and completion evidence |
| --- | --- | --- |
| E01 | D3 | Separate the forward tokenizer cursor from callback and error locations. Store token-start byte, line and column without moving the scan cursor backward. |
| E02 | D3 | Calculate earlier positions only on query or error, considering a newline index. Keep predefined/numeric entities from forcing eager tracking; defer final position calculation until requested. |
| E03 | D2 | Count bytes examined by position accounting. Test N, 2N and 4N inputs; doubling the input should roughly double the work, rather than repeatedly rescanning prefixes. |
| E04 | D4 | Introduce lifetime-scoped pointer-backed input for synchronous final parsing. Define ownership, reentrancy, callback and stop/resume rules before removing copies. |
| E05 | D2 | Count bytes copied through the native bridge. Check expected copy counts in eligible fast-path tests. |
| E06 | D4 | Replace prefix replay with persistent tokenizer, decoder, element/entity stacks and unfinished-token state. Test chunks 1, 64, 4096 and full input; require linear decoded/parsed-byte counts. |
| E07 | D3 | Profile again after position and copying repairs. Reuse per-parser encoded-name, attribute-pointer and managed-buffer storage where measurements justify it. |
| E08 | D3 | Avoid constructing disabled diagnostics. Preserve synchronous callbacks, queries, stop/resume and reentrancy. Retain token slices with external DOCTYPE when declarations do not require materialized values. |

### F Xpact core investigation and adapters

| ID | Level | Task and completion evidence |
| --- | --- | --- |
| F01 | D2 | Pin and reproduce the Core build. Document compiler, XPACT_CORE, XPACT_INCLUDE, Eiffel-Loop, zlib and reference dependencies. Distinguish native Windows builds from Linux scans of Windows files. |
| F02 | D3 | Optional student extension with guidance: add a Core runner for common element/text, accepted/rejected and chunk cases. Reuse the shared corpus manifest, expectations and result format; label unsupported features. |
| F03 | D3 | Map supported events, APIs, errors, positions and limits. Prototype any future production adapter using the raw parser base; prevent higher-level text trimming from changing Expat behavior. |
| F04 | D4 | Resolve incompatible private parser structures before sharing pointers. Define ownership and lifetime between our bridge, Core buffers and C-backed strings. |
| F05 | D4 | Reproduce and repair the reviewed character-data buffer and temporary-NUL restoration-index issues. Add native callback regressions. |
| F06 | D3 | Audit and complete missing default, external-entity, skipped-entity and other callbacks. Establish position and stop/resume behavior in a candidate native adapter. |
| F07 | D4 | Restore the caller's original GC state after completion, parse errors, exceptions and abandoned streams. Verify nested and early-exit paths. |
| F08 | D3 | Verify split byte-order marks, odd UTF-16 chunks, surrogate pairs and both byte orders. Retain exact byte fixtures and minimized differences. |
| F09 | D4 | Define and test limits for large tokens, deep or expanded entities and growing name caches. Investigate predictable name-hash collisions and resource exhaustion. |

### G Shared verification and measurement

| ID | Level | Task and completion evidence |
| --- | --- | --- |
| G01 | D2 | Build a portable corpus manifest with sources, versions, hashes, dependencies and expectations. Start with W3C and Core cases; cover text-, tag- and attribute-heavy inputs, namespaces, encodings, DTD/entities and large tokens. Add SVG and libxml2 cases. |
| G02 | D3 | Define comparable results for xpact, Core and Expat 2.8.1: status, errors, positions, ordered events and attributes. Normalize only callback segmentation permitted by the API. |
| G03 | D2 | Compare engines through Parse and ParseBuffer across chunks. Map W3C expectations by parser configuration; reconcile accepted, rejected, skipped and failed totals. Require every selected engine and expected row; save traces. Retain native API tests. |
| G04 | D2 | Add the generated AutoTest suite to CI. Report executed outcomes separately from test-definition and manifest counts. |
| G05 | D3 | Add bounded randomized and property-based differential tests. Save seeds and exact bytes, minimize failures and promote useful cases into deterministic regressions. |
| G06 | D2 | Measure steady-state work inside executables after loading and warm-up. Report startup-inclusive timing separately and verify completed iterations before using a sample. |
| G07 | D3 | Compare equivalent direct Eiffel and native tokenizer/callback modes, including selected PubMed inputs after correctness checks. Align OS, compiler settings, assertions, bytes, Expat version, lifecycle and semantic digest. |
| G08 | D2 | Generate N, 2N and 4N inputs with entities near 5 and 95 percent of the document. Use equal callback work and chunk settings to expose nonlinear behavior. |
| G09 | D2 | Calibrate at least one second of in-process work; verify completion. Report median, dispersion, copied/reparsed/position-scanned bytes, allocations, callback transitions and retained-input or peak memory. Large-corpus analysis needs D3 guidance. |
| G10 | D3 | Add statistically tolerant CI performance thresholds only after correctness and reproducibility pass. Publish revision, toolchain, input metadata and limitations with results. |

### H Later platform and release work

| ID | Level | Task and completion evidence |
| --- | --- | --- |
| H01 | D4 | Build and package an Eiffel-backed Linux libxpact.so with assertion, ABI and native-suite checks. The existing bridge-only WSL library does not complete this task. |
| H02 | D3 | Broaden compiler, build-system and consumer ABI coverage. Produce repeatable packages with identified configurations, dependencies, headers, binaries and checksums. |
| H03 | D3 | Test replacement in a real application, such as CPython. Keep separate reference and xpact runs; archive source revisions, patch, library checksum and test logs. |
| H04 | D4 | Decide and document allocation-hook compatibility. Implement promised semantics or narrow support explicitly; excluded injection tests do not excuse unsafe allocation/free ownership. |
| H05 | D4 | Investigate later managed Eiffel or .NET and Python-facing adapters after native correctness and lifecycle support are stable. Define supported configurations and tests before claiming availability. |
| H06 | D3 | Decide on Core adoption and release using conformance, memory, scaling, performance and consumer evidence. Retain separate implementations if integration does not meet the agreed criteria. |

### Suggested student selection

Start with A01, A02, A04 and A06. Choose B01 and B02 as a small framework improvement, then focus on C02, C03 and a bounded part of C10. Use G01 and G03 for a reviewed W3C subset and xpact versus Expat comparison. Add SVG, libxml2 or selected PubMed files as progress permits. B04 or B05 is an alternative if failure accounting is most useful. F01 and F02 remain optional. Narrow this selection with your supervisor.

The register groups related subrequirements from the existing review into complete tasks. Groups B through E and G cover the earlier test, parser, compatibility and performance findings. Groups A and F add the assertions policy and recent Core comparison. Group H records the wider platform and release roadmap.
