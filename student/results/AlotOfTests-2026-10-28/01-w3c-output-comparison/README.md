# 1 · W3C output comparison

> **Question:** xpact gives the right **verdict** on all W3C cases, but does it also report the right **content**
> (elements, attributes, text, PIs, notations)?
> **Status:** ✅ run (2026-10-28) · 🔴 6 problems found · nothing changed in xpact

[⬅ back to AlotOfTests](../README.md)

## In short

| | Result |
|---|---|
| Cases with an expected output file (`OUTPUT` in the W3C catalog) | **432** |
| ✅ xpact's output is exactly the expected one | **359** |
| ⚪ Expat differs as well (XML 1.1 documents; xpact reads them as 1.0) | 29 |
| 🟡 Optional error: xpact rejects, Expat accepts (either verdict is allowed) | 4 |
| 🔴 **Only xpact differs** | **40**, from 6 separate problems (below) |
| Assertions build (`xpact_assertions.dll`) | identical, case by case |

**Extra (1b): the verdict of all 2,585 cases through the DLL**, not only the 247 of the DLL entity lane:

| Result | Cases | Meaning |
|---|---:|---|
| ✅ right verdict | 1,654 core + 309 legacy + 302 no-crash | |
| ⚪ "wrong" verdict, same as Expat | 318 | 5th-edition name characters: the DLL uses the 4th-edition name tables on purpose (Expat compatibility), see the `legacy-names` lane |
| 🔴 **wrong verdict, xpact only** | **2** | `hst-lhs-007`, `hst-lhs-008` (problem 7) |
| crashes / timeouts | 0 | both builds |

### 🔧 Fix for F01-1 and F01-2 (2026-10-28, local, not committed)

✅ **359 → 393 / 432**, 0 cases worse, both builds; all old test lanes unchanged. Details and logs: [fix-F01-1/README.md](fix-F01-1/README.md). Issue drafts (not on GitHub): [issue-drafts/](issue-drafts/).

| ID | Status |
|---|---|
| F01-1 | ✅ fixed locally (30/30) |
| F01-2 | ✅ fixed locally (1/1) |
| F01-3 | 🟡 3 of 4 fixed by the same change; `valid-sa-096` left |
| F01-4, F01-5, F01-6 | ⬜ not started |

### 🔁 Rerun (2026-10-28, later the same day)

✅ **Reproduced exactly.** Same DLLs (`student-Mass` `293918f`), both builds, assertions build first:
`python run.py --dll <w9-latest>\build\native-eiffel\xpact_assertions.dll --out logs-rerun-2026-10-28/assertions` (and the same with `xpact.dll` → `normal`).
Result in both builds: 359 pass · 44 xpact only (40 problems + 4 optional) · 29 both differ. Each case's status is **identical** to the first run ([logs-rerun-2026-10-28/](logs-rerun-2026-10-28/)). The first run's `logs/` are kept as the baseline.

## Problems found (one per future issue)

| # | Problem | Cases | Cause |
|---|---|---:|---|
| 🔴 F01-1 | **Attribute defaults from the external DTD are not applied.** `<!ATTLIST d a CDATA "x">` in an external DTD or external parameter entity: the `attlistdecl` event fires, but `<d>` gets no `a="x"`. A later internal declaration then wins, although the **first** declaration should (`sa-097`, `not-sa-026`) | 30 | suspected: declarations parsed by the external-entity child parser do not reach the parent's attribute-default table (general entities do, see repro) |
| 🔴 F01-2 | **Defaults not applied inside an external general entity.** `<e/>` inside `&x;` (external) gets no default attributes; the same `<e/>` in the document does | 1 | suspected: the child parser has no access to the parent's attribute defaults |
| 🔴 F01-3 | **Tokenized attribute values are not normalized.** For `NMTOKENS`, `ID`, `IDREFS`, `ENTITIES`, `NOTATION`… spaces must be collapsed and trimmed (§3.3.3): `" 1  2 "` → `"1 2"`. Also with an internal DTD | 4 | unknown |
| 🔴 F01-4 | **Public identifier not normalized** in a notation declaration: line break and spaces must become one space | 1 | unknown |
| 🔴 F01-5 | **A second byte order mark is dropped.** An external entity starting with two `U+FEFF`: the first is the BOM, the second is text and must be reported | 3 | unknown |
| 🔴 F01-6 | **External parameter entity inside an entity value is parsed as declarations.** `<!ENTITY e "<![CDATA[%e;]]>">`: the text of `%e;` belongs **in the value** (§4.4.5 "included in literal"). xpact fires an `attlistdecl` from it and leaves the value empty | 1 | unknown |
| 🔴 F01-7 | **Two wrong verdicts through the DLL** (the Eiffel W3C run has them right): `hst-lhs-007` UTF-8 BOM + `encoding='iso-8859-1'` is accepted (Expat accepts too); `hst-lhs-008` UTF-16 BOM + `encoding='utf-8'` is accepted (Expat rejects) | 2 | suspected: the DLL's input path handles the BOM before the parser sees the declaration; the C checker `xpact_w3c_case.exe` gives the same ACCEPT |

### Cases per problem

<details><summary>Click to open the list</summary>

- **F01-1:** `invalid-not-sa-022`, `valid-sa-097`, `valid-not-sa-003` `004` `005` `006` `007` `008` `009` `011` `012` `013` `014` `015` `016` `017` `018` `019` `020` `021` `023` `024` `025` `026` `028` `029`, `ibm-invalid-P32-ibm32i01`, `ibm-valid-P32-ibm32v01` `v03` `v04`
- **F01-2:** `valid-ext-sa-013`
- **F01-3:** `valid-sa-096`, `ibm-invalid-P32-ibm32i03`, `not-sa02`, `not-sa03`
- **F01-4:** `notation01`
- **F01-5:** `valid-ext-sa-014`, `invalid-bo-4`, `invalid-bo-5`
- **F01-6:** `valid-not-sa-031`
- **F01-7:** `hst-lhs-007`, `hst-lhs-008`
- 🟡 optional (not a problem): `ibm-invalid-P68-ibm68i01`–`i04`: an undeclared entity in an attribute default in the external DTD; xpact rejects ("undefined entity"), Expat accepts
</details>

### Small reproductions (F01-1, F01-2)

Files in [mini/](mini/):

| Input | xpact | Expat |
|---|---|---|
| `ext-dtd.xml`: external DTD declares `g` and a default for `d/@a` | `<d>` **no attribute**, `&g;` expanded | `<d a="default-from-dtd">`, `&g;` expanded |
| `ext-ent.xml`: `<e/>` once through an external entity, once directly | first `<e>` **no attribute**, second `a="dflt"` | both `a="dflt"` |

## Problem report (CLAUDE.md format), shared by F01-1 … F01-7

| Field | |
|---|---|
| **Environment** | Windows 11, student PC; `xpact.dll` and `xpact_assertions.dll` from `w9-latest` (= `student-Mass` `293918f`, tree `f196d8c`), built with EiffelStudio 25.12 + MSVC 19.51; Python 3.14; Expat reference = `pyexpat` 2.7.3 |
| **Command** | `python run.py` and `python verdicts_all.py` in this folder (`--dll …\xpact_assertions.dll` for the assertions build) |
| **Expected** | the catalog's `OUTPUT` file, byte for byte; the runner's expected verdict |
| **Actual** | see the tables above; per case: [logs/results.tsv](logs/results.tsv), [logs/verdicts-xpact.tsv](logs/verdicts-xpact.tsv); differences: [logs/diffs/](logs/diffs/) |
| **Investigation** | Expat as a control on every case; minimal repro files; the project's own C checker for F01-7; both builds |
| **Cause** | suspected or unknown (column above), not confirmed in the Eiffel code yet |
| **Fix** | none yet |
| **Verification** | ⬜ after a fix: rerun `run.py` and `verdicts_all.py` |

## How it works

1. [`run.py`](run.py): loads the W3C catalog with the project's runner (`scripts/run_w3c_conformance.py`), takes every case with `OUTPUT`.
2. The document is parsed through `xpact.dll` with the Expat C API ([harness/engines.py](../harness/engines.py)): no namespace processing, parameter entities on, external files only from the suite folder (as `tests/native/xpact_w3c_case.c` does).
3. The events become **James Clark canonical XML** ([harness/canonical.py](../harness/canonical.py)): sorted attributes, `&#10;` for line breaks, no comments, notations in a DOCTYPE.
4. Exactly the same is done with Expat, so a difference in **both** points at the harness or the suite, a difference in **xpact only** points at xpact.
5. Each parse runs in a child process ([harness/pool.py](../harness/pool.py)), so a crash or hang costs one case, not the run.

## Limitations

- Only the DLL path is checked; the Eiffel executable used by Jenkins does not print events. Both use the same Eiffel parser, so the problems are probably in the parser, but that is not confirmed.
- The W3C has an output file for 432 of 2,585 cases (only valid and invalid documents).
- Third canonical form (`OUTPUT3`) does not occur in this catalog.

## To do

- [ ] Check F01-1 … F01-7 against the known Expat differences #122–#126 (are some already known?)
- [ ] One issue per problem, with the repro files
- [ ] Find the cause in `src/xp_parser.e` / the native bridge
- [ ] Add this comparison as a lane next to the W3C verdict run
