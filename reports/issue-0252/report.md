# Issue #252: check parser loops with Boogie

| Item | Value |
|---|---|
| Issue | [#252](https://github.com/andersoxie/xpact/issues/252) (labels `test`, `investigation`) |
| Branch | `test/252-boogie-loop-checks`, from `incremental-test` @ `5519ea2` |
| Code modelled | `src/xp_native_parser.e` @ `f067a9d` (identical at `5519ea2`) |
| Tools | Boogie 3.5.8 (.NET tool, run on .NET 10.0.10 with `DOTNET_ROLL_FORWARD=Major`), Z3 4.12.1 x64 |
| Machine | Windows 11 Home 10.0.26300, Git Bash |
| Parser change | **none** |
| Status | ✅ models added and run; 🔎 contract finding open (no fix here) |

## Problem

The supervisor asked to "use AutoProof / EVE / Boogie on xpact". No current AutoProof/EVE build was found, but Boogie (the back end AutoProof translates Eiffel into) is available. Past loop-variant bugs ([#3](https://github.com/andersoxie/xpact/issues/3), mass-xpact #12) were found only when a test happened to hit them.

## What was done

Hand-written Boogie models in [verification/boogie/](../../verification/boogie/README.md) of:

| Routine | Line @ `f067a9d` | Past bug | Fix commit |
|---|---|---|---|
| `skip_reparse_tag_spaces` | 2072 | - | - |
| `direct_start_tag_name` | 1936 | - | - |
| `direct_start_tag_attributes` | 1975 | #3: outer variant `a_end_index - i` does not decrease at the `/` of `<root/>` | `d9f662f` |
| `append_decoded_utf16` | 1616 | mass-xpact #12: `i` does not move on an invalid surrogate | `19ba873` |

Checked: bounds of every `a_input.item`, preconditions of every call, every loop variant (non-negative, decreasing), stated postconditions. Each routine is checked against its callees' **contracts only**, as AutoProof would.

## Command

```sh
export Z3=C:/Users/masou/Desktop/Lia/tools/z3-download/z3-4.12.1-x64-win/bin/z3.exe
sh verification/boogie/run-all.sh
```

## Expected and observed

Expected results are in the [folder README](../../verification/boogie/README.md#expected-results). Observed ([boogie-run.txt](boogie-run.txt)):

| Run | Expected | Observed | |
|---|---|---|---|
| `00-smoke` | 1 verified, 1 error | 1 verified, 1 error (line 8, wrong `max`) | ✅ |
| `01-skip-reparse-tag-spaces` | verified | 1 verified, 0 errors | ✅ |
| `02-direct-start-tag-name` | verified | 1 verified, 0 errors | ✅ |
| `03-A-before-fix` | variant error | 1 error, line 133 (variant decreases); trace lines 66-68 = the `'/'` branch | ✅ old bug found |
| `03-B-after-fix` | verified | 3 verified, 0 errors | ✅ |
| `03-C-contract-as-written` | fails | 1 error, line 43 (loop 1 variant non-negative on entry) | ✅ as expected |
| `04-UA-before-fix` | variant error | 1 error, line 68 (variant decreases) | ✅ old bug found |
| `04-UB-after-fix` | verified | 1 verified, 0 errors | ✅ |
| `04-UC-contract-as-written` | fails | 3 errors: line 39 (`index_in_bounds` on entry), lines 48 and 53 (`utf16_unit_at` precondition) | ✅ as expected |

**Vacuity check:** `assert false` added at the end of each loop body and routine in the verified models (01, 02, 03-B, 04-UB). Expected failures 1 / 1 / 2 / 2, observed 1 / 1 / 2 / 2: the "verified" results do not come from contradictory assumptions.

## Finding (open, not fixed here)

| Needed for the proof | Stated by a contract? | Can it fail at run time? |
|---|---|---|
| `direct_start_tag_name /= Void` ⇒ `a_start_index + 1 < a_end_index` | ❌ no postcondition | No: proved from the body (`02`) |
| `complete_encoded_prefix_count` result `<= input_buffer.count` | ❌ no postcondition | ❔ unknown, not modelled |
| `decoded_raw_count <= l_end` in `append_decoded_utf16` | ❌ no postcondition, no class invariant | ❔ unknown |

Cause: **confirmed** that the contracts do not state these facts (runs `03-C`, `04-UC`). Whether the last two can be false at run time is **unknown**. Possible fix: add the missing `ensure` / `invariant` clauses (separate issue and PR, with the Eiffel test matrix rerun with assertions on).

## Limitations

- The models are a **hand translation**; a proof covers the model, not the Eiffel code. AutoProof would remove that gap.
- Only bounds, preconditions, variants and stated postconditions; not functional correctness.
- Name tests, `has ('&')`, duplicate names, `max_name_length` and UTF-16 unit values are abstracted; integer overflow is not modelled.
- Eiffel test matrix and W3C runs not rerun: no Eiffel or C source changed.

## Verification

- [x] `run-all.sh` output matches every expected result ([boogie-run.txt](boogie-run.txt)).
- [x] Vacuity check 1 / 1 / 2 / 2 as expected.
- [x] `git diff --stat origin/incremental-test` touches only `verification/boogie/`, `reports/issue-0252/` and `reports/README.md`.
