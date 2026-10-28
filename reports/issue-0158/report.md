# Report: issue #158: keep a second byte order mark after UTF-16 decoding

> **Issue:** [#158](https://github.com/andersoxie/xpact/issues/158) F01-5 · found by the W3C output test ([#154 report](../issue-0154/report.md))
> **Branch:** `fix/158-keep-second-byte-order-mark`, from `student-Mass` @ `d0a4e21`, rebased on `133ae01` (#157) · **Changed:** `src/xp_parser.e`, `src/xp_native_parser.e` (+28 / −2)
> **Status:** ✅ fixed · ✅ verified locally, both builds · 🟡 waiting for a Jenkins run before the issue is closed

## 1. In short

| | Before (`d0a4e21`) | After (on `d0a4e21`) | After, rebased with #157 |
|---|---:|---:|---:|
| ✅ W3C output exactly right | 394 / 432 | **397 / 432** | **398 / 432** |
| ❌ cases that got **worse** | | **0** | **0** |

Fixed: `valid-ext-sa-014`, `invalid-bo-4`, `invalid-bo-5` (all UTF-16). The UTF-8 version, `invalid-bo-6`, already passed.

**It was also a wrong verdict**, not only wrong content. The [probe](bom_probe.py) found it: a UTF-16 document that starts with **two** BOMs was **accepted**; the second U+FEFF is a character before the root element, so Expat rejects it.

| Probe case (whole, and split at 1, 2, 3 bytes) | Expat | xpact before | xpact after |
|---|---|---|---|
| UTF-8, no BOM / BOM / BOM + U+FEFF in text | ACCEPT, `x` / `x` / `﻿x` | ✅ same | ✅ same |
| UTF-8, two BOMs | REJECT | ✅ REJECT | ✅ REJECT |
| UTF-16 LE / BE, one BOM | ACCEPT, `x` | ✅ same | ✅ same |
| **UTF-16 LE / BE, two BOMs** | **REJECT** | ❌ **ACCEPT** | ✅ REJECT |
| UTF-16 LE, BOM + U+FEFF in text | ACCEPT, `﻿x` | ✅ same | ✅ same |
| UTF-16 BE, BOM + `encoding="UTF-16"` | ACCEPT, `x` | ✅ same | ✅ same |
| **Total like Expat** | | **8 / 10** | **10 / 10** |

([before](logs/checks/bom-probe-before.txt), [after](logs/checks/bom-probe-after-assertions.txt))

## 2. Problem report (CLAUDE.md format)

| Field | |
|---|---|
| **1. Problem** | In UTF-16 input, a U+FEFF right after the byte order mark is dropped |
| **2. Environment** | Windows 11 (student PC); EiffelStudio 25.12, MSVC (`msc_vc140`); Python 3.14; Expat control `pyexpat` 2.7.3; both DLL builds |
| **3. Command** | `python -I reports\issue-0154\tools\run.py --dll build\native-eiffel-assertions\xpact_assertions.dll --out <folder>`; `python -I reports\issue-0158\bom_probe.py <dll>` |
| **4. Expected** | `valid-ext-sa-014` (external entity `FF FE FF FE d a t a`, UTF-16 LE): `<doc>` + U+FEFF + `data</doc>` |
| **5. Actual (before)** | `<doc>data</doc>`; and two-BOM UTF-16 documents accepted (probe) |
| **6. Error output** | none ([diff](../issue-0154/logs/after-normal/diffs/valid-ext-sa-014.xpact.txt)) |
| **7. Investigation** | Only the UTF-16 variants failed, the UTF-8 one passed. `decoded_utf16_input` (`src/xp_native_parser.e`) skips the first unit when it is U+FEFF, the BOM, correctly. The second U+FEFF becomes the UTF-8 bytes `EF BB BF` at the start of the decoded text. `normalized_input` (`src/xp_parser.e`) then removed a leading UTF-8 BOM from that already decoded text. The parser's own UTF-16 path (`utf_16_as_utf_8`) also skips the first BOM and fed `normalized_input` the same way |
| **8. Cause** | ✅ **confirmed**: the BOM was removed twice; telling `normalized_input` that the mark is already gone fixes the 3 cases and the probe, and changes nothing else (section 4) |
| **9. Fix** | `XP_NATIVE_PARSER`: `last_input_byte_order_mark_removed`, set by `decoded_utf16_input` when it skips the BOM, reset by `decoded_input`, passed on with the new `XP_PARSER.set_input_byte_order_mark_removed` before each parse. `XP_PARSER.normalized_input`: strips a leading `EF BB BF` only if no mark was removed and the text was not converted by its own decoder (`l_source = a_input`) |
| **10. Verification** | ✅ section 4 |

## 3. The change

| File | Change |
|---|---|
| `src/xp_native_parser.e` | new `last_input_byte_order_mark_removed`; reset in `decoded_input`; set in `decoded_utf16_input` when the BOM is skipped; `parser.set_input_byte_order_mark_removed (…)` right after `decoded_input` |
| `src/xp_parser.e` | new `set_input_byte_order_mark_removed` / `input_byte_order_mark_removed` (next to `set_input_is_utf8`; clears the cached doctype when it changes); both BOM checks in `normalized_input` honour it, and the copy path also requires unconverted input |

## 4. Verification

Assertions build first, then the normal build. Full set on `d0a4e21` + #158; after the rebase on `133ae01` (#157) the assertions build, test 1 and both probes were run again.

| Check | Before | After the fix | Log |
|---|---|---|---|
| ✅ DLL build + smoke test | ok ×2 | ok ×2 (+ ok after the rebase) | [assertions](logs/checks/build-assertions.txt), [normal](logs/checks/build-normal.txt), [rebased](logs/checks/build-assertions-rebased.txt) |
| ✅ **W3C output test** | 394 / 432 | **397 / 432**; only the 3 BOM cases changed; normal = assertions · **398** rebased with #157 | [assertions](logs/after-assertions/results.tsv), [normal](logs/after-normal/results.tsv), [rebased](logs/after-rebased/results.tsv) |
| ✅ BOM probe, 10 cases × 4 splits | 8 / 10 | **10 / 10** | [before](logs/checks/bom-probe-before.txt), [after](logs/checks/bom-probe-after-assertions.txt) |
| ✅ W3C verdicts through the DLL, all 2,585 | baseline | **identical** per case, both builds | [summaries](logs/checks/verdicts/) |
| ✅ Jenkins Benchmarks stage, run locally (`-SkipWslC`) | 2,283 + 302, 0 failed | **2,283 + 302, 0 failed, 0 errors, 0 skipped**, both builds | [summary](logs/checks/jenkins-w3c/summary.md), [console](logs/checks/jenkins-benchmarks-stage.txt) |
| ✅ External entities through the DLL | 247 / 247 | **247 / 247**, both builds | [summary](logs/checks/dll-entity-lane/summary.json) |
| ✅ Python suite | 206 OK | **206 OK** | [log](logs/checks/python.txt) |
| ✅ C# DLL tests vs Expat 2.8.1 (4,308 inputs) | recorded table | difference table **identical**, both builds | [off](logs/checks/csharp/xpact/), [on](logs/checks/csharp/xpact_assertions/) |
| ✅ Dual regression lane (xpact, built from the changed source) | 910 / 910 | **910 / 910**, both builds | [summary](logs/checks/dual-regression/summary.md) |
| ✅ Eiffel test matrix | 4 / 4 | **4 / 4** | [log](logs/checks/eiffel-matrix.txt) |
| 🟡 Jenkins | | not run yet | |

## 5. Problems met (kept separate)

| Problem | Cause | What was done |
|---|---|---|
| Two-BOM UTF-16 documents accepted | ✅ same cause as #158 | fixed by the same change; recorded here, not filed separately |
| Dual lane: `xpact-core` not built | ✅ environment, as #154 P1 | xpact lane only |

## 6. Limitations

- The full set ran on `d0a4e21` + #158; after the rebase only the build, test 1 and the probes were repeated (the #157 change is in another routine).
- Other converting decoders (Latin-1, unknown encodings) do not set the flag; they cannot produce a leading `EF BB BF` from a BOM, and `l_source = a_input` covers the parser's own path.

## 7. Revert

After the squash merge: `.\student\tools\fix.ps1 revert -Issue 158 -Commit <merged sha>`.
