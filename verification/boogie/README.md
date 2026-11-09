# Boogie checks of parser loops

Issue [#252](https://github.com/andersoxie/xpact/issues/252) · Report: [reports/issue-0252](../../reports/issue-0252/report.md) · Code modelled: `src/xp_native_parser.e` @ `f067a9d` (unchanged up to `5519ea2`)

## In short

- ✅ Boogie **finds both known loop-variant bugs**, [#3](https://github.com/andersoxie/xpact/issues/3) and mass-xpact #12, in the code from before their fixes, and gives the exact failing path.
- ✅ Boogie **proves both fixed loops**: every `item` call is in bounds, every call meets its callee's precondition, and every variant stays non-negative and decreases on every iteration, **for every input**.
- 🔎 **Finding:** the proofs only go through with **facts that no contract states** (see below). The code still works, but a contract-based verifier like AutoProof would reject it until the contracts say these facts.
- ⚠️ These are **hand-written models** of the Eiffel code, not the Eiffel code itself. A proof covers the model only. See [Limitations](#limitations).

Why Boogie: the supervisor asked for AutoProof / EVE / Boogie. AutoProof (inside EVE) translates Eiffel to Boogie automatically, but no current EVE build was found yet. Boogie itself is available, so these models do the translation by hand.

## Run

Needs Boogie 3.5.x and Z3 (tested with Boogie 3.5.8 and Z3 4.12.1):

```sh
dotnet tool install --global boogie --version 3.5.8     # Boogie (.NET tool)
# Z3: unzip z3-4.12.1-x64-win.zip from https://github.com/Z3Prover/z3/releases
export Z3=/path/to/z3-4.12.1-x64-win/bin/z3.exe          # or put z3 on PATH
sh verification/boogie/run-all.sh                       # Git Bash, Linux or macOS
```

`run.sh` sets `DOTNET_ROLL_FORWARD=Major` (Boogie 3.5.x targets .NET 8 and then also runs on .NET 10) and `MSYS_NO_PATHCONV=1` (otherwise Git Bash turns Boogie options like `/version` into paths). Full output of each run goes to `logs/` (not committed).

## Expected results

| Run | What is checked | Expected |
|---|---|---|
| `00-smoke` | toolchain: one correct, one wrong `max` | 1 verified, 1 error |
| `01-skip-reparse-tag-spaces` | bounds, variant, `result_in_bounds` | 1 verified, 0 errors |
| `02-direct-start-tag-name` | body + **proposed** postcondition `Result /= Void implies a_start_index + 1 < a_end_index` | 1 verified, 0 errors |
| `03-A-before-fix` | #3 loop with the old variant `a_end_index - i` | 1 error: line 133 "variant decreases", path through the `'/'` branch (the `<root/>` case of #3) |
| `03-B-after-fix` | #3 loop as on `f067a9d` | 3 verified, 0 errors |
| `03-C-contract-as-written` | same, `direct_start_tag_name` known only by its real contract | 1 error: line 43, loop 1 variant may start negative |
| `04-UA-before-fix` | UTF-16 loop before `19ba873` | 1 error: line 68 "variant decreases" |
| `04-UB-after-fix` | UTF-16 loop as on `f067a9d`, two facts assumed | 1 verified, 0 errors |
| `04-UC-contract-as-written` | same, contracts only | 3 errors: `index_in_bounds` on entry; 2× `utf16_unit_at` precondition |

The observed results are in the [report](../../reports/issue-0252/report.md).

## Finding: contracts too weak for a proof

| Routine | The proof needs | Stated by a contract? | Can it fail at run time? |
|---|---|---|---|
| `direct_start_tag_attributes` | `direct_start_tag_name /= Void` ⇒ `a_start_index + 1 < a_end_index` | ❌ `direct_start_tag_name` has no postcondition | No: the body guarantees it (proved in `02`) |
| `append_decoded_utf16` | `l_end <= input_buffer.count` | ❌ `complete_encoded_prefix_count` has no postcondition | ❔ unknown: not modelled |
| `append_decoded_utf16` | `decoded_raw_count <= l_end` | ❌ no postcondition, no class invariant | ❔ unknown: needs a check of every place that changes `input_buffer` or `decoded_raw_count` |

Possible fix (not done here): add these as `ensure` / `invariant` clauses. AutoProof would need the same.

## Files

| File | Models |
|---|---|
| [models/prelude.bpl](models/prelude.bpl) | string = map + count; space/quote tests; name tests left open (the proof holds for any definition) |
| [models/01-skip-reparse-tag-spaces.bpl](models/01-skip-reparse-tag-spaces.bpl) | `skip_reparse_tag_spaces` |
| [models/02-direct-start-tag-name.bpl](models/02-direct-start-tag-name.bpl) | `direct_start_tag_name` (body + contract as written) |
| [models/03-direct-start-tag-attributes.bpl](models/03-direct-start-tag-attributes.bpl) | `direct_start_tag_attributes` (#3), switches `FIXED`, `NAME_POST` |
| [models/04-append-decoded-utf16.bpl](models/04-append-decoded-utf16.bpl) | `append_decoded_utf16` (mass-xpact #12), switches `U_FIXED`, `U_FACTS` |
| `models/config-*.bpl` | one line each: sets the switches for one run |
| [run.sh](run.sh), [run-all.sh](run-all.sh) | run one / all |

## Limitations

- **Hand translation.** Each model was written by reading the Eiffel code; a translation mistake would make a proof meaningless for XPact. AutoProof would translate automatically.
- **Only the checked properties:** bounds of `item`, call preconditions, loop variants and stated postconditions. Not checked: that the attributes or decoded text are *correct*.
- **Abstractions:** name-character tests are open functions; `has ('&')`, duplicate names, `max_name_length` and UTF-16 unit values are arbitrary (havoc). `substring` has no precondition in EiffelBase 25.12, so it is not checked. Integer overflow is not modelled (Boogie `int` is unbounded).
- **Helper invariants** (parity of `i`, etc.) were added by hand where Eiffel has none; Boogie checks them too.
- **Line references** point to `src/xp_native_parser.e` @ `f067a9d`; the models do not follow later code changes by themselves.
- Two routines only. The rest of the parser is not covered.
