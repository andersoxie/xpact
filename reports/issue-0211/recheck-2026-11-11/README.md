# #211 recheck on `incremental-test` (2026-11-11)

| | |
|---|---|
| Code | andersoxie/xpact `incremental-test` @ `0785dbf` |
| DLL | fresh build 2026-11-11, `scripts/build_native_eiffel.ps1` both tiers (EiffelStudio 25.12, `msc_vc140`); smoke test ok |
| `xpact.dll` SHA-256 | `02B7F95B803196B9…` (same in `build/native-eiffel`, `website/backend/native`, `website/dist/native`) |
| Worker | `website/dist/Xpact.Worker.exe` from `publish.ps1`, production build, whole document, one `XML_Parse` |
| Reference | CPython 3.15.0 `pyexpat` |
| Assertions build | not measured |

## 1. The #211 documents (`laughs.py`, [results.json](results.json))

`python -I reports\issue-0211\laughs.py website\dist\Xpact.Worker.exe website\dist\native\xpact.dll reports\issue-0211\recheck-2026-11-11`

| Levels | Expands to | XPact 2026-11-02 | XPact 2026-11-08 | **XPact now** | Expat |
|---|---|---|---|---|---|
| 3-5 | 10 KB - 1 MB | accepted | accepted | accepted (139-340 ms) | accepted |
| 6 | 10 MB | "syntax error", ~7 s | amplification, 1.44 s | **amplification limit breached, 1.54 s** | amplification, 98 ms |
| 8 | 1 GB | "syntax error", ~7 s | amplification, 1.47 s | **amplification limit breached, 1.54 s** | amplification, 98 ms |

XPact times include ~0.1-0.2 s worker start (3 levels: 232 ms, 4 levels: 139 ms).

## 2. libxml2 `test/recurse/lol_*` ([lol.py](lol.py), [lol-results.json](lol-results.json))

Files from `gitlab.gnome.org/GNOME/libxml2` `master`, `test/recurse/`.

| File | XPact | ms | Expat | ms |
|---|---|---:|---|---:|
| `lol_classic.xml` (48 levels) | 🔴 **rejected, code 2 "syntax error"** at `&ha48;` (51:6) | 138 | amplification limit | 97 |
| `lol_ig_attr.xml` | ✅ amplification limit breached | 1,718 | amplification limit | 96 |
| `lol_ig_content.xml` | ✅ amplification limit breached | 2,142 | amplification limit | 83 |
| `lol_eg.xml`, `lol_ep.xml` | accepted (worker loads no external entities) | 114 | accepted | 0 |

`lol_eg`/`lol_ep` timed out on 2026-11-08 in the corpus runner, which loads external entities. This recheck does **not** reproduce that setup, so those two are not rechecked.

## 3. Why `lol_classic` says "syntax error" ([deep.py](deep.py), [deep-results.json](deep-results.json))

Tiny documents with N nested entities, each adding 1 byte (so no amplification at all):

| Levels | XPact | Expat |
|---:|---|---|
| 31, 32 | accepted | accepted |
| 33, 40, 48 | 🔴 rejected, code 2 "syntax error" | accepted |

**Cause (confirmed by this test and the source):** `Default_max_entity_depth = 32` (`src/xp_limits.e:24`). Deeper nesting sets "entity expansion depth exceeded" (`src/xp_parser.e:3471`), which has no entry in the error-code map in `src/xp_native_parser.e` (~3038), so it is reported as code 2. Expat has no such depth limit. This is a **separate problem** from #211 and is filed as #293.

## Result

- ✅ The error is right: Expat's amplification error (code 43) for the #211 documents and the libxml2 `lol_ig_*` files.
- 🟡 Still ~15x slower than Expat (~1.5 s vs ~0.1 s); #211's expected result was "well under a second".
- 🔴 New: well-formed documents nested more than 32 entity levels deep are rejected as "syntax error".
