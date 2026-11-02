# 4 · Differential testing against Expat

> **Question:** On the same generated input, do xpact and Expat agree on verdict and events?
> **Status:** ✅ run (2026-10-28) · ✅ no crash in 1.46 million documents · 🔴 2 new problems + 2 known ones found again · nothing changed in xpact

[⬅ back to AlotOfTests](../README.md)

## In short

[diff.py](diff.py) builds random documents with most XML features, sends each through both parsers (whole document) and compares:
- the verdict;
- the error code;
- the events, when both accept.

Features used: XML declaration, DOCTYPE with entities, parameter entities, notations, `ELEMENT` and `ATTLIST` declarations, `#FIXED`/`#REQUIRED`/defaults, tokenized types, namespaces, CDATA, comments, PIs, character references, non-ASCII names. One document in five gets a small mutation.

| | Documents |
|---|---:|
| Generated (20 min, seed 1) | **1,457,486** |
| ✅ both accept | 829,531 |
| ✅ both reject | 627,056 |
| verdict differs | 899 (0.06 %) |
| crashes / hangs | **0** |

Result with a minimal example per group: [logs/diff-xpact-seed1.json](logs/diff-xpact-seed1.json) · console: [logs/diff-xpact-seed1.txt](logs/diff-xpact-seed1.txt)

## What differs

| Group | Count | Minimal example | xpact | Expat | Problem |
|---|---:|---|---|---|---|
| 🔴 default value of a tokenized attribute not normalized in `attlistdecl` | 145,098 | `<!ATTLIST _u ks NMTOKENS #FIXED " 𝄞">` | `" 𝄞"` | `"𝄞"` | = F01-3 |
| 🔴 public ID of a notation not normalized | 119,828 | `<!NOTATION n1 PUBLIC " q">` | `" q"` | `"q"` | = F01-4 |
| 🔴 **`#FIXED` reported as not required** | 98,344 | `<!ATTLIST e b CDATA #FIXED "">` | `isrequired = 0` | `isrequired = 1` | **F04-1** (new) |
| 🔴 **`xmlns=""` reports URI `""` instead of NULL** | 10,611 | `<f><e xmlns=""/></f>` | `startns(NULL, "")` | `startns(NULL, NULL)` | **F04-2** (new) |
| ⚪ `version=''` | 834 | `<?xml version=''?>` | REJECT | ACCEPT | xpact is right: `VersionNum` is `1.` + digits; Expat is lenient |
| ⚪ `encoding='utf8'`, `'utf'` | 65 | | | | Python `pyexpat` artefact: it maps unknown names to Python codecs. C Expat reports "unknown encoding" |
| 🟡 different error code, same REJECT | ~157,000 | `<E x>`: "syntax error" vs "invalid token" | | | error-code compatibility, compare #122–#126 |

### 🔴 F04-1 · `#FIXED` attributes reported with `isrequired = 0`

| Field | |
|---|---|
| **Environment** | `xpact.dll` from `w9-latest` (`student-Mass` `293918f`), Python 3.14 ctypes harness |
| **Command** | `python diff.py --seconds 1200 --seed 1`; repro: `<!DOCTYPE d [<!ATTLIST d a CDATA #FIXED "v">]><d a="v"/>` |
| **Expected** | Expat API: `XML_AttlistDeclHandler(…, dflt, isrequired)`, where `dflt != NULL` and `isrequired = 1` means `#FIXED` |
| **Actual** | `isrequired = 0`, so an application cannot tell `#FIXED "v"` from a plain default `"v"` |
| **Cause** | unknown; found in 11 libxml2 test files as well (test 7) |

### 🔴 F04-2 · Default namespace undeclared with `xmlns=""`: URI `""` instead of NULL

| Field | |
|---|---|
| **Expected** | Expat calls `StartNamespaceDeclHandler(prefix = NULL, uri = NULL)` for `xmlns=""` |
| **Actual** | xpact passes an empty string `""` |
| **Cause** | unknown |

## Limitations

- Expat = Python's `pyexpat` 2.7.3, not the C library with default settings. Differences in encoding handling come from Python, and are marked ⚪.
- Only whole documents; chunking is test 2.
- The shrinker keeps the same group; it is minimal for that group, not always for the bug.

## To do

- [ ] Issues for F04-1 and F04-2
- [ ] Compare the error-code groups with #122–#126
- [ ] Generator: external entities, conditional sections, more namespace cases
