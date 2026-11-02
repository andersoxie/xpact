# 7 · libxml2's test corpus

> **Question:** Does xpact handle libxml2's test files the same way as Expat?
> **Status:** ✅ run (2026-10-28) · ✅ 1,269 of 1,417 files identical to Expat · 🔴 1 serious new problem (F07-1), 1 small one (F07-2), the rest already known · nothing changed in xpact

[⬅ back to AlotOfTests](../README.md)

## In short

libxml2 at commit `2034036d` (2026-10-27), shallow clone in `download/` (not for git). All 1,417 files under `test/` except the HTML folders were run through `xpact.dll` and Expat. External files come only from that folder; `test/namespaces` uses the namespace parser.

| | Files |
|---|---:|
| ✅ same verdict, error code and events as Expat | **1,269** |
| 🟡 same verdict, other error code | about 120 |
| 🔴 same verdict, other events | 22 (all explained below) |
| verdict differs | 3 (`t4`, `t4a`, `iso-8859-5`, see ⚪ below) |
| ⏱ xpact timeout | **2** (F07-1) |

Per file: [logs/libxml2-xpact.tsv](logs/libxml2-xpact.tsv) · groups: [logs/libxml2-xpact-summary.json](logs/libxml2-xpact-summary.json) · console: [logs-run.txt](logs-run.txt)

## Groups

| Group | Files | Example | Problem |
|---|---:|---|---|
| ⏱ **billion laughs through external entities: xpact runs on and on** | 2 | `recurse/lol_eg.xml`, `lol_ep.xml` | 🔴 **F07-1** |
| `#FIXED` with `isrequired = 0` | 11 | `defattr.xml`, `issue643.xml` | = F04-1 |
| external parameter entity in an entity value | 2 | `valid/pe-val-latin1.xml`, `valid/t11.xml` | = F01-6 (here the text even appears as a `chars` event inside the DTD) |
| tokenized default not normalized | 1 | `att9` | = F01-3 |
| **predefined entities `lt` `gt` `amp` `apos` `quot` reported as `entitydecl`** | 6 | `ent6`, `valid/REC-xml-19980210.xml`, `valid/xhtml1.xhtml` | 🔴 **F07-2** (small) |
| billion laughs: "syntax error" instead of the amplification code | 6 | `recurse/lol_classic.xml` | = F05-3 |
| ⚪ `valid/t4.xml`, `t4a.xml`: xpact ACCEPT, Expat REJECT | 2 | `<!ENTITY %percent; def "ghi">` in the external DTD | xpact agrees with libxml2 (the file is in libxml2's `valid` folder); Expat is the odd one |
| ⚪ encodings `iso-8859-5`, ICU, `unsupported-encoding` | 3 | | Python `pyexpat` codec artefact |
| 🟡 other error codes | ~119 | `c14n/…` "invalid token" vs "syntax error" | error-code compatibility, compare #122–#126 |

## 🔴 F07-1 · Billion laughs through external entities is not stopped

| Field | |
|---|---|
| **Environment** | `xpact.dll` from `w9-latest` (`student-Mass` `293918f`), Python 3.14 ctypes harness, the same external-entity loader for both parsers |
| **Command** | `python run.py`; then each file alone with a 300 s timeout |
| **Input** | `recurse/lol_eg.xml`: `g3` → 10 × `g2` → 10 × `g1` → … , every level an **external** file (`lol_ep.xml`: the same with parameter entities) |
| **Expected** | rejected by the amplification limit, as Expat does after 15–18 s ("error in processing external entity reference", the child parser hit the limit) |
| **Actual** | still running after **300 s** (the child process was stopped) |
| **Investigation** | internal billion laughs **is** stopped (test 5); only the external version is not |
| **Cause** | suspected: xpact counts the amplification per parser, and each external entity gets a new child parser, so the total is never reached. Expat counts parent + children together |
| **Fix / Verification** | none yet / ⬜ |

## 🔴 F07-2 · Declarations of the predefined entities are reported

`<!ENTITY lt "&#38;#60;">` and the other four predefined entities may be declared (§4.6). Expat does **not** call `EntityDeclHandler` for them; xpact does. Small, but it changes the event stream (`ent6`: 9 events in xpact, 4 in Expat).

## Limitations

- libxml2 has no machine-readable expected verdicts for most files, so Expat is the reference; where Expat looks wrong it is marked ⚪.
- Expat = Python's `pyexpat` 2.7.3 (Python-codec encoding handler).
- The harness loads external entities in Python, which is slower than C; the times compare xpact and Expat with the same loader.

## To do

- [ ] Issues for F07-1 (security) and F07-2
- [ ] Rerun with `xpact_assertions.dll`
- [ ] Use the corpus as fuzzing seeds (test 3)
