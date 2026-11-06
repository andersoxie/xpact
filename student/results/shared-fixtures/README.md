# Shared fixtures and comparison output (week 8)

> **Issue:** [CodTanium/mass-xpact#81](https://github.com/CodTanium/mass-xpact/issues/81) · **Date:** 2026-11-06
> **xpact:** final `student-Mass` (parser `45d2f53`), `xpact.dll` and `xpact_assertions.dll` · **Expat:** 2.8.1 `libexpat.dll` built here (MSVC Release, `char`, DTD/GE/NS on, SHA-256 `74c3c976…`)
> **Status:** ✅ done · 1 new finding ([#82](https://github.com/CodTanium/mass-xpact/issues/82))

## 🚦 In short

| | Result |
|---|---|
| ✅ One manifest of every shared fixture set | **247 fixtures in 9 sets**, each with source, path, SHA-256 and the finding it belongs to ([`manifest.tsv`](manifest.tsv), made by [`make_manifest.py`](make_manifest.py)) |
| ✅ The same verdict as Expat | **245 / 247**; the 2 others are [#82](https://github.com/CodTanium/mass-xpact/issues/82) (pre-existing) |
| ✅ No crash, no timeout, no missing result | 6,916 parses per build |
| ✅ Both xpact builds | assertions = production on every row |
| ✅ Against the expected verdict | 89 pass; the 2 misses are the known 5th-edition G01 cases |
| ✅ Week 7 reruns on the fixed code | [G03](../G03-comparison/README.md): **62 / 93 identical** to Expat (was 59); [C# DLL tests](dlltests-vs-expat/xpact/summary.md): **3,511 / 4,308 identical** (was 1,079) |

## 📊 Per set (production; `xpact_assertions.dll` identical)

Each fixture is parsed 14 ways per engine (`XML_Parse` and `XML_ParseBuffer` × whole, 1, 2, 3, 7, 64, 1,024 bytes), with all handlers set and external entities loaded only from the fixture's own folder ([G03 harness](../../../reports/issue-0154/tools/harness/engines.py)).

| Set | Fixtures | Identical to Expat | Same verdict | xpact the same in all 14 ways | Differences | Finding |
|---|---:|---:|---:|---:|---|---|
| `G01-w3c` | 93 | 62 | 93 | 92 | error code 14, position 16, events 1 | andersoxie#170, #171, #176 |
| `C03-chunks` | 6 | **6** | 6 | 6 | | |
| `C10-utf8` | 42 | 36 | 42 | 42 | events 6 (all CDATA) | andersoxie#123 |
| `ext-entities-64` | 20 | 18 | 18 | 20 | **verdict 2**: `ibm68i03/04`, code 21 | [#82](https://github.com/CodTanium/mass-xpact/issues/82) (new, pre-existing) |
| `positions-68` | 1 | **1** | 1 | 1 | | |
| `billion-laughs-60` | 8 | 6 | 8 | 8 | events before the code-43 error, 2 | |
| `skipped-entity-69` | 3 | **3** | 3 | 3 | | |
| `fuzz-crash-72` | 11 | 3 | 11 | 11 | error code 3, position 5 | andersoxie#170, #171 |
| `fuzz-piece-dependent-74` | 63 | 0 | 63 | **0** | error code 63 (depends on the pieces) | [#74](https://github.com/CodTanium/mass-xpact/issues/74) |
| **Total** | **247** | **135** | **245** | 183 | | |

Per row: [`runs/final-normal/results.tsv`](runs/final-normal/results.tsv); every difference with the first differing event: [`runs/final-normal/differences/`](runs/final-normal/differences/).

## 🔁 Week 7 reruns on the fixed code

| Comparison | 2026-10-26 / 10-31 | 2026-11-06 (final) |
|---|---|---|
| [G03](../G03-comparison/README.md): 93 cases × 14 ways ([run](../G03-comparison/runs/final-normal/summary.json)) | 59 identical; 1,042 / 1,302 pairs; xpact the same in all ways 90 | **62** identical; **1,100** pairs; **92** |
| C# DLL tests vs Expat, 4,308 cases ([old](../expat-2.8.1/summary.md), [new](dlltests-vs-expat/xpact/summary.md)) | 1,079 identical; error code 72; position 3,153; events 657 | **3,511** identical; error code **0**; position **0**; events **171** (#123: 133, #126: 38) |
| Depends on the chunking (C03 pairs) | 6 of 318 | **0** |

The G03 changes are exactly the 5 cases the fixes #172–#175 targeted; none got worse.

## 🛠️ How to repeat

```bash
python -I student/results/shared-fixtures/make_manifest.py
python -I student/results/shared-fixtures/compare.py --tag final-normal \
    --xpact-dll build/fix72/native-eiffel/xpact.dll --expat-dll build/libexpat-R_2_8_1/Release/libexpat.dll
# any other manifest in the same format, e.g. a new test source:
python -I student/results/shared-fixtures/manifest_from_folder.py <folder> <set> "<source>" --out <results folder>/manifest.tsv
python -I student/results/shared-fixtures/compare.py --manifest <results folder>/manifest.tsv --tag final-normal [--modes whole,64,1024] ...
```

`dlltests-vs-expat/compare.py` is a copy of [`expat-2.8.1/compare.py`](../expat-2.8.1/compare.py) that writes next to itself, so the 2026-10-26 evidence stays as it was.
