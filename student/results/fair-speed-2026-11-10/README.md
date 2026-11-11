# Fair speed test: xpact vs native Expat 2.8.1 (2026-11-10)

Issue: [andersoxie#275](https://github.com/andersoxie/xpact/issues/275) · Result tables: [summary.md](summary.md) · Raw data: [results.tsv](results.tsv), [matrix.log](matrix.log)

## ✅ Result in short

| | |
|---|---|
| Same work? | ✅ **0 checksum mismatches** in 102 cells with callbacks on (element names, attributes, text) |
| Whole document, callbacks on | xpact **9–20× slower** than Expat (attributes 9–10×, text 12–20×, DTD 17–19×, namespaces 18–20×) |
| Whole document, callbacks off | xpact **2.3–16× slower** (attributes 2.3–2.6×, elements 4.9–5.8×, namespaces 14–16×) |
| 1-byte pieces | xpact **21–43× slower** |
| Median ratio, all 200 cells | **18.2×** (best 2.25×, worst 36,032×) |
| ISO-8859-1 in pieces | 🔴 **quadratic** ([#272](https://github.com/andersoxie/xpact/issues/272)): 157× at 64 KB, 2,338× at 4 KB, 36,032× at 256 B; 16 B and 1 B **timed out** (> 900 s); Expat 35 ms |
| UTF-16 | same as UTF-8 (no extra cost) |
| Assertions DLL vs production | **9–22× slower** (subset: elements and text, 1 MB) |

Absolute example: `elements-10MB` whole, callbacks on: xpact 1,492 ms, Expat 89 ms per parse.

## Environment

- Revision: `658a8eb` (andersoxie `incremental-test`); parser source unchanged since `45d2f53`.
- Machine: PC2, AMD Ryzen 7 5800H, 16 GB, Windows 11 Home 10.0.26200; PC kept idle during the run.
- Builds (SHA-256, first 16 hex digits):
  - `xpact.dll` (finalized, production, assertions off) `38323ba0c32f2305`
  - `xpact_assertions.dll` (assertions on) `28b97d9d2ab419e5`
  - `libexpat.dll` 2.8.1 Release (`reports\issue-0121\expat-build.cmd`) `74c3c976823bf386`
  - `fair_speed.exe` (`cl /O2`) `10b651cd674026e6`

## Method

- One harness, [`benchmarks/fair_speed/fair_speed.c`](../../../benchmarks/fair_speed/fair_speed.c), loads either DLL with `LoadLibrary` and calls the same `expat.h` functions. Timed: parser create + every `XML_Parse` + free (file read not timed).
- Checksum: FNV over start/end element names, attributes and text, hashed byte by byte so the text split doesn't matter.
- Inputs: [`gen_inputs.py`](../../../benchmarks/fair_speed/gen_inputs.py), deterministic: 5 shapes × 10 KB / 1 MB / 10 MB (10,000,000 bytes, under xpact's 10 MiB limit), UTF-8; `elements-1MB` also in UTF-16 and ISO-8859-1.
- Matrix: × pieces whole / 64 KB / 4 KB / 256 / 16 / 1 byte × callbacks off/on; namespaces processing on for the namespaces shape. 17 files × 6 × 2 = 204 cells per engine.
- Runner: [`run_matrix.py`](../../../benchmarks/fair_speed/run_matrix.py): warm-up + calibration to ~0.25 s per run, then 5 rounds alternating engine order (AB/BA), one process per run, median reported; a parse over 20 s is measured once; 900 s timeout.

## Reproduce

```
python -I benchmarks/fair_speed/gen_inputs.py build/speed/inputs
cl /O2 /Fe:build/speed/fair_speed.exe benchmarks/fair_speed/fair_speed.c
python -I benchmarks/fair_speed/run_matrix.py build/speed/fair_speed.exe build/speed/inputs build/speed/results.tsv --xpact <xpact.dll> --expat <libexpat.dll> --assertions <xpact_assertions.dll>
python -I benchmarks/fair_speed/summarize.py build/speed/results.tsv student/results/fair-speed-2026-11-10/summary.md
```

## Limitations

- [ ] One machine, one run of the matrix (5 rounds per cell); the 4 latin1 timeouts are not measured and 4 cells over 20 s are single measurements.
- [ ] Only start/end element and character data callbacks; other handlers (comments, PIs, DTD declarations) not timed.
- [ ] Generated inputs, not real-world documents (the catalog runs cover those).
- [ ] Error inputs not timed; Expat's own build options (e.g. `XML_DTD`, `XML_GE`) are the defaults of its CMake Release build.

> **2026-11-11:** after #273 (exception guards) and #274 (call lock) the DLL was checked again with this harness: no cost on whole documents, about 2–4 % on 1-byte pieces ([check](../../../reports/issue-0276-check/README.md)).
