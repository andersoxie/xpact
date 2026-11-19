# Gobo assertion performance and coverage

The initial Gobo/EiffelStudio assertion comparison did not enable the same
checks. Most of Gobo's large slowdown came from checking its Base library,
including allocating integer invariants, while EiffelStudio disabled ordinary
Base-library assertions. The Gobo benchmark now explicitly disables Base
assertions and labels the remaining mode **xpact assertions requested**.
Gobo 26.10 still misses several checks despite that scope correction.
The newer `26.11.12+ca6541c` nightly passes the previously failing probes;
an additional literal-`ensure False` case still differs from EiffelStudio.
The follow-up below distinguishes those results from the original measurements.

The original investigation was performed on 8 November 2026 against parser revision
`b870d3b`, Gobo `26.10.18+c84ee2f`, EiffelStudio `25.02.9.8723`, and GCC 13.3.0
inside Ubuntu 24.04/WSL2. The parser was unchanged during the experiments.
The evidence is in [the investigation data](../benchmarks/results/gobo-assertion-investigation-2026-11-08.json).

## Follow-up: 13 November 2026

The installed Windows compiler, `C:\gobo\bin\gec.exe`, reports
`26.11.12+ca6541c`. This is the latest **nightly** checked on 13 November;
the latest stable release at that check was `26.10.18+c84ee2f`.
The matching official Linux archive was downloaded into a separate qualification
directory. Both packages correspond to commit
`ca6541cacb6d3ce388bc312c884f321d183de411`.
See the [official nightly release](https://github.com/gobo-eiffel/gobo/releases/tag/nightly)
and [changes since 26.10](https://github.com/gobo-eiffel/gobo/compare/c84ee2f...ca6541c).

Fresh finalized builds (Gobo using Boehm GC) produced these results:

| Qualification | Linux / GCC 13.3 | Windows / bundled Zig 0.15.2 |
|---|---|---|
| Seven assertion cases, each in all-on, all-off and supplier-only modes | Gobo **21/21**; EiffelStudio 25.02 **21/21** | Gobo **21/21** |
| Imported-library scope and caller-state cases | Gobo **7/7** | Gobo **7/7** |
| `MEMORY.collecting`, `collection_off`, `collection_on` sequence | Passed | Passed |

All-on now detects the plain `check` and non-decreasing loop variant, and
supplier-only now detects the precondition. All-off still completes all seven
cases. Gobo and EiffelStudio therefore agree on every case in the existing
bounded assertion matrix; this does not establish complete Eiffel semantic
equivalence.

That 42-case Linux matrix deliberately uses a dynamic postcondition, so it does
not exercise the special handling of literal `ensure False`. A separate finalized
Linux/GCC probe compared this empty routine with a routine whose postcondition is a Boolean
parameter passed `False`:

```eiffel
test_literal
    do
    ensure
        literal_false_postcondition: False
    end
```

| Compiler and assertion mode | Literal `False` | Dynamic false parameter |
|---|---|---|
| Gobo 26.11.12, all off | **Completes normally** | Completes normally |
| Gobo 26.11.12, all on | Detected | Detected |
| EiffelStudio 25.02, all off | Detected | Completes normally |
| EiffelStudio 25.02, all on | Detected | Detected |

Seven of the eight expected compatibility outcomes matched. The remaining Gobo
case exits successfully after the call; its generated C contains an empty inline
block in place of the routine. The generator's postcondition check prevents
inlining only when postcondition monitoring is enabled. This points to inlining
bypassing the new literal-`False` exception behavior. The fixture uses a tagged
postcondition; source inspection shows that the special-case predicate examines
the expression without consulting its tag. The untagged form was not separately
run. This is an additional compatibility gap, separate from the original three
assertion defects that now pass.

The separate-library fixture leaves its imported library's assertion options
unset while enabling all assertions in the root target. It confirms that
ordinary library postconditions and invariants remain disabled, while a root
call checks the library routine's supplier precondition. A library-to-library
call leaves that precondition disabled; after returning to the root, a direct
call checks it again. Root check and postcondition violations remain detected.
This verifies both scope isolation and restoration of the caller's policy.

The GC probe observes **enabled → off → off → on → on → off → on**, including
repeated operations. It uses explicit process failure on a mismatch, independent
of Eiffel assertion settings. This qualifies those three control operations,
not memory reclamation, other `MEMORY` APIs, or multithreaded behavior.

Parser reuse does not eliminate temporary objects. The no-event parsing path
[creates an `XP_TOKEN_SLICE` for each opening element](../src/xp_parser.e#L5777),
and parser reset replaces namespace state and predefined-entity strings.
The current catalog has 101 elements per document. A bounded executable might
finish with GC disabled, but that does not establish acceptable memory growth
for a long-lived application. Allocation bytes and sustained memory growth were
not measured here. Suspending GC around each parse, then restoring its previous
state, also differs from compiling the whole program with `--gc=no`.

The fixes are present upstream:

| Original issue | Corrective change |
|---|---|
| ECF `check` option updates the wrong setting | [Correct option setter](https://github.com/gobo-eiffel/gobo/commit/196c23725e6b45fba943d8c8e37420eeb2058dc3) |
| Saved loop variant assigned in the wrong direction | [Correct saved value](https://github.com/gobo-eiffel/gobo/commit/b861e06463b6a3fb55f7ce513fd58bd5983ff654) |
| Missing caller-requested supplier preconditions | [Track caller precondition policy](https://github.com/gobo-eiffel/gobo/commit/17c6b3756e5787f401988e45d1e96cb466ccc273) |
| Root assertions propagate into imported libraries | [Keep library options separate](https://github.com/gobo-eiffel/gobo/commit/5b083f9674d72a40faa1c77e61d63e9d34fb5b62) |
| Checked primitive routines trigger integer invariants and boxing | [Inline finalized basic routines and disable basic-class assertions](https://github.com/gobo-eiffel/gobo/commit/894098e1c154610bfc4522864e5611b3d4e6552d) |
| Ordinary assertions carry additional exception frames | [Remove per-assertion `setjmp`](https://github.com/gobo-eiffel/gobo/commit/f51e634011e2ce136badd9b5ce238ddd1b3bc33a) |
| GC controls are stubs | [Implement Boehm GC controls](https://github.com/gobo-eiffel/gobo/commit/51c91d46cb3f482d76e0e2f84890017ac322aecd) |

Inspection of the newly generated assertion-enabled xpact C confirms that
ordinary preconditions and checks no longer introduce their own `GE_setjmp`,
and the integer invariant/boxing path is absent. Exception frames still occur
for old expressions, once initialization, and rescue handling. The current ECF
already disables Base assertions, so this inspection cannot isolate the benefit
of the primitive optimization from the earlier scope correction.
The primitive change permits finalized inlining and suppresses basic-type
assertions, matching EiffelStudio's behavior; it does not remove the boxing
implementation or establish that boxing is unnecessary in other contexts.

Both Gobo benchmark modes also built and completed a smoke run: 100 documents,
one warmup and three measured runs per mode, at repository revision `01e963d`.
This is compatibility evidence, not a new performance comparison with the
8 November timings. The runner continues to publish only normal-GC Gobo rows;
that omission no longer means the newer compiler lacks GC controls.

An additional Linux/GCC check built both finalized targets directly from the unchanged
`benchmarks/xpact_benchmarks.ecf`, including its reference to EiffelStudio's Base
library. Gobo built and parsed 100 documents in each mode without an added ECF
optimization flag or an explicit `--gc` argument. Its generated commands used
the default GCC `-O2`, and both executables used the default Boehm GC. This verifies
that this ECF works with the tested Gobo installation without the separate Gobo
ECF's overrides. The compiler's general GC default is Boehm when available and
no GC otherwise; explicitly selecting Boehm remains useful for reproducibility.

The nightly is built on Ubuntu 22.04 rather than a newer GitHub runner image.
Compatibility with Ubuntu 20.04 remains **untested**; successful Ubuntu 24.04
qualification does not establish it.

**Jenkins build #134 still used the old Linux compiler.** Successful `xpact` build
**#134**, started at 14:30 and finished at 15:07 Stockholm time on 13 November,
archives `gec version 26.10.18+c84ee2f` in its WSL benchmark metadata. Its
compiler is under `build/gobo-toolchain/26.10/gobo`, selected by
`build/gobo-toolchain/gobo-env.sh`. The new Windows archive had been downloaded
at 14:12, but that installation did not replace the WSL compiler. Initial
qualification used an isolated Linux installation. Later, at **18:15 UTC
(19:15 Stockholm)** on 13 November, the shared environment file was switched to
`build/gobo-toolchain/26.11.12-ca6541c/gobo`. This changes the compiler selected
by subsequent Jenkins WSL builds; it does not change build #134's archived results.

The [qualification evidence](../benchmarks/results/gobo-assertion-qualification-2026-11-13.json)
preserves the version identities, assertion diagnostics, additional probe source
text, commands, hashes, and Jenkins metadata identity. The shared-ECF and
literal-postcondition follow-up accompanies the
[new Gobo/EiffelStudio comparison](../benchmarks/results/gobo-eiffelstudio-comparison-2026-11-13.json);
see the [WSL benchmark notes](wsl-benchmarks.md) for its methodology and results.
The original findings and timings below remain historical evidence for Gobo 26.10.

## What the original 8 November results measured

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

## Gobo 26.10 assertion coverage differences

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
error. Postconditions use a dynamic predicate because EiffelStudio raises a
violation for literal `ensure False` even when ordinary assertion monitoring is off.

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
