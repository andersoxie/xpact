# Gobo assertion performance and coverage

The initial Gobo/EiffelStudio assertion comparison did not enable the same
checks. Most of Gobo's large slowdown came from checking its Base library,
including allocating integer invariants, while EiffelStudio disabled ordinary
Base-library assertions. The Gobo benchmark now explicitly disables Base
assertions and labels the remaining mode **xpact assertions requested**.
This aligns the broad library scope but does **not** make assertion enforcement
identical: Gobo 26.10 misses several checks described below.

This investigation was performed on 8 November 2026 against parser revision
`b870d3b`, Gobo `26.10.18+c84ee2f`, EiffelStudio `25.02.9.8723`, and GCC 13.3.0
inside Ubuntu 24.04/WSL2. The parser was unchanged during the experiments.
The evidence is in [the investigation data](../benchmarks/results/gobo-assertion-investigation-2026-11-08.json).

## What the original results measured

The original medians were for three process runs of 1,000 copies of the same
2,611-byte catalog, after one warmup, with normal garbage collection:

| Requested mode | EiffelStudio | Gobo, original configuration |
|---|---:|---:|
| Assertions off | 188.183 ms | 113.548 ms |
| Assertions on | 1,615.829 ms | 24,833.566 ms |

The two ECF targets both requested preconditions, postconditions, checks,
class invariants, loop assertions, and supplier preconditions. However,
EiffelStudio's generated runtime option table enabled the 15 xpact types
with assertion mask 63 and assigned mask 0 to Base types, including
`INTEGER_32`, `BOOLEAN`, `CHARACTER_8`, `STRING_8`, and `ARRAYED_STACK`.
Gobo propagated the target policy into its imported Base library.

Generated assertion text alone is insufficient evidence of execution.
EiffelStudio emits Base assertion code but guards it using its runtime option
table. The corresponding Gobo checks were executable in the measured binary.
EiffelStudio also retains caller-requested supplier preconditions: an xpact
caller can check a Base routine's precondition despite Base's own mask being 0.

## Why the additional checks are expensive

Gobo's checked integer comparisons invoke Eiffel routines and entry/exit
invariants. The generated `INTEGER_32.invariant` evaluates the inherited
`reflexive_conformance` clause by allocating a temporary boxed integer through
`GE_boxed111`, then calling `INTEGER_32.conforms_to`. That routine returns true,
but the allocation remains in the optimized executable. EiffelStudio's hot
parser paths use native integer comparisons without these Base invariants.

Instrumentation of a copy of the original generated C counted **554,112
integer invariant evaluations and 554,112 integer boxes for 10 documents**,
including process setup. Boehm reported 84 collections in that short run.
Its small heap repeatedly collected these temporary objects; the CPU profile
also showed substantial kernel scheduling, futex, and page-management work.
The checked routines carry exception frames and `_setjmp` calls as well.

Controlled experiments changed one factor at a time. Each row below is the
median of three runs of **100 documents**, following a full untimed warmup.
These shorter batches include process startup and should not be scaled into
the original 1,000-document measurements.

| Configuration | Median time |
|---|---:|
| EiffelStudio, original assertion configuration | 254.647 ms |
| Gobo, original assertion configuration, GCC `-O2` | 2,433.624 ms |
| Gobo, original assertions, GCC `-O3` only | 2,438.306 ms |
| Gobo, original assertions, one Boehm marker thread | 892.048 ms |
| Gobo, only integer invariant boxing eliminated in diagnostic C | 681.440 ms |
| Gobo, Base assertions disabled, xpact assertions still requested | 44.766 ms |

The GCC optimization setting does not explain the gap in this experiment.
Eliminating only the integer invariant's redundant boxing reduced elapsed time
about 72% and reduced collections from 84 to 3 in a separate 10-document run.
Disabling Base assertions removed about 98% of the original Gobo elapsed time
in the 100-document experiment; its 10-document GC run showed only the initial
collection. Parser assertions remained generated in that configuration.

The generated-C change and single-marker setting are diagnostic controls,
not shipped runtime changes. The corrected benchmark changes only the ECF's
Base assertion scope. It keeps GCC `-O2`, Boehm's normal settings, and the
unchanged parser. The faster corrected Gobo row is still not proof of superior
performance under equivalent contract enforcement.

## Checks are still not equivalent

Small bounded programs deliberately violate each kind of contract. With all
six ECF assertion flags requested, the observed behavior is:

| Deliberate violation | EiffelStudio 25.02 | Gobo 26.10 |
|---|---|---|
| Precondition | Detected | Detected |
| Postcondition | Detected | Detected |
| Plain `check` instruction | Detected | **Not detected** |
| Class invariant | Detected | Detected |
| Loop invariant | Detected | Detected |
| Non-decreasing loop variant | Detected | **Not detected** |
| Negative loop variant | Detected | Detected |
| Precondition with only `supplier_precondition` enabled | Detected | **Not detected** |

The probes also run with assertions discarded. They classify only the named
deliberate violation as detection; an unrelated failure is an investigation
error. Postconditions use a dynamic predicate because EiffelStudio gives
literal `ensure False` special nonreturning-routine semantics.

The findings correspond to concrete Gobo 26.10 compiler behavior:

- In `ET_ECF_GROUP.fill_options`, the ECF `check` option updates the invariant
  setting instead of the check-instruction setting. The benchmark therefore
  lacks checks such as `attribute_name_ranges_available` and
  `namespace_scope_available` that EiffelStudio includes.
- The C generator assigns the saved loop-variant value in the wrong direction.
  A constant positive variant passes even though it does not decrease; the
  independent negative-value check still works.
- Supplier-precondition-only selection does not activate the violated
  precondition in the Gobo probe. Consequently, explicitly disabling Base
  assertions does not reproduce EiffelStudio's caller-requested Base
  preconditions.

These are limitations of the tested Gobo release, not parser fixes. The
benchmark retains the requested xpact assertion flags, records the requested
scope and known coverage limitations, and avoids calling the configurations
equivalent. Later compiler versions need fresh qualification rather than
assuming these defects persist or have been fixed.

## Reproducing the investigation

Configure both Linux compilers as described in
[the WSL benchmark instructions](wsl-benchmarks.md), then run:

```sh
python3 tools/compiler_assertions/run_probe.py
```

This builds isolated all-on, all-off, and supplier-only programs, then writes
`build/compiler-assertions/results.json` and the build/probe logs. Exit zero
means the diagnostic completed; inspect `all_requested_checks_match` and the
per-case results for capability differences. Missing tools, build failures,
timeouts, and unrelated process failures do not publish a successful report.

To reproduce the original excessive scope, make a separate copy of
`benchmarks/xpact_gobo_benchmarks.ecf`, make its cluster paths absolute, and
remove the nested assertion options on its `base` library. Build its
assertion target in an isolated directory with `--finalize --gc=boehm --cc=no`,
then run the generated shell script with `sh -e` from its `.gobo` directory.
Keep this diagnostic configuration separate from ordinary benchmark results.

The optional generated-C controls are created with:

```sh
python3 tools/compiler_assertions/create_gobo_variants.py \
  --generated-dir /absolute/path/to/original-assertions/.gobo \
  --output-dir /absolute/path/to/new-diagnostic-variants
```

The tool requires the audited generated Gobo 26.10 integer implementation,
rejects incompatible output, copies sources into a new directory, and records
diffs and hashes. It creates counting, integer-boxing-eliminated, and `-O3`
variants without compiling or modifying the originals. Compile each copied
shell script separately, then time sequentially with the same iteration count.
`GC_PRINT_STATS=1` supplies the separate collection diagnostics; omit it from
timed runs. `GC_MARKERS=1` selects the diagnostic single-marker control.

The original historical results belong to `b870d3b`; measurements on later
parser revisions are a separate series. This investigation does not qualify
every Eiffel language construct, inherited contract combination, compiler
version, or XML workload.
