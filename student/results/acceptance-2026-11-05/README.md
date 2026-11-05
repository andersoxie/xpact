# Acceptance 2026-11-05: our `student-Mass` against andersoxie `student-Mass`

> **Issue:** [CodTanium/mass-xpact#67](https://github.com/CodTanium/mass-xpact/issues/67) · **Baseline:** andersoxie `student-Mass` @ `253c81e` · **Final:** `45d2f53`
> **Full report and every log:** [`reports/acceptance-253c81e-vs-45d2f53/`](../../../reports/acceptance-253c81e-vs-45d2f53/report.md)

**Result: ✅ as good or better on every check, none worse.** Three regressions were found on the way, and all three were fixed and merged before the final numbers ([#68](https://github.com/CodTanium/mass-xpact/issues/68), [#69](https://github.com/CodTanium/mass-xpact/issues/69), [#72](https://github.com/CodTanium/mass-xpact/issues/72)).

| Check | Cases | `253c81e` | Final | |
|---|---|---|---|---|
| DLL tests, both builds | 4,308 × 2 | all pass | all pass | ✅ |
| Expat 2.8.1 `runtests` | 399 × 2 | 38 known failures | the same 38 | ⚪ |
| Eiffel test matrix | 4 lanes | 4/4 | 4/4 | ⚪ |
| W3C conformance runner | 2,585 × 2 | 1,974 pass, 0 fail | identical per case | ⚪ |
| Test 2, W3C in pieces | 2,585 | ok 2,561 | ok 2,564 | ✅ |
| W3C trace, assertions build | 3,030 files | dies at file 1,037 | all files | ✅ |
| Verdict as Expat | 3,061 files | 3,037 | 3,057 | ✅ |
| Position after every call as Expat | 495,725 calls | 122,310 | 122,827 | ✅ |
| Fuzzing, crashes (production / assertions) | 80,000 parses | 0 / 7 | 0 / 0 | ✅ |
| `doc-rich.xml` byte by byte | 131 KB | 50 min | 106 ms | ✅ |
| Threads (2 or 4 parsers in parallel) | | crash | crash ([#75](https://github.com/CodTanium/mass-xpact/issues/75)) | ⚪ |

Not done: Linux (WSL is not installed), other machines.
Session notes: [note 15](../../../docs/notes/note-15.txt), [note 16](../../../docs/notes/note-16.txt).
