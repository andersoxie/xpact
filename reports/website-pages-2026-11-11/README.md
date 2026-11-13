# Website pages updated with the 2026-11-11 results

| | |
|---|---|
| Branch | `docs/website-pages-2026-11-11` from `incremental-test` @ `0e82ed4` |
| Command | `python website/scripts/export-data.py`; `website\scripts\test.ps1`; browser check of the published site (headless Chromium) |

## Change
- `export-data.py`: `benchmarks.json` gets a `fairSpeed` block computed from `student/results/fair-speed-2026-11-10/results.tsv` (200 cells, median ratio 18.2, 0 checksum mismatches, 4 not compared; whole 1 MB documents per shape). Same numbers as the test's own `summary.md`. The other data files are unchanged.
- Benchmarks page: new section "Speed against native Expat 2.8.1" (from the data, not hard-coded).
- Docs, Known limitations: thread row now "Threads take turns" (#304, was "not thread-safe, crash"); ISO-8859-1 links #272 (was mass-xpact#84); new rows: speed (#275), entity depth (#293), billion-laughs time (#211).
- Home, Current status: #273 and #274 done; speed (#275) to do.

## Verification
| Check | Result |
|---|---|
| Typecheck + frontend build, backend tests | ✅ 42/42 ([log](test-website.txt)) |
| `/benchmarks`, `/docs`, `/` in Chromium | ✅ 0 console errors, 0 failed requests; new rows present |
| New section, desktop and 390 px wide | ✅ [desktop](fair-section.png), [phone](fair-mobile.png); no sideways scroll |
