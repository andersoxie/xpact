# G01: corpus manifest and 93 reviewed W3C cases (2026-10-26)

> **Issue:** [#118](https://github.com/andersoxie/xpact/issues/118) (task G01, draft 11) · **Date:** 2026-10-26
> · **Code:** `student-Mass` @ `c532e81` · **Selected by the student; not reviewed by the supervisor** (the student decided to skip that review)

## In short

| | |
|---|---|
| 🎯 Goal | A portable list of W3C XML test cases with sources, hashes, dependencies and **reviewed** expected outcomes: the agreed regression set for xpact (guide, week 4) |
| 📋 Result | **93 cases**: **83 counted** (46 accept, 37 reject) + **10 marked, not counted** (external entities, XML 1.1, another edition, `error`) |
| ✅ Review | **93 / 93** pass the automatic review (expected outcome vs the guide's table, today's result in both builds); 5 read by eye, all right |
| ✅ Today | the 83 counted cases **pass** in both finalized builds; the 10 marked ones are **skipped** by the runner, as they must be |
| 🔁 Portable | `make_manifest.py --check` verifies every path and SHA-256 on any copy of the suite |

## The files

| File | What |
|---|---|
| [`manifest.tsv`](manifest.tsv) | **the manifest**: one row per case (columns below) |
| [`summary.md`](summary.md) | suite and hashes, counts by category and type, today's results |
| [`make_manifest.py`](make_manifest.py) | makes both, or checks the manifest (`--check`) |

`manifest.tsv` columns: `id` · `category` · `collection` · `path` (relative to
`xmlconf/`) · `sha256` · `bytes` · `type` (valid, invalid, not-wf, error) ·
`expected` (ACCEPT/REJECT; in brackets when not counted) · `counted` ·
`skip_reason` · `recommendation` · `version` · `edition` · `namespace` ·
`entities` · `sections` (XML spec sections) · `dependencies` (external entities,
the W3C canonical output file) · `today_finalized` ·
`today_finalized_assertions` · `review` · `description`.

## What is in it

| Category | Counted | Accept / reject | How it is chosen |
|---|---|---|---|
| namespaces | 8 | 4 / 4 | `eduni/namespaces/1.0/` |
| encodings | 10 | 5 / 5 | spec 4.3.1/4.3.3 (encoding declarations), or the file itself: UTF-16 byte order mark or a non-UTF-8 encoding |
| entities | 10 | 5 / 5 | character and entity references, entity declarations (spec 4.1-4.5) |
| dtd | 10 | 5 / 5 | document type, element and attribute-list declarations (2.8, 3.2, 3.3) |
| attributes | 10 | 5 / 5 | attribute values and attributes (productions 10, 41; 3.3.3 normalisation) |
| tags | 10 | 5 / 5 | start, end and empty-element tags (3.1) |
| text | 10 | 5 / 5 | character data, comments, PIs, CDATA (2.4-2.7) |
| characters | 6 | 3 / 3 | characters, names, literals (2.2, 2.3) |
| invalid | 6 | 6 / 0 | well formed but breaks DTD validity: a non-validating parser **accepts** |
| largest | 3 | 3 / 0 | the largest applicable inputs |
| **not counted** | 10 | - | 4 need external entities, 3 XML 1.1, 1 another edition, 2 `error` (no required verdict) |

**How the cases are picked:** the catalog is read with `load_catalog()` of
`scripts/run_w3c_conformance.py`, so "expected" and "counted" are the runner's
own decision (the runner Jenkins uses). Within each category the candidates are
taken evenly spread over the catalog order, half expected to be accepted and
half rejected where both exist, so the set mixes the `xmltest`, `sun`, `oasis`,
`ibm` and `eduni` collections. Rerunning the script gives the same 93 cases.

**Not in it:** the 12 Japanese cases (the runner skips all of them: 6 need
external parameter entities, 6 are `error` cases with no required verdict),
Xpact-core inputs (G01 extension, see F02), SVG/libxml2/PubMed.

## The review

| Check | Done by | Result |
|---|---|---|
| Expected outcome follows the guide's table (`valid`, `invalid` → ACCEPT; `not-wf` → REJECT; `error` → no verdict) | `review` column, every case | 93 ok |
| External-entity, XML 1.1, other-edition and `error` cases are marked and not counted | `counted`, `skip_reason` | 10 marked |
| Today's runner agrees (2026-10-26, `student-Mass` @ `e8c5cb3`, MSVC): counted → `passed`, not counted → `skipped`, both builds | `review` column | 93 ok |
| Read by eye | the student's session, 2026-10-26 | 5 / 5 right: `rmt-ns10-001` (good namespace URI → accept), `o-p02fail15` (UTF-16 with control character 0x11 → reject), `not-wf-sa-101` (`encoding=" UTF-8"` → reject), `valid-sa-049` (UTF-16 with BOM → accept), `inv-dtd01` (`(#PCDATA\|x\|x)*`, a validity error only → accept) |

## How to use and repeat

```powershell
# the suite is downloaded by run_benchmarks.ps1 / run_w3c_conformance.py into build\validation-corpora\
python -I student\results\G01-corpus\make_manifest.py `
  --suite-dir build\validation-corpora\w3c-xml-20130923\xmlconf `
  --today build\benchmarks\w3c-xml-conformance\results.tsv
# on another machine, verify the suite copy against the manifest:
python -I student\results\G01-corpus\make_manifest.py --check --suite-dir <path to xmlconf>
```

Python 3.11 or newer. The suite is `xmlts20130923`, archive SHA-256
`f9510b35…68deb` (pinned in the runner); root catalog SHA-256 in [summary.md](summary.md).

## Limitations

- **Not reviewed by the supervisor**, which the G01 task asks for; the student chose to skip it.
- "Reviewed" means checked against the guide's rules, the catalog and today's
  results, plus 5 cases by eye, not all 93 by eye.
- Today every counted case passes, so the set has no current failure in it; it
  is a regression set (it must keep passing), not a list of open bugs.
- Only the binary verdict is covered. The 34 linked canonical outputs make an
  event check possible later; it is not done here.
