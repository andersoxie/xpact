# Report: mass-xpact #60: billion-laughs documents were rejected late and as "syntax error"

> **Issue:** [CodTanium/mass-xpact#60](https://github.com/CodTanium/mass-xpact/issues/60), follow-up of [andersoxie/xpact#211](https://github.com/andersoxie/xpact/issues/211) · **Branch:** `fix/60-amplification-limit`, from `student-Mass` @ `9728bba`
> **Changed:** `src/xp_limits.e`, `src/xp_parser.e`, `src/xp_native_parser.e`
> **Status:** ✅ fixed for Expat's default settings · ✅ verified · ⚠️ known difference with very strict custom settings (#61)

## 1. In short

There were three differences from Expat:
- XPact stopped entity expansion at a fixed 8 MiB of replacement text and reported it as code 2, **"syntax error"**.
- It ignored the `XML_SetBillionLaughsAttackProtection*` settings.
- It **wrongly rejected large legitimate documents** whose entities expand past 8 MiB with a low factor.

It now applies Expat's rule, with the native settings or Expat's defaults (factor 100, threshold 8 MiB). A document is rejected when its output (document bytes + entity replacement bytes) is at least the threshold **and** more than the factor times its document bytes. The error is code 43, `XML_ERROR_AMPLIFICATION_LIMIT_BREACH`, as in Expat. A 1 GiB hard cap stays only to protect the 32-bit counter.

**Default settings** (Expat 2.8.1 compiled into the same probe; [Expat](logs/expat-default.txt), [before](logs/before-default.txt), [after](logs/after-default.txt)):

| Document | Expat | XPact before | XPact after |
|---|---|---|---|
| `laughs-3` / `-4` / `-5` (181–269 B, up to 1 MB of entity text) | accepted | accepted | ✅ accepted |
| `laughs-6` (313 B → 10 MB) | **rejected, 43** | rejected, **2 "syntax error"** | ✅ **rejected, 43** |
| `laughs-8` (401 B → 1 GB) | **rejected, 43** | rejected, **2** | ✅ **rejected, 43** |
| `big-low-factor` (1 MB document, 9 MB of entity text, factor ~10) | **accepted** | **rejected, 2** (wrong) | ✅ **accepted** |
| `under-threshold` (7 KB → 7 MB) | accepted | accepted | ✅ accepted |
| `over-threshold` (7 KB → 8.4 MB) | rejected, 43 | rejected, 2 | ✅ rejected, 43 |

All 8 match Expat now ([documents](logs/documents/), laughs documents in `reports/issue-0211/`).
`laughs-6` is rejected after ~0.84 s (Expat ~0.1 s). XPact has to expand the same 8 MiB first, and its expansion is slower.

## 2. The problem

| Field | |
|---|---|
| **Environment** | Windows 11, student PC2; EiffelStudio 25.12, `msc_vc140`, MSVC (VS 18); `student-Mass` @ `9728bba` |
| **Command** | `laughsprobe.exe [-m factor] [-t threshold] <files>` ([source](logs/tools/laughsprobe.c)): `XML_ParserCreate(NULL)`, the optional settings, one final `XML_Parse`, no handlers |
| **Cause** | ✔ Confirmed by the code. `{XP_PARSER}.note_entity_expansion` stopped at `Default_max_entity_expansion_bytes` = 8 MiB with "entity expansion limit exceeded". `{XP_NATIVE_PARSER}`'s message-to-code mapping had no entry for it, so it became `XML_ERROR_SYNTAX`. The native amplification check used a constant estimate. Expat's rule is in `accountingDiffTolerated` (`xmlparse.c`) |

## 3. The change

- [x] `XP_LIMITS`: `Default_amplification_threshold_bytes` (8 MiB) and `Default_maximum_amplification` (100.0), Expat's defaults. `Default_max_entity_expansion_bytes` is now 1 GiB, a hard cap only.
- [x] `XP_PARSER`: `amplification_threshold`, `maximum_amplification` and `set_amplification_limits` (for `XP_NATIVE_PARSER`). `is_amplification_limit_breached` uses Expat's rule, with the document bytes received so far as the direct count. External-entity parsers keep the 8 MiB check, since the native parser checks their amplification.
- [x] `XP_NATIVE_PARSER`: before each parse, it passes the values set with `XML_SetBillionLaughsAttackProtection*`, or Expat's defaults (`native_maximum_amplification`, `native_amplification_threshold`). "entity expansion limit exceeded" maps to `Xml_error_amplification_limit_breach` (43).

## 4. Verification

| Check | Result |
|---|---|
| ✅ Both tiers build | `System Recompiled.`, smoke `ok` |
| ✅ 8 documents with default settings | all match Expat (verdict and code) |
| ✅ DLL tests, 4,308 cases | 4,308 / 4,308 on both tiers; `results.tsv` byte-identical to `student-Mass` ([production](logs/dlltests-production-summary.txt), [assertions](logs/dlltests-assertions-summary.txt)) |
| ✅ No-handler check, 3,061 W3C files, whole and 7-byte pieces | 0 differences |
| ✅ W3C trace | 9 / 9 files byte-identical, both tiers ([production](logs/w3c-trace-sha256-production.txt), [assertions](logs/w3c-trace-sha256-assertions.txt)) |
| ✅ Test 2 (2,585 cases) | TSVs byte-identical, both tiers |
| ✅ Expat 2.8.1 `runtests`, incl. `test_billion_laughs_attack_protection_api` and `test_amplification_isolated_external_parser` | `Checks: 399, Failed: 38` on both tiers, the same 38 names ([production](logs/expat-runtests-production.txt), [assertions](logs/expat-runtests-assertions.txt)) |

## 5. Known difference (follow-up #61)

With **very strict custom settings** (`-m 2 -t 1000`), 6 of 8 documents match Expat. XPact rejects `laughs-3` and `big-low-factor`, which Expat accepts ([Expat](logs/expat-custom.txt), [after](logs/after-custom.txt)). Before this change XPact ignored the custom settings and matched only 3 of 8.

The cause is how bytes are counted. XPact adds the whole replacement text of each reference when it expands it. Expat counts token by token, as it processes them. So with a factor of 2 XPact reaches the limit earlier. This doesn't matter with Expat's default settings.

## 6. How to revert

Revert the commit; the fixed 8 MiB cap and code 2 return.
