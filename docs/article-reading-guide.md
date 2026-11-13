# Reading xpact Against The Article

The article reference for this repository is:

<https://www.eiffel.org/blog/Finnian%20Reilly/2026/05/finding-billion-user-project-eiffel-how-dbc-catches-security-flaws-rust-misses>

The working interpretation used in this repository is:

- choose a widely deployed C library domain where reliability and security
  matter;
- implement the core behavior in Eiffel, with contracts visible in the source;
- use the existing C ecosystem as the compatibility oracle;
- publish benchmarks and parity gaps honestly instead of hiding them;
- separate Phase 1 correctness/parity work from Phase 2 performance
  architecture;
- keep enough C ABI compatibility to let real C callers test the Eiffel
  implementation.

## The Important Distinction

xpact is not trying to translate libexpat's C implementation into Eiffel line
by line. The goal is to build an Eiffel XML parser that can be judged against
libexpat's public behavior.

That distinction explains the repository shape:

- `src/xp_parser.e` owns XML tokenization, entity handling, DTD callbacks,
  position accounting, and parser invariants.
- `src/xp_native_parser.e` adapts the Eiffel parser to libexpat-style
  incremental parsing and callback semantics.
- `native/xpact_native.c` exports C ABI symbols but does not parse XML.
- `adapters/libexpat` makes the upstream Expat test suite the behavioral
  comparison point.

## How To Read The Source

Read the repository in this order if you want to understand the design:

1. `README.md`
   Establishes current release status and remaining gaps.
2. `docs/phase-1.md`
   Describes the Phase 1 scope that was built from the article's idea.
3. `src/xp_parser.e`
   Read this as the contractual core. Look for preconditions, postconditions,
   loop invariants, variants, and resource-limit checks.
4. `src/xp_external_entity_resolver.e` and `src/xp_external_entity_policy.e`
   These show the security boundary: the parser never performs I/O directly.
5. `src/xp_native_parser.e`
   This class is the compatibility adapter for libexpat-style streaming state,
   error codes, accounting, stop/resume, and native callbacks.
6. `src/xp_native_callback_handler.e`
   This class maps Eiffel events to the callback shapes expected by C callers.
7. `native/xpact_native.c` and `native/xpact_eiffel_runtime_bridge.c`
   These files are bridge infrastructure. They are intentionally not the XML
   parser.
8. `adapters/libexpat/parity.tsv`
   This is the public truth table for what upstream tests are green, red, or
   intentionally out of scope for the Windows preview.
9. `docs/performance-analysis.md`, `docs/wsl-benchmarks.md`, and
   `docs/gobo-assertions.md`
   These distinguish the completed parser optimizations from the 13 November
   local toolchain comparison and its assertion qualification. The tables in
   `docs/benchmarks.md` preserve the June Windows campaign; Jenkins artifacts
   identify each CI build's own measurements.

## How The Article Maps To Verification

The article's "billion-user project" idea only becomes credible if the
implementation is measured against existing users' expectations. For xpact,
that means layered verification:

- Eiffel tests exercise the contracted parser model in the tested configurations.
- Native ABI smoke tests verify the tested C linking and call paths.
- The upstream libexpat suite provides the main compatibility oracle.
- Same-machine benchmarks show cost honestly.
- Public-application replacement tests check the library outside its own
  repository.

`docs/drop-in-verification.md` turns that into a Jenkins plan.

## How The Performance Update Maps To xpact

The article's May 2026 performance discussion motivated the following design
directions. Some are already implemented in xpact's guarded no-op paths:

- Phase 1 was correct to use ordinary Eiffel strings while closing XML behavior
  and libexpat parity gaps.
- Slice-backed element names, no-event attribute/text scanning, and safe input
  aliasing are implemented. October work added marker reuse, backward-position
  updates, duplicate-attribute hashing, batched text positions, and bounded
  DOCTYPE slice eligibility. These are completed changes, documented with
  before/after evidence in [performance analysis](performance-analysis.md).
- Broader buffer views still require explicit ownership, callback, mutation and
  reset rules; the existing guarded paths do not establish a universal zero-copy
  parser or remove the need for materialized public values.
- Repeated names should be pooled or interned so large documents do not allocate
  the same vocabulary thousands of times.
- GC-off parse windows are implemented, including the qualified new Gobo
  `MEMORY` controls. Their benefit depends on the workload and allocation policy;
  the June neutral result is not a universal claim about GC cost.
- SCOOP pipeline parallelism is a later optional capability, not a substitute
  for making the single-threaded tokenizer competitive first.

Compiler behavior also matters: the new Gobo nightly fixes the original missed
checks, but a literal-`ensure False` inlining case remains different. Read the
[bounded qualification](gobo-assertions.md) before interpreting assertion-enabled
timings as identical enforcement across compilers.

## Current Answer To "Are We On The Right Track?"

Yes, for the Eiffel-library vision:

- XML behavior is implemented in Eiffel.
- Contracts remain part of the source design.
- Native ABI work is restricted to the boundary layer.
- libexpat is being used as the reference oracle.
- Remaining gaps are explicit.

No, if the claim is "100% drop-in replacement today":

The current acceptance levels and remaining replacement work are recorded in
[drop-in verification](drop-in-verification.md). Parser benchmarks and smoke
tests alone do not establish complete application replacement compatibility.
