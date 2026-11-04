# Speed work: session notes

Working notes from the 2026-11-03/04 sessions that made XPact faster. Each fix has its own issue,
PR and report; the notes record the order of the work, the traps, and how to repeat the checks.

## 1. Status at a glance

| | Work | Issue | PR | Effect | Report |
|---|---|---|---|---|---|
| ✅ | Chunked parsing resumes instead of re-parsing the whole buffer | [#2](https://github.com/CodTanium/mass-xpact/issues/2) | [#4](https://github.com/CodTanium/mass-xpact/pull/4) | square growth → linear | `reports/mass-xpact-issue-0002/` |
| ✅ | Test 2 harness runs cases in parallel | [#5](https://github.com/CodTanium/mass-xpact/issues/5) | [#6](https://github.com/CodTanium/mass-xpact/pull/6) | 15:30 → 5:02 | `reports/issue-0165/` |
| ✅ | UTF-16 input resumes too | [#7](https://github.com/CodTanium/mass-xpact/issues/7) | [#8](https://github.com/CodTanium/mass-xpact/pull/8) | 70.5 s → 0.18 s (313 KB, 256-byte pieces) | `reports/mass-xpact-issue-0007/` |
| ✅ | W3C runner `--jobs` | [#9](https://github.com/CodTanium/mass-xpact/issues/9) | [#10](https://github.com/CodTanium/mass-xpact/pull/10) | 40 s → 9 s | |
| ✅ | Long text runs continue instead of re-parsing | [#11](https://github.com/CodTanium/mass-xpact/issues/11) | [#13](https://github.com/CodTanium/mass-xpact/pull/13) | pr-xml-utf-8 byte by byte 72.6 s → 9.9 s | `reports/mass-xpact-issue-0011/` |
| ✅ | Assertions regression from #7 (UTF-16 loop variant) | [#12](https://github.com/CodTanium/mass-xpact/issues/12) | in [#8](https://github.com/CodTanium/mass-xpact/pull/8) | 40 → 38 expected Expat failures | `reports/mass-xpact-issue-0012/` |
| ✅ | Production DLL finalized without `-keep` | [#14](https://github.com/CodTanium/mass-xpact/issues/14) | [#16](https://github.com/CodTanium/mass-xpact/pull/16) | whole parse 3.5× faster | `reports/mass-xpact-issue-0014/` |
| ✅ | Eiffel inlining for the production DLL | [#17](https://github.com/CodTanium/mass-xpact/issues/17) | [#18](https://github.com/CodTanium/mass-xpact/pull/18) | whole parse 15–20 % faster | `reports/mass-xpact-issue-0017/` |
| 📝 | Session notes collected here | | [#19](https://github.com/CodTanium/mass-xpact/pull/19) | | |
| ⬜ | Assertions DLL crash on `ibm68n03.xml` (default handler only) | [#3](https://github.com/CodTanium/mass-xpact/issues/3) | | | |
| ⛔ | Static `STRING_8` scanner input: 20 % faster, but an intermittent crash; **parked** | [#20](https://github.com/CodTanium/mass-xpact/issues/20) | [#21](https://github.com/CodTanium/mass-xpact/pull/21) (draft) | whole parse 14.1 → 11.3 ms | `reports/mass-xpact-issue-0020/` |
| ⬜ | `build_native_eiffel.ps1` relinks stale code when `ec` rejects its options | [#15](https://github.com/CodTanium/mass-xpact/issues/15) | | | |

Report folders are on the PR branches until the PRs are merged. Raw Test 2 outputs of every build
(TSV + summary per run) are in [`reports/issue-0165/tools/logs/`](../../reports/issue-0165/tools/logs/).

### Merge order

- [ ] #4 → retarget #8 to `student-Mass` → #8 → retarget #13 → #13
- [ ] #16 → retarget #18 to `student-Mass` → #18
- [ ] #6, #10 and #19: any time
- [ ] ⛔ #21: **do not merge** until #20 is solved

Retarget a stacked PR **before** deleting the branch under it, or GitHub closes it.

## 2. Next work

- [ ] [#20](https://github.com/CodTanium/mass-xpact/issues/20): find the crash behind the static-input change (note 10)
- [ ] Parser code hot spots after #17: `append_character`
  (hash reset), string allocation, `note_position`
- [ ] Per-call overhead of `XML_Parse` (byte by byte is still several times slower than one call)
- [ ] Carry text runs that a default handler also sees
- [ ] Resume for Latin-1 / ASCII input
- [ ] The 73 split-point differences in error documents: compare with Expat first
- [ ] [#15](https://github.com/CodTanium/mass-xpact/issues/15): fail the build when `ec` did not recompile

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
