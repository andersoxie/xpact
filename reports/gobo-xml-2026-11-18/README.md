# 🆚 xpact vs Gobo XML (2026-11-18)

[← reports](../README.md) · issue [#442](https://github.com/andersoxie/xpact/issues/442) · related: [Gobo compiler for xpact](../gobo-2026-11-16/README.md) · [Gobo DLL](../gobo-dll/README.md) · [AlotOfTests 2026-11-08](../../student/results/AlotOfTests-2026-11-08/README.md) · page version: [report.html](report.html)

> **What:** xpact against Gobo's own pure-Eiffel XML parser (`XM_EIFFEL_PARSER`), on every test suite we have. Expat 2.8.5 is the reference where the XML spec gives no answer.
>
> `incremental-test @ dd75cb8` · `xpact.dll 6E74C312…` · `gx_engine 8FEDBE32…` · `Gobo 26.11.14` · `assertions off`

---

## 📌 In short

| 🟢 xpact, W3C core | 🟠 Gobo, W3C core | 🟢 xpact, fuzzing 10 min | 🟠 Gobo, fuzzing 10 min | 🟢 xpact speed |
|:---:|:---:|:---:|:---:|:---:|
| **1,974 / 1,974** | **1,910 / 1,974** | **870,295** inputs | **79,717** inputs | **3.4–34× faster** |
| every case right | 64 wrong (32 bad docs accepted) | 0 crashes | 0 crashes | than Gobo XML |

xpact is better on correctness, attack resistance, streaming and speed. Gobo is better on one thing: it has no size limits, so it accepts very large or very deep documents that xpact deliberately rejects (⏸️ [paused by the student](#️-paused-by-the-student)).

| # | Test | 🟢 xpact | 🟠 Gobo XML | Better |
|---|---|---:|---:|:---:|
| 1 | Project W3C runner, core (1,974) | ✅ 1,974 | ❌ 1,910 · 64 wrong | 🟢 xpact |
| 1b | W3C legacy names, editions 1–4 (309) | ✅ 309 | ❌ 9 · 300 wrong | 🟢 xpact |
| 2 | W3C canonical output (432) | 375 exact | 319 exact | 🟢 xpact |
| 3 | Fuzzing, 10 min | 99.996 % = Expat | 97.6 % = Expat | 🟢 xpact |
| 4 | Differential vs Expat, 10 min | 99.995 % = Expat | ⏳ running | ⏳ |
| 5 | Encodings (146) | 3 cases differ | ❌ UTF-16 + declaration | 🟢 xpact |
| 6 | libxml2 corpus (1,417 files) | 1,412 = Expat | 1,398 = Expat | 🟢 xpact |
| 7 | Security attacks | ✅ all rejected fast | ❌ 2 hang, 1 exception | 🟢 xpact |
| 8 | Huge / deep documents | ⏸️ rejected (limits) | ✅ accepted | 🟠 Gobo |
| 9 | Large files 1–9 MB | 2–8× faster | slower | 🟢 xpact |
| 10 | Streaming (document in pieces) | ✅ supported | ❌ not supported | 🟢 xpact |
| 11 | Speed, Eiffel vs Eiffel (17 files) | ✅ 3.4–34× faster | slower | 🟢 xpact |

---

## ⚖️ Where each one is better

<table><tr><td valign="top" width="50%">

### 🟢 xpact does better
- ✅ Every W3C core case right; Gobo gets 64 wrong
- ✅ Rejects the 32 malformed W3C documents Gobo accepts: namespace rules, char-ref overflow, entity rules
- ✅ Reads UTF-16 documents that have an encoding declaration (Gobo: "unsupported character encoding")
- ✅ Billion laughs rejected in 3 s; Gobo runs into the 60 s timeout
- ✅ Quadratic blowup rejected in 0.17 s; Gobo runs into the timeout
- ✅ Streaming: a document can be fed in pieces (Expat API); Gobo's Eiffel parser needs the whole document
- ✅ Both XML 1.0 name tables (5th edition and editions 1–4); Gobo has only the 5th
- ✅ Caller can set the encoding (`XML_ParserCreate(encoding)`); Gobo can't
- ✅ 3.4–8.6× faster than Gobo XML, 25–34× on DTD-heavy documents; 11× more fuzz inputs in the same 10 minutes

</td><td valign="top" width="50%">

### 🟠 Gobo does better
- ✅ No 10 MB input limit: 20 MB files accepted, xpact rejects them ⏸️
- ✅ 100k-deep nesting, 10–100 MB names, text and comments accepted; xpact rejects (hard limits) ⏸️
- ✅ 50k namespaces and 100k attributes accepted; xpact rejects ⏸️
- ⚠️ Lower memory in the harness, but xpact's figure includes the Python process, so this isn't a clean comparison

> xpact's limits are known and deliberate; they are why the attack cases pass. Work on them is ⏸️ **paused by the student** (see below).

</td></tr></table>

### ⏸️ Paused by the student

| Item | Where | Status |
|---|---|---|
| Entities nested more than 32 levels deep are rejected | [#293](https://github.com/andersoxie/xpact/issues/293) | ⏸️ **paused (by student)** |
| 10 MB input limit (20 MB files, 10–100 MB tokens, 100k-deep nesting, 100k attributes rejected) | [decision log, open decisions](../../docs/decision-log.md) | ⏸️ **paused (by student)** |

---

## 🔬 Each test in detail

<details>
<summary><b>1 · Project W3C runner (all 2,585 cases)</b> · 🟢 xpact</summary>

The project's own runner, `scripts/run_w3c_conformance.py --all-cases`, XML 1.0 5th-edition profile. Each case is a fresh process. Raw files: [w3c/](w3c/), [w3c-nouf/](w3c-nouf/).

| Engine | core | legacy-names | optional-error | xml-1.1 |
|---|---:|---:|---:|---:|
| 🟢 xpact | ✅ 1,974 / 0 | ✅ 309 / 0 | 28 / 0 | 274 / 0 |
| 🟠 Gobo (strict) | 1,910 / ❌ 64 | 9 / ❌ 300 | 28 / 0 | 274 / 0 |
| 🟠 Gobo, no Unicode filter | 1,863 / ❌ 111 | 7 / ❌ 302 | 28 / 0 | 274 / 0 |

pass / fail. "Strict" uses Gobo's namespace resolver, Unicode validation filter, end-tag checker and stop-on-error filter. It's Gobo's best setup: without the Unicode filter it gets worse.

**Gobo's 64 core failures**

| Group | Cases | Examples |
|---|---:|---|
| Namespace rules not checked (accepts bad docs) | 17 | `rmt-ns10-009…012, 029…033, 036, 042…044, rmt-ns-e1.0-13a/b` |
| Valid docs rejected because of the 5th-edition name/char tables | 17 | `x-ibm-1-0.5-*, x-rmt5-014/016/019, ibm89n06…12, invalid-sa-140/141` |
| Entity and DTD rules not checked (accepts bad docs) | 11 | `not-wf-sa-074/104, not-wf-sa03, ibm32n09, ibm68n06, ibm77n01, ibm85n01/02, ibm89n01/02, hst-lhs-007` |
| UTF-16 documents rejected | 7 | `valid-sa-049/050/051, pr-xml-little, pr-xml-utf-16, weekly-little, weekly-utf-16` |
| Errata / external DTD documents rejected | 7 | `rmt-e2e-18/38/60, rmt-e3e-13, x-rmt-008b, ibm49i01, ibm51i01` |
| Char-ref overflow accepted | 4 | `hst-bh-001…004` |
| Other | 1 | `ht-ns10-047, not-wf-sa-175` |

Example, `eduni/misc/001.xml`: the character number below does not fit in 32 bits, so the document must be rejected. Gobo accepts it; xpact rejects it.

```xml
<p>Fa&#xFF000000F6;il</p>   <!-- 32 bit integer overflow -->
```
</details>

<details>
<summary><b>2 · W3C canonical output (432 cases)</b> · 🟢 xpact</summary>

The events of each engine are written as James Clark canonical XML and compared with the suite's expected OUTPUT files. Events are compared on start, end, text, PI and comment, the kinds all three engines report.

| Engine | Exact | Only this engine wrong | Wrong in both (Expat too) |
|---|---:|---:|---:|
| 🟢 xpact | ✅ 375 | 4 | 53 |
| 🟠 Gobo | 319 | ❌ 60 | 53 |
</details>

<details>
<summary><b>3 · Fuzzing and 4 · differential vs Expat</b> · 🟢 xpact</summary>

Fuzzing mutates W3C documents (bit flips, inserted tokens, splices). The differential test generates new documents. Both are 10 minutes with seed 1 and compare each verdict with Expat.

| Test | Engine | Inputs | Same verdict as Expat | Accepts what Expat rejects | Crashes / hangs |
|---|---|---:|---:|---:|---:|
| Fuzzing | 🟢 xpact | 870,295 | ✅ 99.996 % | 9 | ✅ 0 |
| Fuzzing | 🟠 Gobo | 79,717 | 97.6 % | ❌ 1,692 | ✅ 0 |
| Differential | 🟢 xpact | 1,039,865 | ✅ 99.995 % | 3 | ✅ 0 |
| Differential | 🟠 Gobo | ⏳ running | | | |

> "Accept" is the final verdict: the parser read the whole document and reported it as well-formed. Gobo's parser takes the whole document in one call, so nothing later can change it.
</details>

<details>
<summary><b>5 · Encodings (146 cases)</b> · 🟢 xpact</summary>

UTF-8 sequences in every position, UTF-16 with and without BOM and declaration, Latin-1, and character references.

| Case | Expected | 🟢 xpact | 🟠 Gobo |
|---|---|---|---|
| `utf16le-decl-utf16le` | ACCEPT | ✅ ACCEPT | ❌ REJECT: unsupported character encoding |
| `bom-utf8-decl-utf16` | REJECT | ❌ ACCEPT | ✅ REJECT |
| `create-*` (4 cases) | caller sets encoding | ✅ supported | ❌ no such API |

Every other case gets the same verdict from both engines. `bom-utf8-decl-utf16` is a small xpact difference from Expat (already known).
</details>

<details>
<summary><b>6 · libxml2 test corpus (1,417 files)</b> · 🟢 xpact</summary>

libxml2's own test files (git `21c8223`, 11 Nov 2026, downloaded, not committed). There are no expected verdicts, so Expat is the reference.

| Engine | Same verdict | Same verdict + events | Timeouts | Exceptions |
|---|---:|---:|---:|---:|
| 🟢 xpact | ✅ 1,412 | ✅ 1,295 | 2 | 0 |
| 🟠 Gobo | 1,398 | 1,055 | 3 | ❌ 1 |
</details>

<details>
<summary><b>7 · Security and limits (29 cases)</b> · 🟢 xpact</summary>

Each case runs in a fresh process with a 60 s timeout. Gobo is capped at 2 GB of memory to protect the PC. "Expected" is what a safe, Expat-compatible parser does.

| Case | Expected | 🟢 xpact | 🟠 Gobo |
|---|---|---|---|
| `billion-laughs` | REJECT | ✅ REJECT 3.1 s | ❌ TIMEOUT 60 s |
| `quadratic-blowup` | REJECT | ✅ REJECT 0.17 s | ❌ TIMEOUT 60 s |
| `entity-chain-100k` | ACCEPT | ✅ ACCEPT 1.2 s | ❌ EXCEPTION at the 2 GB cap |
| `billion-laughs-attr, -pe, recursive-*` | REJECT | ✅ REJECT | ✅ REJECT |
| `xxe-*` (3, no handler) | ACCEPT (skip) | ✅ ACCEPT | ⚠️ REJECT: external entities not supported |
| `deep-nesting-100k / 1m` | ACCEPT | ⏸️ REJECT (limit) | ACCEPT 3.5 s / TIMEOUT |
| `huge-name 10 MB, attribute 50 MB, text 100 MB, comment 50 MB` | ACCEPT | ⏸️ REJECT (limits) | ✅ ACCEPT |
| `many-attributes-100k, many-namespaces-50k` | ACCEPT | ⏸️ REJECT (limits) | ✅ ACCEPT |
| `ns-separator-in-uri` | REJECT | ❌ ACCEPT | ❌ ACCEPT |

The other cases (bad UTF-8, NUL byte, a duplicate attribute after 8 KB, small chunks) give the same verdict for both. ⏸️ = limit work paused by the student ([#293](https://github.com/andersoxie/xpact/issues/293), 10 MB limit).
</details>

<details>
<summary><b>8 · Large files (1–20 MB)</b> · 🟢 xpact · 🟠 Gobo for 20 MB</summary>

Whole document, handlers off / on. Seconds include the test harness for both engines.

| File | 🟢 xpact, no handlers | 🟠 Gobo, no handlers | 🟢 xpact, all handlers | 🟠 Gobo, all handlers |
|---|---:|---:|---:|---:|
| `records 9 MB` | ✅ 0.25 s | 1.37 s | ✅ 1.67 s | 3.38 s |
| `text 9 MB` | ✅ 0.49 s | 1.75 s | ✅ 1.23 s | 6.33 s |
| `ns 9 MB` | ✅ 1.39 s | 2.00 s | ✅ 5.46 s | 6.94 s |
| `nested 9 MB` | ✅ 0.27 s | 1.85 s | ✅ 2.38 s | 4.52 s |
| any 20 MB file | ⏸️ REJECT (10 MB limit) | ✅ ACCEPT 2.6–3.7 s | ⏸️ REJECT | ✅ ACCEPT 7–16 s |

xpact can also take these files in 64 KB pieces at almost the same speed. Gobo cannot take pieces.
</details>

<details>
<summary><b>9 · Speed, Eiffel against Eiffel (17 files)</b> · 🟢 xpact</summary>

xpact's EiffelStudio benchmark exe against Gobo's `gx_engine --bench`, on the `build/perf-inputs` documents. Time per document, start-up removed, runs alternate, median of 3, PC otherwise idle. Expat (pyexpat, no handlers, C) for scale. Raw: [speed.json](speed.json).

| File | 🟢 xpact ms | 🟠 Gobo ms | Expat ms | Gobo / xpact |
|---|---:|---:|---:|---:|
| attributes 10 KB | 0.368 | 2.2 | 0.077 | 5.98× |
| attributes 1 MB | 36.4 | 198.7 | 7.3 | 5.45× |
| attributes 10 MB | 360.5 | 1,599.7 | 74.7 | 4.44× |
| dtd 10 KB | 0.897 | 30.1 | 0.081 | ❌ 33.59× |
| dtd 1 MB | 85.3 | 2,790.6 | 7.1 | ❌ 32.73× |
| dtd 10 MB | 831.1 | 21,084.5 | 74.4 | ❌ 25.37× |
| elements 10 KB | 0.553 | 3.057 | 0.078 | 5.53× |
| elements 1 MB (UTF-8) | 52.4 | 256.9 | 6.9 | 4.90× |
| elements 1 MB (Latin-1) | 82.6 | 281.3 | 7.2 | 3.41× |
| elements 1 MB (UTF-16) | 89.7 | 424.1 | 7.8 | 4.73× |
| elements 10 MB | 511.3 | 1,980.8 | 69.0 | 3.87× |
| namespaces 10 KB | 0.35 | 2.612 | 0.069 | 7.46× |
| namespaces 1 MB | 32.9 | 228.3 | 6.1 | 6.94× |
| namespaces 10 MB | 320.3 | 1,676.1 | 62.5 | 5.23× |
| text 10 KB | 0.172 | 1.486 | 0.019 | 8.64× |
| text 1 MB | 16.4 | 133.2 | 1.4 | 8.10× |
| text 10 MB | 166.1 | 1,025.6 | 16.6 | 6.17× |

All 17 documents accepted by both. This is Gobo's XML **library**; the Gobo **compiler** building xpact itself is a different topic ([Gobo compiler for xpact](../gobo-2026-11-16/README.md)).
</details>

---

## 🧪 How it was tested

<details>
<summary><b>Setup, fairness and limits of this comparison</b></summary>

- ✅ Fresh builds of xpact from `dd75cb8`: DLL (smoke test ok) and benchmark exe. The stale `build\native-eiffel` was not used.
- ✅ New Gobo test engine [engine/gx_engine.e](engine/gx_engine.e) (about 300 lines of Eiffel), built with `gec --finalize --gc=boehm` and MSVC ([build_engine.ps1](build_engine.ps1)). It speaks the W3C runner protocol and the AlotOfTests harness protocol.
- ✅ Raw bytes go to Gobo through `parse_from_stream`, because `parse_from_string` would re-encode them as Latin-1. String mode is mixed, giving full Unicode.
- ✅ The AlotOfTests scripts ran unchanged on a copy of the harness ([harness/](harness/)), with `XP_ENGINE=xpact|gobo`. The original evidence was not touched.
- ✅ Gobo has no Expat error codes, so scoring uses verdicts only and Expat-only event kinds are left out (`XP_CONTENT_ONLY=1`).
- ✅ Fuzzing and differential ran at the same time for both engines (same CPU load). Security limits, large files and speed ran alone.
- ❌ Not compared: W3C in pieces (Test 2) and the chunked tests, because Gobo cannot take pieces. Memory and leak checks were not run for Gobo.
- ❌ The memory figures in the harness are not like-for-like (xpact's include the Python process).
- ☐ Expat is the reference in fuzzing, differential and libxml2, and Expat isn't always right. The W3C results are judged against the spec.

```bash
bash reports/gobo-xml-2026-11-18/run_all.sh A|B|C|W|S   # A correctness · B fuzz+diff · C limits+large · W W3C runner · S speed
python reports/gobo-xml-2026-11-18/analyze.py           # results.json + results.md
```

Console logs of every step: [console/](console/).
</details>

<details>
<summary><b>Status</b></summary>

- ✅ Issue [#442](https://github.com/andersoxie/xpact/issues/442) created
- ✅ W3C runner, W3C output, fuzzing, encodings, libxml2, security, large files, speed
- ⏳ Gobo differential: running (row 4 is updated when it finishes)
- ⏸️ [#293](https://github.com/andersoxie/xpact/issues/293) entity depth and the 10 MB limit: paused (by student)
</details>
