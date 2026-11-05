# Acceptance: our `student-Mass` against andersoxie `student-Mass`

> **Issue:** [CodTanium/mass-xpact#67](https://github.com/CodTanium/mass-xpact/issues/67) · **Date:** 2026-11-05
> **Baseline:** andersoxie `student-Mass` @ `253c81e` (2026-11-03) · **Final:** CodTanium `student-Mass` @ `45d2f53`
> **Status:** ✅ the final version is **as good or better on every check**; 3 regressions found on the way, all fixed (#68, #69, #72)

## 1. The answer in one table

✅ = final as good or better · ⚪ = the same, also with the same known problem · ❌ = final worse

| # | Check | Cases | Baseline `253c81e` | Final `45d2f53` | |
|---|---|---|---|---|---|
| 1 | DLL tests (C#), both builds | 4,308 × 2 | 4,308 pass | 4,308 pass; 1 row changed, now = Expat | ✅ |
| 2 | Expat 2.8.1's own suite (`runtests`), both builds | 399 × 2 | 361 pass, 38 known allocator tests fail | the same 361 / 38 | ⚪ |
| 3 | Eiffel test matrix (direct parser) | 4 lanes | 4/4 ok | 4/4 ok | ⚪ |
| 4 | W3C conformance runner, both builds | 2,585 × 2 | 1,974 pass, 0 fail, 611 skipped | the same, every case identical | ⚪ |
| 5 | Test 2: W3C in pieces | 2,585 × 2 | ok 2,561 · XPact-only 19 · both 5 | **ok 2,564** · XPact-only 16 · both 5 | ✅ |
| 6 | W3C trace (every callback), 9 modes | ~3,000 files × 9 | production ok; **assertions build dies at file 1,037 of 3,030** with a default handler | production: 20 files changed, now as Expat; assertions: **all 3,030 / 3,061 files** | ✅ |
| 7 | Chunked CRC harness · corpus gate · shim audit, both builds | 54 · 182 · 6 rows | | identical | ⚪ |
| 8 | Same result as Expat, 3,061 W3C files, no handlers, whole | 3,061 | verdict 3,037 · + code 2,676 · + line/column 1,524 | **3,057 · 2,696 · 1,544** | ✅ |
| 9 | Position after every call vs Expat, all W3C files | 495,725 calls (1 byte) · 72,000 (7 bytes) | 122,310 · 14,863 | **122,827 · 15,357** | ✅ |
| 10 | **Fuzzing**, 20,000 mutated documents × 4 ways, production | 80,000 parses | 0 crashes · verdict = Expat 79,940 | 0 crashes · **79,960**; 68 results closer to Expat, **0 further** | ✅ |
| 11 | Fuzzing, assertions build | 80,000 parses | **7 crashes** | **0 crashes** | ✅ |
| 12 | Skipped-entity callbacks without an external-entity handler | 6 cases | 0/6 as Expat | **6/6 as Expat** | ✅ |
| 13 | Speed (section 4) | 10 + 5 rows | | 4×–28,000× faster in pieces; whole parse 7× (DLL) | ✅ |
| 14 | Threads: 2 or 4 threads, each with its own parser | 4,000 / 8,000 parses | crashes | crashes (Expat: all correct) | ⚪ #75 |
| 15 | Linux, other machines | | not run | not run (no WSL, one PC) | — |

**No check is worse.** The only differences between the two versions are the fixes listed in section 3.

## 2. How this was done

- **Reused** everything recorded for `253c81e` at the start of our work ([mass-xpact #2](../mass-xpact-issue-0002/report.md)): DLL tests, trace, Test 2, CRC, shim audit, timing. Its built DLLs (`build/baseline/`) were used for what had not been recorded: the Expat suite on both builds, the Expat comparison, per-call positions, fuzzing and threads.
- **Built from a local worktree of `253c81e`** only what needs the source: the Eiffel test matrix and the benchmark/W3C-conformance runner. Nothing was pushed to andersoxie.
- **Expat 2.8.1** is the referee: it is compiled into the same probes, so every difference is judged by what Expat does.
- Same PC for everything: Windows 11, AMD Ryzen 7 5800H, EiffelStudio 25.12, MSVC `msc_vc140`.

## 3. What changed between the two versions, and why

Every difference found was traced to an issue. None is unexplained.

| Difference | Where seen | Issue | Expat? |
|---|---|---|---|
| Unread external entities without a handler: no code 21 | #8, #6 (20 files), #12 | [#64](https://github.com/CodTanium/mass-xpact/issues/64), [#69](https://github.com/CodTanium/mass-xpact/issues/69) | ✅ now as Expat |
| Assertions build no longer dies on `ibm68n03.xml` | #6 | [#3](https://github.com/CodTanium/mass-xpact/issues/3) | ✅ |
| Big `pr-xml-*` documents no longer time out in pieces | #5 (3 rows) | [#2](https://github.com/CodTanium/mass-xpact/issues/2), UTF-16 fixes | ✅ |
| Malformed UTF-8 byte by byte: error at call 5, not 6 | #1 (1 row) | [#2](https://github.com/CodTanium/mass-xpact/issues/2) (found now; #2's report compared pass counts only) | ✅ Expat: call 5 |
| Positions between calls | #9 | [#68](https://github.com/CodTanium/mass-xpact/issues/68) | ✅ closer |
| Assertions build no longer dies on 7 fuzzed documents | #11 | [#72](https://github.com/CodTanium/mass-xpact/issues/72) | ✅ |
| Billion-laughs documents: code 43 and Expat's rule | separate test documents | [#60](https://github.com/CodTanium/mass-xpact/issues/60) | ✅ |
| Speed | #13 | #2 – #57 | — |

### 3.1 Found by this acceptance run

| Found | What | Status |
|---|---|---|
| 🔴 **Regression** | Between calls, the position pointed inside unfinished markup (26,295 calls worse than `253c81e`) | ✅ fixed, [#68](https://github.com/CodTanium/mass-xpact/issues/68) |
| 🔴 **Regression** | The #64 fix broke 3 Eiffel test-matrix assertions (#64 had not been checked with the matrix) | ✅ fixed, [#69](https://github.com/CodTanium/mass-xpact/issues/69) |
| 🟠 Bug, in both | Assertions build died on 7 fuzzed documents (`</£`, `(#PCDATA>`) | ✅ fixed, [#72](https://github.com/CodTanium/mass-xpact/issues/72) |
| 🟠 Bug, in both | An unrescued Eiffel exception in a DLL call jumps into the returned `DllMain` frame: no trace (`0xC00000FF`) | ⬜ open, [#73](https://github.com/CodTanium/mass-xpact/issues/73) (probably also andersoxie#13) |
| 🟡 Difference, in both | Error code depends on the pieces for 63 of 20,000 fuzzed documents | ⬜ open, [#74](https://github.com/CodTanium/mass-xpact/issues/74) |
| 🟡 Limitation, in both | Not thread-safe: 2 threads crash the DLL; not documented | ⬜ open, [#75](https://github.com/CodTanium/mass-xpact/issues/75) |
| ⚪ Environment, in both | Eiffel matrix lane 4 stops in a full run, passes alone | ⬜ open, [#77](https://github.com/CodTanium/mass-xpact/issues/77) |

## 4. Speed (same PC, alternating runs)

**Chunked DLL timing** (`run-tools.ps1 -Run Timing`; same checksums everywhere; [final run 1](logs/speed/chunked-timing-final1.tsv), [baseline today](logs/speed/chunked-timing-base.tsv), [final run 2](logs/speed/chunked-timing-final2.tsv), [baseline recorded 2026-11-03](logs/speed/chunked-timing-baseline-recorded-2026-11-03.tsv)):

| Document, piece size | Baseline | Final | Faster |
|---|---|---|---|
| `doc-rich.xml` (131 KB), 1 byte | 3,024,266 ms (**50 min**) | 106 ms | ~28,500× |
| `doc-rich.xml`, 16 bytes | 200,812 ms (recorded 214,516) | 25 ms | ~8,000× |
| `doc-rich.xml`, 256 bytes | 12,606 ms | 16–24 ms | ~600× |
| `doc-rich.xml`, 4,096 bytes | 956 ms | 15.5 ms | ~60× |
| `doc-rich.xml`, whole | 107.6 ms | 15.2 ms | 7× |
| `doc-plain.xml` (43 KB), 1 byte | 344,219 ms (5.7 min) | 35 ms | ~9,800× |
| `doc-plain.xml`, 16 bytes | 21,856 ms | 9.9 ms | ~2,200× |
| `doc-plain.xml`, whole | 38.1 ms | 6.5–10.2 ms | ~4–6× |

**Anders's benchmark suite** (`run_benchmarks.ps1 -SkipWslC`, catalog with 100 items, 1,000 iterations, median of 3 repetitions; 4 runs each, alternating; [tables](logs/speed/)):

| Row | Baseline (4 runs) | Final (4 runs) | |
|---|---|---|---|
| Native C ABI with callbacks | 1,366 / 1,467 / 1,490 / 1,404 ms | 352 / 363 / 379 / 352 ms | ✅ ~4× |
| Native C ABI tokenizer | 550 / 581 / 596 / 573 ms | 108 / 104 / 111 / 105 ms | ✅ ~5.4× |
| Eiffel direct parser, assertions off | 132 / 130 / 132 / 132 ms | **623** / 125 / 124 / 126 ms | ✅ ~5 % faster; the 623 was one outlier, not seen again in 3 reruns |
| Eiffel direct parser, assertions on | 1,402 – 1,523 ms | 1,437 – 1,463 ms | ⚪ the same |
| libexpat through Python (reference) | 94 – 109 ms | 100 – 103 ms | ⚪ the same machine load |

## 5. Details per check

<details><summary>1. DLL tests</summary>

4,308 cases (whole, split at every byte, byte by byte, with and without callbacks), production and assertions DLL. Both versions pass all. One row differs ([diff](logs/dlltests/)): `utf8-bad-continuation-text/none/bytes` (`<r>\xc3(</r>` byte by byte) now fails at call 5 instead of 6; Expat fails at call 5 ([probe](logs/tools/failcall.c)). Bisected over the saved builds: it changed with the first #2 build.
</details>

<details><summary>2. Expat 2.8.1 runtests</summary>

399 checks on both builds of both versions; the same 38 failures (allocator-injection tests that XPact does not support) by name ([logs](logs/expat-runtests/)).
</details>

<details><summary>3. Eiffel test matrix</summary>

Assertions off/on × Workbench/Finalized. Both versions 4/4 ([baseline](logs/matrix/baseline.txt), [final](logs/matrix/final.txt)). In full runs lane 4 stopped with "Cannot create project directory" in both versions and passed alone (#77). Before #69 the final version failed 3 assertions in lane 1.
</details>

<details><summary>4. W3C conformance runner</summary>

`run_benchmarks.ps1`, Finalized and FinalizedAssertions: 2,585 catalog cases each, 1,974 passed, 0 failed, 0 errors, 611 skipped, in both versions; 0 cases with a different result ([results](logs/w3c-conformance/)).
</details>

<details><summary>5. Test 2</summary>

3 rows changed of 2,585 ([diff](logs/test2/)): `pr-xml-little`, `pr-xml-utf-16`, `pr-xml-utf-8` were a 300 s TIMEOUT and now pass. The 16 XPact-only and 5 "both" rows are the same in both versions.
</details>

<details><summary>6. W3C trace</summary>

Production: the 9 traces of the final version differ from `253c81e` only in the 20 #64 files, which now end with Expat's status and error in every mode. Assertions: with a default handler the `253c81e` assertions DLL died at file 1,037 of 3,030 (1,057 of 3,061) on `ibm68n03.xml` (#3); the final one completes all files with the same output as production ([hashes](logs/trace/), [completeness](logs/trace/assertions-completeness.txt)).
</details>

<details><summary>8-9. Expat comparison and positions</summary>

No-handler probe, whole and in 1/7/16-byte pieces ([tables](logs/expat-comparison/)): at every piece size the final version is closer to or as close to Expat, 0 files further. Positions after every call ([summary](logs/per-call-positions/)); the regression found in the first comparison is in [between-call-positions](logs/between-call-positions/) and was fixed in #68.
</details>

<details><summary>10-11. Fuzzing</summary>

`fuzzgen.py` (seed 67) mutates the W3C files ≤ 4 KB: byte flips, random bytes, deletions, duplications, splices, truncation, and XML fragments (`<![CDATA[`, `]]>`, `&#xD800;`, invalid UTF-8, CR, NUL, deep nesting, long names). Each document is parsed whole, byte by byte, in 7-byte and in seeded random pieces, with element, text, PI and comment handlers. `fuzzrun.py` restarts the probe after a crash or hang ([tools](../mass-xpact-issue-0072/logs/tools/), [production](logs/fuzz/production/summary.txt), [assertions](logs/fuzz/assertions/summary.txt)).

| Measure (80,000 parses) | Baseline | Final |
|---|---|---|
| Crashes / hangs, production | 0 | 0 |
| Crashes / hangs, assertions | 7 | 0 |
| Verdict as Expat | 79,940 | 79,960 |
| Verdict and error code as Expat | 54,595 | 54,639 |
| Accepted documents with Expat's events | 2,456 / 2,460 | 2,476 / 2,480 |
| The same answer whole and in pieces | 19,937 / 20,000 documents | 19,937 (Expat 19,992) → #74 |
</details>

<details><summary>14. Threads</summary>

[`threads.c`](logs/threads/threads.c): each thread creates its own parser and parses a small document 2,000 times. Expat: 2,000 / 4,000 / 8,000 correct with 1 / 2 / 4 threads. Both XPact versions: 1 thread correct, 2 and 4 threads crash. Cause: the Eiffel runtime is built without thread support (`concurrency support="none"`) (#75).
</details>

## 6. What the andersoxie repository offers for our open problems

- `student-Mass` (`253c81e`), `main` and every `codex/*` branch are already in our history; the only newer branches are our own drafts (#227 memory cap, #233 Docker).
- No fix for #20 (heap corruption) or for #170, #171, #126, #123, #176.
- **Technique we use:** PR #84 runs every Expat test in its own process, because a `longjmp` out of a failing callback broke the Eiffel GC state for the next test. Our Expat-suite runs use that runner. #73 is the same kind of problem inside the DLL.
- An option to switch the GC off during a parse (`suspend_gc_during_parse`); a workaround, not a fix.

## 7. Limitations of this result

- [ ] One PC only; no Linux run (WSL is not installed) and no other machines.
- [ ] Fuzzing is 20,000 documents with one seed and one handler set; it found 2 bugs, so more seeds would likely find more.
- [ ] #20 (heap corruption under GC stress) was left out on request; it exists in both versions.
- [ ] The tests show what they cover. They do not prove that there are no other faults.
