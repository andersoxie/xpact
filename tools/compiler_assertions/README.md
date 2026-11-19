# Compiler assertion diagnostics

This small, bounded Eiffel program deliberately violates one contract at a time.
The runner builds it with the selected Linux compilers in three configurations:

| Configuration | Expected detection |
|---|---|
| `all_on` | Precondition, postcondition, plain `check`, class invariant, loop invariant, nondecreasing variant, and negative variant |
| `all_off` | None |
| `supplier_only` | The precondition on the call to another object |

Run from a Linux shell configured for EiffelStudio, Gobo, GCC and `make`:

```sh
python3 tools/compiler_assertions/run_probe.py
```

Use repeatable `--compiler Gobo` / `--compiler EiffelStudio` and
`--selection all_on` / `--selection all_off` / `--selection supplier_only` to
narrow the investigation. `--output-dir PATH` changes the default
`build/compiler-assertions` output directory. Gobo uses its bundled Boehm GC
with GCC; its CLI/default overrides are cleared for a reproducible configuration.

Every selected configuration is rebuilt in its own directory. Build logs,
generated C, and individual probe diagnostics are retained there. `results.json`
records versions, source hashes, requested versus observed behavior, and the
diagnostic text. Nonzero probe exits count as detected violations only when the
expected assertion tag is present, so a crash or loader failure cannot be
mistaken for a successful check.

This is a diagnostic tool, not a conformance gate. Known capability differences
produce a report and exit zero; inspect `all_requested_checks_match` and the
per-case results. Build failures, timeouts, and unrelated execution failures
exit nonzero and leave no result report. Old reports and executables are
invalidated before rebuilding, and the complete report is published only after
all selected builds and cases finish.

The postcondition uses a boolean argument instead of a literal `ensure False`:
EiffelStudio raises a postcondition violation for the latter even when ordinary
postcondition monitoring is disabled. This runtime behavior does not establish
the same attachment-analysis rules as `check False then end`.
Both loop-variant probes terminate after
two iterations when checking is absent.

## Recorded qualification: 13 November 2026

Gobo `26.11.12+ca6541c` and EiffelStudio `25.02.9.8723` each match all 21
Linux/GCC cases in this runner. The three Gobo 26.10 omissions (plain `check`,
non-decreasing variant, and supplier-only precondition) no longer reproduce in
that nightly. A separate Windows Gobo qualification also matches those 21 cases.

Separate probes check imported-library scope, caller-policy restoration, and
repeated Boehm GC on/off transitions. These pass on the qualified Gobo build.
An additional Linux probe still differs: finalized Gobo removes an empty
routine's literal `ensure False` with assertions off, whereas EiffelStudio
raises. The dynamic postcondition in this runner deliberately does not test
that special case, so `all_requested_checks_match` is not a claim of full
compiler equivalence.

See [the assertion investigation](../../docs/gobo-assertions.md) for the scope,
diagnostics and saved supplementary probe sources, and
[WSL setup](../../docs/wsl-benchmarks.md) for compiler environment selection.
