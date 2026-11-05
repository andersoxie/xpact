# Speed work: session notes

Working notes from the 2026-11-03/04 sessions that made XPact faster. Each fix has its own issue,
PR and report; the notes record the order of the work, the traps, and how to repeat the checks.

> **Updated 2026-11-04 (evening).** ✅ **All speed PRs are merged into `student-Mass`** (`8ccf51b`; #21 later the same evening) and
> verified together: [post-merge check](../../reports/mass-xpact-merge-2026-11-04/report.md). The GC heap corruption (#20)
> turned out to be **already in `student-Mass`** (equal-load test), so it did not block #16 and #18 after all.

## 1. Status at a glance

✅ merged · 🟡 open, waiting · ⛔ blocked · ⬜ not started

| | Work | Issue | PR | Effect | Report |
|---|---|---|---|---|---|
| ✅ | Test 2 harness runs cases in parallel | [#5](https://github.com/CodTanium/mass-xpact/issues/5) | [#6](https://github.com/CodTanium/mass-xpact/pull/6) | 15:30 → 5:02 | [0005](../../reports/mass-xpact-issue-0005/report.md) |
| ✅ | W3C runner `--jobs` | [#9](https://github.com/CodTanium/mass-xpact/issues/9) | [#10](https://github.com/CodTanium/mass-xpact/pull/10) | 40 s → 9 s | [0009](../../reports/mass-xpact-issue-0009/report.md) |
| ✅ | Session notes and all reports on `student-Mass` | | [#19](https://github.com/CodTanium/mass-xpact/pull/19), [#22](https://github.com/CodTanium/mass-xpact/pull/22) | | |
| ✅ | Chunked parsing resumes instead of re-parsing the whole buffer | [#2](https://github.com/CodTanium/mass-xpact/issues/2) | [#4](https://github.com/CodTanium/mass-xpact/pull/4) | square growth → linear | [0002](../../reports/mass-xpact-issue-0002/report.md) |
| ✅ | UTF-16 input resumes too | [#7](https://github.com/CodTanium/mass-xpact/issues/7) | [#8](https://github.com/CodTanium/mass-xpact/pull/8) | 70.5 s → 0.18 s (313 KB, 256-byte pieces) | [0007](../../reports/mass-xpact-issue-0007/report.md) |
| ✅ | Assertions regression from #7 (UTF-16 loop variant) | [#12](https://github.com/CodTanium/mass-xpact/issues/12) | in [#8](https://github.com/CodTanium/mass-xpact/pull/8) | 40 → 38 expected Expat failures | [0012](../../reports/mass-xpact-issue-0012/report.md) |
| ✅ | Long text runs continue instead of re-parsing | [#11](https://github.com/CodTanium/mass-xpact/issues/11) | [#13](https://github.com/CodTanium/mass-xpact/pull/13) | pr-xml-utf-8 byte by byte 72.6 s → 9.9 s | [0011](../../reports/mass-xpact-issue-0011/report.md) |
| ✅ | Build stops when `ec` generated no new C | [#15](https://github.com/CodTanium/mass-xpact/issues/15) | [#23](https://github.com/CodTanium/mass-xpact/pull/23) | no silent stale DLLs | [0015](../../reports/mass-xpact-issue-0015/report.md) |
| ✅ | Production DLL finalized without `-keep` | [#14](https://github.com/CodTanium/mass-xpact/issues/14) | [#16](https://github.com/CodTanium/mass-xpact/pull/16) | whole parse 3.5× faster | [0014](../../reports/mass-xpact-issue-0014/report.md) |
| ✅ | Eiffel inlining for the production DLL | [#17](https://github.com/CodTanium/mass-xpact/issues/17) | [#18](https://github.com/CodTanium/mass-xpact/pull/18) | whole parse 15–20 % faster | [0017](../../reports/mass-xpact-issue-0017/report.md) |
| ✅ | Static `STRING_8` scanner input | | [#21](https://github.com/CodTanium/mass-xpact/pull/21) | whole parse 14.1 → 11.3 ms | [0020](../../reports/mass-xpact-issue-0020/report.md) |
| ✅ | Search for `encoding` only inside the XML declaration (input in pieces was quadratic) | [#31](https://github.com/CodTanium/mass-xpact/issues/31) | [#32](https://github.com/CodTanium/mass-xpact/pull/32) | pr-xml-utf-8 byte by byte 2,857 → 438 ms | [0031](../../reports/mass-xpact-issue-0031/report.md) |
| ✅ | Resume the search for the end of a delayed DOCTYPE (no rescan of the internal subset) | [#34](https://github.com/CodTanium/mass-xpact/issues/34) | [#35](https://github.com/CodTanium/mass-xpact/pull/35) | pr-xml-utf-8 byte by byte 437 → 319 ms | [0034](../../reports/mass-xpact-issue-0034/report.md) |
| ✅ | Check the XML declaration without per-call allocations | [#37](https://github.com/CodTanium/mass-xpact/issues/37) | [#38](https://github.com/CodTanium/mass-xpact/pull/38) | pr-xml-utf-8 byte by byte 334 → 286 ms | [0037](../../reports/mass-xpact-issue-0037/report.md) |
| ✅ | Keep the declared encoding of a complete XML declaration | [#40](https://github.com/CodTanium/mass-xpact/issues/40) | [#41](https://github.com/CodTanium/mass-xpact/pull/41) | pr-xml-utf-8 byte by byte 290 → 236 ms | [0040](../../reports/mass-xpact-issue-0040/report.md) |
| ✅ | Copy each input chunk once instead of twice | [#43](https://github.com/CodTanium/mass-xpact/issues/43) | [#44](https://github.com/CodTanium/mass-xpact/pull/44) | pr-xml-utf-8 byte by byte 248 → 217 ms | [0043](../../reports/mass-xpact-issue-0043/report.md) |
| ✅ | Reuse one string for small input chunks | [#46](https://github.com/CodTanium/mass-xpact/issues/46) | [#47](https://github.com/CodTanium/mass-xpact/pull/47) | pr-xml-utf-8 byte by byte 219 → 200 ms | [0046](../../reports/mass-xpact-issue-0046/report.md) |
| ✅ | Answer the UTF-16 checks from a known XML declaration | [#48](https://github.com/CodTanium/mass-xpact/issues/48) | [#49](https://github.com/CodTanium/mass-xpact/pull/49) | pr-xml-utf-8 byte by byte 198 → 184 ms | [0048](../../reports/mass-xpact-issue-0048/report.md) |
| ✅ | Count positions only once over a continued text run (long text runs were quadratic) | [#51](https://github.com/CodTanium/mass-xpact/issues/51) | [#52](https://github.com/CodTanium/mass-xpact/pull/52) | 100 KB text run byte by byte 7,394 → 102 ms; pr-xml-utf-8 184 → 145 ms | [0051](../../reports/mass-xpact-issue-0051/report.md) |
| ✅ | Without a character-data handler, count plain text bytes after a pending text run without parsing them | [#53](https://github.com/CodTanium/mass-xpact/issues/53) | [#55](https://github.com/CodTanium/mass-xpact/pull/55) | 100 KB run, 16-byte pieces, no handlers 1,622 → 3.6 ms | [0053](../../reports/mass-xpact-issue-0053/report.md) |
| ✅ | Drop the per-call allocations of the reparse-deferral checks | [#57](https://github.com/CodTanium/mass-xpact/issues/57) | [#58](https://github.com/CodTanium/mass-xpact/pull/58) | pr-xml-utf-8 byte by byte 145 → 134 ms | [0057](../../reports/mass-xpact-issue-0057/report.md) |
| ✅ | **Billion laughs:** Expat's amplification rule and code 43 instead of a fixed 8 MiB cap and "syntax error" (from andersoxie#211) | [#60](https://github.com/CodTanium/mass-xpact/issues/60) | [#62](https://github.com/CodTanium/mass-xpact/pull/62) | all 8 test documents match Expat; a legitimate 1 MB document is no longer rejected | [0060](../../reports/mass-xpact-issue-0060/report.md) |
| ⬜ | With very strict custom billion-laughs settings, XPact rejects 2 documents Expat accepts | [#61](https://github.com/CodTanium/mass-xpact/issues/61) | | | |
| 🔴 | **Pre-existing** heap corruption under GC stress and load (`test_deep_nested_attribute_entity`) | [#20](https://github.com/CodTanium/mass-xpact/issues/20) | | | [0020](../../reports/mass-xpact-issue-0020/report.md) |
| ✅ | Assertions DLL crash on `ibm68n03.xml` (default handler only): name checked before `is_predefined_entity` | [#3](https://github.com/CodTanium/mass-xpact/issues/3) | [#25](https://github.com/CodTanium/mass-xpact/pull/25) | assertions DLL no longer dies | [0003](../../reports/mass-xpact-issue-0003/report.md) |

All reports are also listed in [`reports/README.md`](../../reports/README.md#speed-work-codtaniummass-xpact-2026-110304).
Raw Test 2 outputs of every build (TSV + summary per run) are in [`reports/issue-0165/tools/logs/`](../../reports/issue-0165/tools/logs/).

### Merge order

- [x] #6, #10, #19, #22 (2026-11-04)
- [x] #4 → #8 → #13 → #23 → #16 → #18 (2026-11-04, `student-Mass` @ `8ccf51b`), [verified together](../../reports/mass-xpact-merge-2026-11-04/report.md)
- [x] #25 (#3, 2026-11-04)
- [x] #21 (2026-11-04, after the equal-load check: 23/24 against `student-Mass` 24/24)
- [x] #32 (#31, 2026-11-04)
- [x] #35 (#34, 2026-11-04)
- [x] #38 (#37, 2026-11-04)
- [x] #41 (#40, 2026-11-04)
- [x] #44 (#43, 2026-11-04)
- [x] #47 (#46) and #49 (#48), 2026-11-05
- [x] #52 (#51), 2026-11-05
- [x] #55 (#53), 2026-11-05
- [x] #58 (#57), 2026-11-05
- [x] #62 (#60), 2026-11-05

Retarget a stacked PR **before** deleting the branch under it, or GitHub closes it.

## 2. Next work

- [ ] [#20](https://github.com/CodTanium/mass-xpact/issues/20): **pre-existing** heap corruption under GC stress and load; every build crashes at about the same rate at equal load (note 12)
- [ ] Parser code hot spots after #17: `append_character`
  (hash reset), string allocation, `note_position`
- [ ] Per-call overhead of `XML_Parse` (byte by byte is still several times slower than one call)
- [ ] Carry text runs that a default handler also sees
- [ ] Resume for Latin-1 / ASCII input
- [ ] The 73 split-point differences in error documents: compare with Expat first
- [x] [#15](https://github.com/CodTanium/mass-xpact/issues/15): fail the build when `ec` did not recompile (#23)

## 3. The notes, in order

| Note | Date | Topic |
|---|---|---|
| [improvement-plan.txt](improvement-plan.txt) | 2026-11-03 | First analysis: ten improvements, highest impact first |
| [note-01.txt](note-01.txt) | 2026-11-03 | Incremental parsing (#2): setup and first findings |
| [note-02.txt](note-02.txt) | 2026-11-03 | Incremental parsing: implementation v1 → v2 |
| [note-03.txt](note-03.txt) | 2026-11-03 | Incremental parsing: verification tools and v3 |
| [note-04.txt](note-04.txt) | 2026-11-03 | Incremental parsing: v4, v5, findings, GitHub state |
| [note-05.txt](note-05.txt) | 2026-11-03 | Incremental parsing done: where things stand |
| [note-06.txt](note-06.txt) | 2026-11-03 | The Expat suite found an accounting bug (fixed); how to run the Expat suite |
| [note-07.txt](note-07.txt) | 2026-11-03 | Parallel Test 2 (#5), UTF-16 resume (#7), **verification recipe** |
| [note-08.txt](note-08.txt) | 2026-11-03 | Text runs (#11), assertions regression (#12) |
| [note-09.txt](note-09.txt) | 2026-11-04 | `-keep` (#14), inlining (#17), **profiler how-to** |
| [note-10.txt](note-10.txt) | 2026-11-04 | Static input (#20): parked on a crash; **flaky-test and GC-stress how-to** |
| [note-11.txt](note-11.txt) | 2026-11-04 | #20 narrowed: **#16 exposes a GC heap corruption**; in-process crash probe how-to |
| [note-12.txt](note-12.txt) | 2026-11-04 | #20 is **pre-existing** (equal-load test); watchpoint found the `BOOLEAN` table; everything merged |
| [note-13.txt](note-13.txt) | 2026-11-04 | Speed rounds #31, #34, #37, #40: **byte by byte 12× faster**; how a profile round goes |
| [note-14.txt](note-14.txt) | 2026-11-05 | **Long text runs were quadratic** (#51, up to 72× faster); profile with handlers too |

<details>
<summary>Traps worth knowing (from the notes)</summary>

- `python` on PATH is the Microsoft Store stub; use uv's `python.exe` (note 9).
- The test harness's `engines.load()` caches the first DLL in a process: compare DLLs in separate processes (note 8).
- `engines.load()` needs an absolute DLL path (`cygpath -aw`), else WinError 87 (note 9).
- Run the Expat suite on **both** DLL tiers; loop variants are only checked on the assertions tier (note 8).
- A build log without `System Recompiled.` means the old generated C was linked (note 9, #15).
- In PowerShell 5.1 a one-element `if/else` array becomes a string; splatting it passes characters (note 9).
- A `READABLE_STRING_8` passed to a `STRING_8` parameter compiles through an obsolete implicit copy (`as_string_8`); count the warnings (note 10).
- A flaky test needs counted runs and GC stress (`EIF_MEMORY_SCAVENGE`, `EIF_FULL_COLLECTION_PERIOD`), not one rerun (note 10).
- The Test 2 parallel runner writes to `reports/issue-0165/tools/logs/` (note 6).

</details>
