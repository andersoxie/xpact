# 5 · Security and limits

> **Question:** Is xpact safe against known XML attacks, and how does it handle extreme input?
> **Status:** ✅ run (2026-10-28) · 🟢 no crash, no memory blow-up, no external file read · 🔴 4 problems found · nothing changed in xpact

[⬅ back to AlotOfTests](../README.md)

## In short

| Area | Result |
|---|---|
| ✅ Billion laughs, quadratic blow-up, recursive entities | all rejected, no crash |
| ✅ External entities without a handler (XXE) | nothing loaded, no file content in the events |
| ✅ 100,000 nested entity references (CVE-2024-8176) | accepted, no stack overflow |
| ✅ Broken UTF-8 in names and attributes, NUL byte (CVE-2022-25235) | rejected |
| ✅ No crash and no hang on any input | except the streaming slowdown below |
| 🟡 **Built-in limits** (by design, Expat has none) | documents deeper than 256, more than 1,024 attributes, names over 512 KB, more than 10 MB of input are **rejected** |
| 🔴 **Streaming is quadratic** (F05-1) | 2 MB fed in 64 KB chunks: 55 s (Expat 0.6 s) |
| 🔴 Namespace URI containing the separator is accepted (F05-2, CVE-2022-25236) | Expat rejects |
| 🔴 Wrong error codes for limits (F05-3) | "syntax error" instead of "amplification limit breached" / a limit message |
| 🔴 Rejecting billion laughs takes 18 s (F05-4) | Expat 0.6 s |

## 1. Attacks and extreme inputs ([run.py](run.py))

Each case in a fresh child process, 60 s timeout. The time and memory include the Python harness.
Measured while test 2 was running on the same PC, so only the **difference** between xpact and Expat is meaningful.

| Case | Expected | xpact | Expat | |
|---|---|---|---|---|
| billion-laughs (10⁹ × "lol") | REJECT | REJECT, **17.9 s**, "syntax error" | REJECT 0.57 s, amplification limit | ✅ verdict · 🔴 F05-3/4 |
| billion-laughs in an attribute | REJECT | REJECT, 9.1 s, "syntax error" | REJECT 0.10 s | ✅ · 🔴 F05-3/4 |
| billion-laughs with parameter entities ⚠ | REJECT | REJECT | REJECT "illegal parameter entity reference" | ✅ (⚠ my test is not-wf for another reason; needs an external DTD) |
| quadratic blow-up (50 KB × 4,000) | REJECT | REJECT 2.6 s | REJECT 0.02 s | ✅ |
| 100 × "lol" (must stay allowed) | ACCEPT | ACCEPT | ACCEPT | ✅ |
| recursive entity: direct / indirect / parameter | REJECT | REJECT ×3 | REJECT ×3 | ✅ |
| entity chain 10,000 / 100,000 deep (CVE-2024-8176) | ACCEPT | ACCEPT 0.3 s / 3.8 s, 113 MB | ACCEPT 0.02 s / 0.18 s | ✅ |
| 100,000 / 1,000,000 nested elements | ACCEPT | **REJECT** "syntax error" | ACCEPT | 🟡 depth limit 256 |
| 10 MB name | ACCEPT | **REJECT** "out of memory" | ACCEPT | 🟡 name limit / input limit |
| 50 MB attribute, 100 MB text, 50 MB comment | ACCEPT | **REJECT** "out of memory" | ACCEPT | 🟡 10 MB input limit |
| 100,000 attributes / 50,000 namespace declarations | ACCEPT | **REJECT** "syntax error" | ACCEPT | 🟡 attribute limit 1,024 |
| 1,000 attributes + a duplicate | REJECT | REJECT "duplicate attribute" | same | ✅ |
| one 4 MB start tag in 4 KB chunks (CVE-2023-52425) | ACCEPT | ACCEPT 1.4 s | ACCEPT 0.03 s | ✅ (slow, F05-1) |
| 200 KB text byte by byte | ACCEPT | **TIMEOUT** (> 60 s) | ACCEPT 0.08 s | 🔴 F05-1 |
| XXE: external entity / parameter entity / DTD, no handler | ACCEPT, nothing read | ✅ ×3 | ✅ ×3 | ✅ |
| `xmlns:a="http://x\|y"` with separator `\|` (CVE-2022-25236) | REJECT | **ACCEPT** | REJECT "syntax error" | 🔴 F05-2 |
| broken UTF-8 (2-, 3-, 4-byte), NUL byte | REJECT | REJECT ×4 | REJECT ×4 | ✅ |

Per case: [logs/security-xpact.tsv](logs/security-xpact.tsv) · console: [logs/run-xpact.txt](logs/run-xpact.txt)

## 2. Where the limits are ([limits.py](limits.py))

| Limit (source: `src/xp_limits.e`, `src/xp_native_parser.e`) | Last accepted | First rejected | xpact's error | Expat |
|---|---:|---:|---|---|
| Element depth (`Default_max_element_depth = 256`) | 256 | 257 | syntax error | no limit |
| Attributes per element (`Default_max_attribute_count = 1024`) | 1,024 | 1,025 | syntax error | no limit |
| Namespace declarations per element (same limit) | 1,024 | 1,025 | syntax error | no limit |
| Name length (`set_max_name_length (524288)` in the DLL) | 524,288 | 524,289 | syntax error | no limit |
| Attribute value just over 1 MiB | accepted | | | |
| Total input (`Default_max_input_bytes = 10 MiB`) | | > 10 MiB, also when **streamed** | out of memory | no limit |

[logs/limits.txt](logs/limits.txt) (the streamed rows stopped at the timeout, see F05-1)

## 3. Streaming speed ([scaling.py](scaling.py))

The same document whole, and in 64 KB chunks (the way an application reads a file):

| Document | Size | xpact whole | xpact 64 KB chunks | Expat chunks |
|---|---:|---:|---:|---:|
| one text node | 512 KB | 0.20 s | 3.0 s | 0.003 s |
| | 1 MB | 0.42 s | 3.6 s | 0.004 s |
| | 2 MB | 0.87 s | **14.6 s** | 0.007 s |
| many small elements | 512 KB | 1.1 s | 4.6 s | 0.13 s |
| | 1 MB | 2.0 s | 13.6 s | 0.26 s |
| | 2 MB | 4.3 s | **55.1 s** | 0.56 s |

**Double the size → four times the time** in chunked mode: quadratic. [logs/scaling.txt](logs/scaling.txt)

## 4. C-API misuse and CVE probes ([api_probes.py](api_probes.py))

Each probe in its own process; expected = Expat 2.8.1's documented behaviour (checked in `xmlparse.c` where unsure).

| Probe | Expected (Expat) | xpact, both builds |
|---|---|---|
| `XML_Parse` with length −1 (CVE-2024-45490) | error 41 invalid argument | ✅ |
| `XML_Parse(NULL, 5)` | error 41 | ✅ |
| `XML_ParseBuffer` without `XML_GetBuffer` | error 42 no buffer | ✅ |
| `XML_GetBuffer(-1)` / `(2³¹−1)` | NULL, error 1 no memory (`xmlparse.c:2445`) | ✅ ✅ |
| `XML_ResumeParser` before parsing / after an abort (CVE-2024-50602) | error 34 not suspended | ✅ ✅ |
| `XML_StopParser` before parsing / after the end | error 44 / 36 | ✅ ✅ |
| `XML_Parse` after the final buffer | error 36 finished | ✅ |
| `XML_ParserFree(NULL)` | no crash | ✅ |
| `XML_ParserReset` after an error, then parse | OK | ✅ |
| `XML_SetEncoding` after parsing started | refused | ✅ |
| Suspend inside a handler, resume twice | 2 (suspended), 2, 1 (OK), events `d`, `e` | ✅ |

**14 of 14 in both builds.** [logs/api-probes.json](logs/api-probes.json)

## Problems (CLAUDE.md format)

### 🔴 F05-1 · Streaming input is quadratic, and the 10 MB limit covers the whole stream

| Field | |
|---|---|
| **Problem** | Feeding a document in several `XML_Parse` calls costs time proportional to (size)²; 2 MB in 64 KB chunks takes 55 s; 200 KB byte by byte does not finish in 60 s. Documents over 10 MB are rejected even when streamed |
| **Environment** | `xpact.dll` from `w9-latest` (`student-Mass` `293918f`), Windows 11, Python 3.14 ctypes harness |
| **Command** | `python scaling.py`; `python run.py` (case `big-text-byte-chunks`) |
| **Expected** | time grows linearly, like the whole-document mode and like Expat |
| **Actual** | table above |
| **Investigation** | same harness and callbacks in both modes; whole mode is linear; Expat is linear with the same harness |
| **Cause** | ✅ **confirmed by code reading:** `parse_with_current_gc_policy` in `src/xp_native_parser.e` (around line 835) appends each chunk to `input_buffer`, then decodes and parses the **whole** buffer again on every call (`decoded_input (input_buffer)`, `handler.reset_events`, callbacks already delivered are skipped). The 10 MB check is `a_input.count > parser.max_input_bytes - input_buffer.count`, so it applies to the total |
| **Fix** | none yet; needs an incremental parser (keep the parser state between calls) or at least dropping the consumed prefix |
| **Verification** | ⬜ |

### 🔴 F05-2 · A namespace URI containing the namespace separator is accepted (CVE-2022-25236)

| Field | |
|---|---|
| **Command** | `<d xmlns:a="http://x\|y"><a:e/></d>` with `XML_ParserCreateNS(NULL, '\|')` |
| **Expected** | REJECT, as Expat ≥ 2.4.5: the application splits `uri\|local` at the separator, so a URI containing it can inject a fake local name |
| **Actual** | ACCEPT |
| **Cause** | unknown: the check is missing |

### 🔴 F05-3 · Limits and amplification report misleading error codes

| Field | |
|---|---|
| **Expected** | billion laughs: `XML_ERROR_AMPLIFICATION_LIMIT_BREACH` (43), as Expat; own limits: a clear code |
| **Actual** | billion laughs and quadratic blow-up: `XML_ERROR_SYNTAX` "syntax error"; depth, attribute and name limits: "syntax error"; input limit: "out of memory" |
| **Cause** | unknown: the code for 43 exists in `xp_native_parser.e` (`Xml_error_amplification_limit_breach`), but this path reports a syntax error |

### 🔴 F05-4 · Rejecting billion laughs is slow

| Field | |
|---|---|
| **Actual** | 17.9 s (content), 9.1 s (attribute) before the REJECT; Expat 0.6 s / 0.1 s |
| **Cause** | unknown; suspected: entity text is built up to the 8 MiB expansion limit before the check fires |

### 🟡 Limits by design (not bugs, but they need a decision)

- xpact rejects valid documents that Expat accepts: depth > 256, > 1,024 attributes, names > 512 KB, input > 10 MB.
- They protect against attacks, but **256 levels** and **10 MB in total** are low for real files (see test 11).
- To decide with the supervisor: keep, raise, or make them configurable (like Expat's `XML_SetBillionLaughsAttackProtection…`).

## Limitations

- Only the DLL path. The Eiffel executable has the same `XP_LIMITS`, but was not measured here.
- The timings include the Python callback overhead.

## To do

- [ ] Issues for F05-1 … F05-4, and the limits decision for the supervisor
- [ ] Rerun with `xpact_assertions.dll`
- [x] Add the C-API CVE probes: 14/14, both builds
