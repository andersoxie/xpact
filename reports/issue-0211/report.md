# Report: issue #211: nested entity expansion ("billion laughs") is rejected late, with a general error code

Issue: [#211](https://github.com/andersoxie/xpact/issues/211) · Date: 2026-11-02 · Found by: the website's security tests ([#210](https://github.com/andersoxie/xpact/issues/210)) · Status: ⬜ open, parser not changed

| # | Field | Record |
|---|---|---|
| 1 | **Problem** | A document whose nested entities expand to 10 MB or more is rejected only after about 7 s, and with code 2 "syntax error". Expat rejects the same document in about 0.1 s with its amplification-limit error. |
| 2 | **Environment** | Student PC 2, Windows 11, `student-Mass` @ `22876e9`. `xpact.dll` production build (SHA-256 `35460E77DDC74083…`), built 2026-11-02 with `scripts/build_native_eiffel.ps1 -BuildTier Production` (EiffelStudio 25.12, `msc_vc140`). Expat reference: CPython 3.15.0 `pyexpat`, `expat_2.8.5`. |
| 3 | **Command** | `python -I laughs.py website\dist\Xpact.Worker.exe website\dist\native\xpact.dll <out>` ([laughs.py](laughs.py)). Each document goes through the website worker: one `XML_ParserCreate(NULL)`, one final `XML_Parse`. |
| 4 | **Expected** | Like Expat: reject quickly (well under a second) once the expansion is far larger than the input, with an error that names the cause. |
| 5 | **Actual** | See the table below and [results.json](results.json). |
| 6 | **Error output** | XPact: `{"verdict":"rejected","error":{"message":"syntax error"}}`. Expat: `limit on input amplification factor (from DTD and entities) breached`. |
| 7 | **Investigation** | Five documents, 3 to 8 levels of 10 references each ([laughs-3.xml](laughs-3.xml) … [laughs-8.xml](laughs-8.xml)). The time grows with the expansion up to 10 MB, then stays at about 7 s, so XPact seems to have a limit that is reached late. The parser source was **not** read for this finding. |
| 8 | **Cause** | ❓ **Unknown / suspected:** an expansion limit exists in `XP_PARSER` (`Default_max_entity_expansion_bytes`), but it is reached later than Expat's amplification check and is reported as a syntax error. Not confirmed. |
| 9 | **Fix** | None in the parser. The website is protected anyway: 10 s time limit, 512 MB memory cap per worker, 1 MB input limit. |
| 10 | **Verification** | Website test `Slow_documents_are_stopped_by_the_timeout` passes: the request ends in under 8 s. The parser behaviour itself is unchanged. |

## Results

| Levels | Input | Expands to | XPact | XPact time | Expat 2.8.5 | Expat time |
|---:|---:|---:|---|---:|---|---:|
| 3 | 181 B | 10 KB | accepted | 125 ms | accepted | 0 ms |
| 4 | 225 B | 100 KB | accepted | 209 ms | accepted | 2 ms |
| 5 | 269 B | 1 MB | accepted | 1,257 ms | accepted | 15 ms |
| 6 | 313 B | 10 MB | **rejected, "syntax error"** | **6,990 ms** | rejected, amplification limit | 106 ms |
| 8 | 401 B | 1 GB | **rejected, "syntax error"** | **7,302 ms** | rejected, amplification limit | 100 ms |

XPact times include starting the worker process (about 100 ms); Expat times are in-process.

## Limitations
- [ ] One machine, one run per document; no repetition.
- [ ] Expat 2.8.5 (pyexpat), not the 2.8.1 used in the other comparisons.
- [ ] The assertions build was not measured.
- [ ] The cause is not investigated in the parser source.

## Next steps
- [x] GitHub issue opened: [#211](https://github.com/andersoxie/xpact/issues/211)
- [ ] Read where `XP_PARSER` checks `Default_max_entity_expansion_bytes` and why the error is "syntax error"
- [ ] Measure the assertions build
- [ ] Decide with the supervisor whether XPact should copy Expat's amplification check (ratio of expanded to input bytes)
