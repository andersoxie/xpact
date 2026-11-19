# Making the parser faster (2026-11-16)

[← reports](../README.md) · branch `perf/parser-allocations` (uncommitted) · status: ✅ **steps 1-4 passed the full acceptance run** (2026-11-16), not committed

## Result

> ✅ **Through the DLL (steps 1-4), idle, 60 cells: median 1.07×; 4 KB / 64 KB pieces 1.10× / 1.11×; elements 1.16×,
> DTD 1.09×, namespaces 1.08×; 0 checksum mismatches; xpact vs Expat 18.27× → 17.15× slower**
> ([comparison](logs/speed-compare-idle-step4.txt)). Steps 3-4 target the DLL path found with the DLL profile below.
>
> ⚠️ The table right below is for the **Eiffel API with a null event handler** (the probe).
> Through the **C API / xpact.dll** (how programs and the website use xpact) the gain is much smaller: fair speed test,
> idle PC, 60 cells (5 shapes × 1 MB × 6 piece sizes × callbacks on/off): **median 1.01×**, DTD documents **1.10×**,
> 0 checksum mismatches ([idle comparison](logs/speed-compare-idle.txt)). Reason: with a real handler the parser takes the
> end-tag path that builds a name string per end tag (`wants_end_element_events`), which steps 1a/1b do not touch;
> step 2 (entities) helps both paths. xpact vs Expat: median 18.27× → 17.92× slower.

### Eiffel API (probe, null handler)

1 MB inputs from the fair speed test (`benchmarks/fair_speed/gen_inputs.py`), 20 parses each, finalized single-threaded
probe ([xp_alloc_probe.e](xp_alloc_probe.e)), median of 3-5 alternating runs ([bench.py](bench.py)):

| Input (1 MB × 20) | Before | After (step 2) | Speed-up |
|---|---:|---:|---:|
| nested elements | 873 ms | 709 ms | **1.23×** |
| many attributes | 368 ms | 333 ms | 1.11× |
| plain text | 189 ms | 176 ms | 1.07× |
| DTD with entity references | 1,866 ms | 1,279 ms | **1.46×** |
| namespaces | 542 ms | 418 ms | **1.30×** |

✅ Same results: test 2 (all 2,585 W3C documents, whole / byte by byte / every split, events compared with Expat) gives a
**byte-identical** report with the changed DLL (`build/native-eiffel-perf/xpact.dll` `13f66b07…`) and with the tested DLL `adae03d2…`.

## How the hot spots were found
- [run.ps1](run.ps1): builds the probe and measures GC on/off. Single-threaded, switching the GC off does **not** help
  (slower: memory just grows), so garbage collection is not the bottleneck there.
- [sample.py](sample.py): a sampling profiler from tools already installed: relinks the probe with `/DEBUG`, takes
  60-80 non-invasive stack snapshots with `cdbX64.exe`, maps generated C names (`F88_1334`) to Eiffel features.

| Profile | Hot spot | Share |
|---|---|---|
| elements, before | `parse_end_tag` → `open_element_matches_range` → `{XP_TOKEN_SLICE}.same_range` | 43 % / 27 % / 25 % |
| DTD, after step 1 | `append_reference_in_content` → `resolved_general_entity_name`, `is_predefined_entity`; allocator 20 % | 72 % / 17 % / 17 % |
| elements, after step 2 | flat: main loop 17 %, `scan_name` 9 %, `note_position` 9 % | no single hot spot left |

## Changes
| Step | Change | Where |
|---|---|---|
| 1a | Compare an end tag with the open element **once** (was up to 3×); `close_element_range_known` reuses the result | `XP_PARSER.parse_end_tag` |
| 1b | `same_range`: one `same_characters` call (native area compare) instead of two dynamic `item` calls per character | `XP_TOKEN_SLICE` |
| 2a | `is_predefined_entity`: compare characters; the 5 manifest strings created 5 objects per entity reference | `XP_PARSER` |
| 2b | `resolved_general_entity_name`: create the alias table only when an alias is followed (was one `HASH_TABLE` per reference) | `XP_PARSER` |

## Limitations
- Between two builds of nearly the same source, non-entity inputs varied by 3-9 % (code layout); step 2 vs step 1 showed
  such a difference on non-entity inputs while the DTD input gained 28 %. All step 2 numbers are still faster than baseline.
- Single PC, one input size; the full fair-speed matrix (#275) against Expat is still to rerun with this build.

## Full acceptance run (2026-11-16) · [acceptance.ps1](acceptance.ps1)

Source: `perf/parser-allocations` working tree (steps 1+2) on top of `incremental-test` @ `08190ec`. The tested DLLs in
`build/native-eiffel` were backed up and restored (`adae03d2…`, `75f43a5b…`) because `run_benchmarks.ps1` rebuilds them.

| Check | Expected | Observed |
|---|---|---|
| Eiffel test matrix, 4 lanes ([log](logs/matrix.txt)) | 4/4 ok | ✅ 4/4 `xpact Phase 1 tests: ok` (lane "assertions-on / Finalized" passed when run alone, see problem below) |
| W3C runner, all 2,585 cases, Finalized + FinalizedAssertions ([summary](logs/w3c-summary.json)) | 0 failed, 0 errors | ✅ both builds: 2,283 passed + 302 no-crash, **0 failed, 0 errors, 0 skipped** (= 8 Nov baseline) |
| Test 2, all documents whole / byte by byte / every split vs Expat | identical to the tested DLL | ✅ byte-identical report |
| Python suite ([log](logs/python.txt)) | all pass | ✅ 257/257 |

Separate problems found on the way (not the parser), **all fixed and verified 2026-11-16** (see the end of this report):
1. **Matrix lane 4 inside a full run:** "Cannot create project directory" for target `xpact_tests_assertions` right after
   the Workbench lane of the same target (`ec.lock` left behind); the lane passes on its own
   (`run_eiffel_test_matrix.ps1 -AssertionMode On -BuildMode Finalized`). Cause suspected: a file in the target folder
   still locked (e.g. virus scanner on the fresh exe). Not fixed.
2. **`run_benchmarks.ps1` via `powershell -File`** turns `-EiffelBuild Finalized,FinalizedAssertions` into one string
   (validation error); use `-Command`. **`python` on PATH** must be a real Python (the Store alias stops the runner, #308).
3. **Python `test_libexpat_isolation` teardown** once failed to delete a temp file "in use by another process"; the test
   passes when rerun (6/6).

## Fair speed test with the DLL (2026-11-16)

`benchmarks/fair_speed/run_matrix.py` got `--jobs N` (several cells at once; inside a cell the engines still alternate).
libexpat 2.8.1 built here with [build_expat.ps1](build_expat.ps1) (official tarball, SHA-256 checked; `libexpat.dll` `1e2a61ba…`).

| Run | Cells | xpact/Expat median old → new | new vs old | Checksum mismatches |
|---|---:|---|---|---|
| Full matrix, `--jobs 8` (17 min per build instead of 1-2 h) | 200/204 | 18.91× → 17.82× | 1.04× (spread 0.55-1.95×: load noise) | 0 / 0 |
| 1 MB inputs, `--jobs 1`, idle | 60/60 | 18.27× → 17.92× | **1.01×** (DTD 1.10×) | 0 / 0 |

Lesson: `--jobs 8` is fine for correctness (checksums) and for a quick overview, but its timing noise is too large to
judge a 5-10 % change; judge changes with `--jobs 1` on an idle PC. Unmeasured in both: `elements-1MB-latin1` in 1 B and
16 B pieces (TIMEOUT 900 s, the known ISO-8859-1 slowdown #272).

## Steps 3-4: the DLL path (2026-11-16)

Profile of `fair_speed.exe` + a `-DEBUG` relink of the changed DLL (`build/native-eiffel-perf-dbg`, never the tested
folder), 1 MB elements, 4 KB pieces, callbacks on ([sample.py](sample.py) `--command`):

| Before step 3 | Share |
|---|---|
| `is_incomplete_markup_prefix` (does the piece end inside markup?) | 28.6 % inclusive |
| `makestr_with_hash` (new string objects for manifest strings) | 24.3 % inclusive |
| allocator (`eif_rt_xmalloc`, `spmalloc`, `emalloc_size`, `erembq`) | ~30 % innermost |

| Step | Change | DLL, idle, 60 cells vs baseline |
|---|---|---|
| 3 | `is_incomplete_markup_prefix`: only `<!` / `<?` can start comment / CDATA / DOCTYPE / PI, so ordinary tags skip the four `has_at` checks; literals are `once` strings (no new object per call) | 1.06× (pieces 4 KB / 64 KB 1.10×, elements 1.14×); repeated run: 1.06× again |
| 4 | Element names: `a_input.substring` already returns a new string (4 places did `make_from_string` on it again); `open_element` lets the stack keep the parser's own fresh name instead of a second copy (the event still gets its own copy) | **1.07×** (elements 1.16×, namespaces 1.08×) |

Test 2 with the step-4 DLL `6c990d29…`: TSV SHA-256 `1feb6129…`, identical to the tested DLL.
After step 3 the profile is flat (allocation spread over callbacks' C strings and name copies, `open_element` 20 %).

## Full acceptance run, steps 1-4 (2026-11-16 03:04-03:09)

| Check | Observed |
|---|---|
| Eiffel test matrix | ✅ 4/4 (`assertions-on / Finalized` again needed the separate run: [log](logs/matrix-lane4.txt)) |
| W3C runner, both builds ([summary](logs/w3c-summary-step4.json)) | ✅ 2,283 passed + 302 no-crash, 0 failed, 0 errors, 0 skipped (each build) |
| Test 2 | ✅ TSV SHA-256 `1feb6129…` = tested DLL |
| Python suite | ✅ 257/257 |

## The three script problems: fixed (2026-11-16)

| Problem | Cause (confirmed) | Fix | Verified |
|---|---|---|---|
| Matrix lane `assertions-on / Finalized` fails in a full run | right after the Workbench lane of the same target `ec` prints "Cannot create project directory", leaves `ec.lock` and **still exits 0** without generating code | `scripts/run_eiffel_test_matrix.ps1`: a compile counts only with exit 0 **and** a fresh `Makefile.SH`; otherwise wait 10 s, remove the stale lock, retry (max 2) | full matrix: lane 4 retried once, **4/4 ok, exit 0** ([log](logs/fixcheck-matrix2.txt)) |
| `run_benchmarks.ps1 -EiffelBuild Finalized,FinalizedAssertions` via `powershell -File` | `-File` passes the list as one string, `ValidateSet` rejected it | split comma-separated values, then check them | run via `-File`: both builds 2,283 + 302, 0 failed ([log](logs/fixcheck-w3c.txt)) |
| Runner stops when `python` on PATH is the Microsoft Store alias | `scripts/resolve_python.ps1` (#308) only refused the alias | it now finds a real interpreter: `XPACT_PYTHON`, non-Store `python`, `py -3`, uv-managed, per-user install | same run with the alias first on PATH: the pyexpat benchmark rows ran |
