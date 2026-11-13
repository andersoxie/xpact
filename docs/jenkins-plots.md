# All Jenkins benchmark plots

The **All Benchmark Plots** report collects the current build's dual-parser
comparison, Windows benchmarks, WSL benchmarks, and optional large XML
benchmarks on one page. Open the report from the Jenkins build or its archived
artifact, `build/all-benchmark-plots/index.html`. Each plot includes an
explanation of its measurement, how to read it, and the limits of the comparison.
Source evidence links retain access to the underlying results.

The page presents existing measurements. Generating or consolidating it does
not run a benchmark. Performance and correctness remain separate: shorter
execution time does not establish correct XML behavior, and a conformance
count is not a throughput measurement.

## Report families

| Family | Measurements | Source |
|---|---|---|
| Dual implementations | Catalog time and throughput; four W3C outcome counts | The current build's `build/dual-ci-...` campaign |
| Windows benchmarks | Current elapsed-time bars and available build history | `build/benchmarks/benchmark-results.tsv` |
| WSL Eiffel GCC benchmarks | Current elapsed-time bars and available build history | `build/wsl-benchmarks/benchmark-results.tsv` |
| Large XML benchmarks | Current elapsed-time bars and available build history for each corpus | `build/large-xml-benchmarks/large-xml-benchmark-results.tsv` |

`Jenkinsfile.all-tests` supports all four families. `Jenkinsfile.windows-phase1`
has the dual, Windows, and WSL families; its report marks large XML as disabled.
A **disabled** family was not requested by that pipeline configuration. A
**missing** family has no usable current-build snapshot, for example because a
preceding stage failed or publication did not complete. Neither means a zero
measurement or a successful test result.

## Dual implementation plots

These plots compare xpact with the pinned Xpact-core implementation on Windows
x64 using finalized Eiffel builds with assertions discarded. Assertion-enabled
builds run directed correctness controls; their timings are not mixed into the
plots. Source revisions, executable identities, campaign state, and control
results belong to the comparison evidence.

### Catalog time per 1000 documents

The horizontal bars show median milliseconds per 1,000 documents. Lower is
faster. Each measured elapsed time is divided by that sample's document count
and multiplied by 1,000 before taking the median. This normalization matters
because the paired runner can increase the common iteration count during
calibration. A larger calibrated run must not appear as a slowdown merely
because it parses more documents.

Both parsers process the same catalog with no-op event handlers, and measured
pairs alternate execution order. Timing includes process startup and parser
reset/reuse. It also includes each implementation's GC behavior: xpact uses
normal collection, while core retains its internal suspension and full
collection behavior. The result describes these complete configured paths;
it does not isolate only the XML scanner or the cost of GC.

### Catalog throughput

The bars show median mebibytes per second, with one MiB equal to 1,048,576
bytes. Higher is faster. Each sample's rate is the document size multiplied by
its iteration count, divided by elapsed seconds and by 1,048,576. The plot
uses the median of those individual rates.

This is the same workload as the normalized-time plot, expressed as useful
input volume per unit of time. The two plots answer complementary questions:
how long a fixed number of documents takes, and how many bytes the configured
path processes per second. Because medians are calculated separately, the
displayed median throughput need not be the exact reciprocal conversion of
the displayed median time, particularly with an even number of samples.

### W3C passed cases

Each bar counts cases whose acceptance or rejection matches the expected
verdict within this lane's supported profile. Higher is better when the suite
and profile are unchanged. Passing includes correctly rejecting not-well-formed XML;
it does not mean every counted document was accepted.

Read this count alongside wrong verdicts, process errors, and exclusions. A
changed suite size or profile changes the denominator. These plots concern
acceptance/rejection behavior, not complete callback or canonical-output
equivalence.

### W3C wrong verdicts

Each bar counts completed cases with an incorrect acceptance or rejection
decision. Lower is better; zero means no wrong verdict was observed among the
completed verdict cases. This category separates a parser's wrong answer from
a case that could not produce a usable result because of a process error or
timeout.

A fall in wrong verdicts is not automatically an improvement if process errors
rise at the same time. Check all four outcome counts and the detailed case
results before attributing a change to parser correctness.

### W3C process errors and timeouts

Each bar counts cases that ended without a usable normal verdict because of
execution or protocol errors, including timeouts. Lower is better. These are
failures, not skipped cases. Their individual diagnostics are needed to
distinguish a parser problem from an execution-environment problem.

The plot deliberately shows counts rather than elapsed times. W3C execution
launches fresh processes and performs file I/O; those durations do not provide
a comparable parser-throughput measurement.

### W3C profile exclusions

Each bar counts catalog cases outside the selected comparison profile.
Exclusions are neither passes nor failures and should not be read as a
performance score. Both implementations must have the same exclusion count
for a valid published comparison.

For each implementation, passed cases plus wrong verdicts plus process errors
plus exclusions must equal the catalog total. A change in exclusions calls for
checking the suite and profile before comparing pass counts across builds.
No known-failure allowlist converts wrong verdicts or process errors into
passes.

Completed campaigns with functional failures remain visible. Incomplete lanes
do not supply numeric plot values. Only xpact contributes to the Jenkins test
summary and test gate; pinned core remains comparison evidence. See
[dual implementation execution](dual-implementation-jenkins.md) for the
campaign and provenance rules.

## Current elapsed time plots

The Windows, WSL, and large XML families group the source rows by workload and
engine. A bar shows the median elapsed milliseconds for one complete measured
run, including all its document iterations. Lower is faster. These plots use
the existing lower-median convention: sort the repetitions and select index
`floor((count - 1) / 2)`. With an even number of repetitions, this selects the
lower central observation rather than averaging the two central values.

Compare bars only with their workload size, iteration count, and engine mode
in view. A 10,000-document run and a 1,000-document run are different amounts
of work even if their chart labels use the same milliseconds unit. A missing
or explicitly unmeasured engine is not a zero-duration result.

### Windows catalog benchmark

The standard workload is a 2,611-byte UTF-8 catalog containing 100 item
elements. The runner defaults to 1,000 document iterations and three measured
process runs. Windows wall-clock timing surrounds the launched executable, so
startup, document preparation, parsing, and process completion contribute to
the result. WSL C rows launched by this Windows runner also include
`wsl.exe` startup. Compilation occurs outside the timed command.

The engine labels identify meaningful differences. Direct Eiffel rows reuse
a parser with a no-op handler. CPython `pyexpat` rows create a parser for each
document; callback rows also execute Python callbacks. Windows native ABI
rows exercise the Eiffel-backed DLL through C, with separate callback and
tokenizer configurations. Explicit parser-reuse variants call
`XML_ParserReset` between documents. GC-suspended and assertion-enabled modes
are separate series because they change the executed path. The bars therefore
compare configured applications and bindings, not interchangeable pure-parser
timings. See [Windows benchmarks](benchmarks.md).

### WSL Eiffel GCC benchmark

This family uses the same catalog inside one Linux environment. The runner
defaults to 10,000 iterations and five repetitions, with one full-workload
untimed warmup for each engine. A Linux monotonic clock measures each complete
subprocess. Linux process startup and preparation are included; compilation
and the Windows-to-WSL launch are excluded.

EiffelStudio, Gobo, and direct C libexpat rows identify their compiler and
runtime paths. Gobo uses its own runtime and Boehm GC, and has no published
GC-suspended variant in this runner. Gobo 26.10 missed checks and had stub GC
controls; the qualified `26.11.12+ca6541c` nightly passes the original assertion
matrix and GC-control sequence. The label **xpact assertions requested** remains
appropriate because qualification is bounded and an inlined literal-`ensure False`
case still differs from EiffelStudio. See the [assertion evidence](gobo-assertions.md).
Comparing Windows and WSL bars cannot isolate compiler effects from
OS, runtime, launch, and iteration-count differences. See
[WSL benchmark configuration and interpretation](wsl-benchmarks.md).

The 13 November Gobo/EiffelStudio comparison is a separate local campaign.
Jenkins build #134 still recorded Gobo 26.10; the shared WSL environment was
switched to 26.11.12 later that day. Read each build's archived compiler version
rather than applying the local result or the environment change retroactively
to its plots. A toolchain change is not by itself a parser-code speedup.

### Large XML benchmark

Each workload identifies a caller-supplied, already decompressed XML file.
The runner loads the complete file before parsing; defaults are one iteration
and three process runs. Timing includes process startup and file loading, but
not download or decompression. Any C baseline launched through WSL from this
runner also includes that launch overhead.

These bars expose behavior on the named real corpus rather than on the small
synthetic catalog. Compare engines within the same corpus and byte count.
Changing a file while keeping its name changes the workload, and elapsed time
alone cannot establish a parser regression across that change. Whole-file
results do not measure streaming memory use or incremental parsing. See
[large XML benchmarks](large-xml-benchmarks.md).

## Build history plots

When history is available, the corresponding trend follows each engine's
elapsed-time median across retained builds. Lower durations indicate faster
completion only when the workload and execution conditions are comparable.
The first-to-last percentage is `(last - first) / first * 100`; a negative
value means elapsed time fell. It is not an independently measured throughput
change or a statistical confidence interval.

The existing history producer combines locally available history with the
previous successful build's archived history, adds the current result, and
retains at most 30 build identifiers. It can fall back to that previous
build's raw results when no history is available. A failed history download
does not turn the current value into a historical series.

History records identify the build, workload, engine, and median duration.
They do not establish that iteration counts, input bytes, compiler versions,
or machine load remained unchanged. Use the archived source reports when
investigating a trend. Earlier successful builds and current build results
are distinct from a continuously sampled time series; absent observations
are not zeroes.

## Publication lifecycle

Each participating lane captures a small snapshot owned by the current build.
The generic benchmark snapshots use the original plot CSV values and
available history. The dual snapshot validates the campaign state and its
persisted lane report hashes before accepting those values. The original Jenkins Plot
identifiers and trend inputs remain available.

Snapshots are retained across stage workspace cleanup. Consolidation selects
only the requested build's snapshots and renders one report, with explicit
disabled or missing-family notices. This matters particularly in
`Jenkinsfile.all-tests`, where stages clear their workspaces: reading only the
last stage's filesystem would lose earlier plots. A missing or failed capture
must not be replaced by a previous build's measurement.

The report preserves source evidence links. Keep the associated Jenkins
artifacts available when using those links; copying only the HTML elsewhere
does not copy the linked raw reports.

## Render a report locally

Capture existing outputs with one shared build identifier, then render the
snapshot directory. These commands do not rerun the measurements. Substitute
the source directory and build identifier from the campaign being inspected.
The generic `--manifest` option accepts the manifest produced by
`writeBenchmarkPlotCsvFiles`; it is required for Windows, WSL, and large XML
captures and omitted for the dual capture.

```powershell
python scripts/jenkins_plot_report.py capture --lane windows --build-id example-42 --source-dir build/benchmarks --manifest jenkins-plot-same-machine-benchmarks-manifest.tsv --output build/plot-snapshots/windows.json
python scripts/jenkins_plot_report.py capture --lane wsl --build-id example-42 --source-dir build/wsl-benchmarks --manifest jenkins-plot-wsl-eiffel-gcc-benchmarks-manifest.tsv --output build/plot-snapshots/wsl.json
python scripts/jenkins_plot_report.py capture --lane large --build-id example-42 --source-dir build/large-xml-benchmarks --manifest jenkins-plot-large-xml-benchmarks-manifest.tsv --output build/plot-snapshots/large.json
python scripts/jenkins_plot_report.py capture --lane dual --build-id example-42 --source-dir build/dual-ci-42-1234567890 --output build/plot-snapshots/dual.json
python scripts/jenkins_plot_report.py render --build-id example-42 --input-dir build/plot-snapshots --output build/all-benchmark-plots/index.html
```

The dual capture's build identifier must match the campaign's `run.json`;
`example-42` and the campaign path above are placeholders. Pass
`--build-url https://jenkins.example/job/xpact/42/` to `render` when evidence
should link to that build's archived artifacts. Mark intentionally omitted
families with repeated `--disabled` options, for example `--disabled wsl
--disabled large`. Otherwise an absent family is reported as missing.
