# C02: final-input regressions (2026-10-26)

> **Issue:** [#128](https://github.com/andersoxie/xpact/issues/128) · **Draft:** [13-C02](../../github/issues/13-C02.md) · **Date:** 2026-10-26
> · Report and logs: [`reports/issue-0128/`](../../../reports/issue-0128/report.md)

## In short

| | |
|---|---|
| 🎯 Goal | The inputs that found [#38](https://github.com/andersoxie/xpact/issues/38), [#39](https://github.com/andersoxie/xpact/issues/39) and [#40](https://github.com/andersoxie/xpact/issues/40) become permanent tests that run in every build and on Jenkins |
| ✅ Where | the **DLL smoke test** (`tests/native/xpact_eiffel_dll_smoke.c`, run on both DLLs by `build_native_eiffel.ps1`) and the **Eiffel suite** (`tests/xp_test_root.e`, run 4 times by `run_eiffel_test_matrix.ps1`) |
| ✅ Today | both DLLs: `smoke: ok`; Eiffel matrix **4/4 ok** (MSVC) |
| ✅ They catch the bugs | with the #38 fix undone the new smoke check fails on `<root>`; with the #40 fix undone the new Eiffel test fails (loop invariant). The old tests caught #40 only in the smoke test and **#38 nowhere** |

## What is tested

| Input | Expected | Found |
|---|---|---|
| `<root/>`, `<root></root>`, `<root>hi</root>` | accepted; one start and one end event | #38 lost the end event of `<root></root>` |
| empty input | rejected, error 3 (no elements) | |
| `<root>` | rejected, error 3 | #38 accepted it with a start handler |
| `<root><child></root>` | rejected, error 7 (tag mismatch) | #38 accepted it with a start handler |
| `<root/>junk` | rejected (code not checked: [#124](https://github.com/andersoxie/xpact/issues/124)) | |
| 6 bad UTF-8 sequences × 6 places (text, attribute, name, comment, PI, CDATA) | rejected, error 4 (invalid token) | #39 accepted them |
| `é` (`C3 A9`) in the same 6 places | accepted (control) | |

Every input is run whole, split at every byte (non-final + final) and byte by
byte (#40: a non-final chunk ending in `<`).

| Test | Parser | Callback sets | Inputs × chunkings |
|---|---|---|---|
| `check_final_input_regressions` (C) | the DLL through `XML_Parse` | none, start, end, start+end, chardata, default | 49 inputs, every split |
| `test_final_input_regressions` (Eiffel) | `XP_PARSER` whole, `XP_NATIVE_PARSER` every split | the parser's own handler | 49 inputs, every split |

#38 needs a callback registered through the C API, so only the C test can
reach it.

## Proof that they catch the bugs

| Fix undone (in a scratch build, then restored) | New tests | Tests before #128 |
|---|---|---|
| #38 (`src/xp_native_parser.e`, shortcut on the final call) | ❌ smoke: `FAIL: final input <root>, handlers 1, split 0 of 6: error 0, expected 3` | ✅ smoke passes, **bug not caught** |
| #40 (`src/xp_parser.e`, start index not clamped) | ❌ Eiffel: `test_final_input_regressions` raised `index_in_bounds` loop invariant; ❌ smoke crashes `0xC0000028` | Eiffel: not caught; smoke: crashes too (an older check reaches the same code) |
| #39 (UTF-8 decoding) | not undone: the fix is spread over many features | the 2026-10-22 run shows these inputs accepted by the old DLLs ([dll-tests-2026-10-22](../dll-tests-2026-10-22/README.md)) |

## Done when (draft 13)

- [x] Cases: `<root/>` accept, `<root>` reject, `<root><child></root>` reject, trailing junk reject
- [x] Each case run with every callback configuration
- [x] Expected status written down before running
- [x] Regressions added to the test suite; results here
- [ ] For rejected documents: no document-completion callback, and no events after the error. *Not checked as a rule here; the Expat comparison found one event of the faulty token itself ([#125](https://github.com/andersoxie/xpact/issues/125))*
