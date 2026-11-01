# More tests for xpact: sources found online

> **Written:** 2026-11-01 · **For:** week 8 ("add selected SVG or libxml2 cases") and later · links checked in a web search on 2026-11-01
> ✅ already used · ⭐ recommended next · 🟡 useful, more work · ⚪ optional · ⛔ blocked today (see the note)
>
> **⛔ Two things to know before running large or chunked files:**
> - xpact rejects input over **10 MB** and nesting over **256 levels** (`src/xp_limits.e`; AlotOfTests test 05).
> - Streaming large files is slow, because the DLL re-parses on every call (F05-1).
>
> Large files therefore need a raised limit, or must be fed whole.

## 🚦 At a glance

| Group | Sources | Best next step |
|---|---|---|
| ✅ Already used | 6 (W3C suite, Expat 2.8.1 and its unit tests, pyexpat, libxml2 test files, CPython XML tests, Expat CVE cases) | the list is [below](#-already-used) |
| Conformance and other parsers' test files | 6 | ⭐ Expat's `xmltest.sh` expected results; ⭐ pugixml's UTF-16/UTF-32 files |
| Malformed input and encodings | 1 | ⭐ Markus Kuhn's UTF-8 stress test |
| Security | 3 | ⭐ RUB-NDS DTD-Attacks payloads |
| Fuzzing | 3 | 🟡 Expat's fuzz harnesses with AFL++'s `xml.dict` |
| Large real-world files | 9 | ⭐ dblp (entities), ⭐ UW XML Data Repository (mid-size); others ⛔ until the 10 MB limit is handled |

---

## ✅ Already used

| Source | Where | Used in |
|---|---|---|
| W3C XML Conformance Test Suite 2013-09-23 (OASIS, IBM, James Clark, Sun, errata, XML 1.1) | [w3.org/XML/Test](https://www.w3.org/XML/Test/) | all 2,585 cases, the output test (432), the in-pieces test, G01/G03 |
| Expat 2.8.1 (reference parser) and its unit tests `tests/runtests.c` | [github.com/libexpat/libexpat](https://github.com/libexpat/libexpat), tag `R_2_8_1` | the C# comparison (4,308), the Jenkins `runtests` stage (399 checks) |
| Python's `pyexpat` 2.7.3 | ships with Python | second reference in `AlotOfTests` |
| libxml2 test files (1,417) | [github.com/GNOME/libxml2](https://github.com/GNOME/libxml2) `test/` | `AlotOfTests` 07 |
| CPython's XML tests (976) | CPython `Lib/test/` | `AlotOfTests` 10 |
| Known Expat CVE inputs (for example CVE-2023-52425, CVE-2022-25236) | Expat's security fixes | `AlotOfTests` 05 |

---

## 1. Conformance and other parsers' test files

| | Source | What it tests | Size | Effort | Notes |
|---|---|---|---|---|---|
| ⭐ | **Expat's `xmltest.sh` and `xmltest.log.expected`** (in Expat's `tests/` folder) | Runs the W3C suite through Expat's `xmlwf` and lists exactly which cases Expat fails or gives different output for. The expected log is Expat's own record of its known results. | small (script + log) | ~2 h | Lets xpact be compared with Expat's **own** record per W3C case, including the canonical-output cases. [Script](https://nxr.netbsd.org/xref/src/external/mit/expat/dist/tests/xmltest.sh), [expected-output change](https://fuchsia.googlesource.com/third_party/expat/+/379213ca196f82d19ae72195c4a9bec0553d0bb2%5E%21/) |
| ⭐ | **pugixml `tests/data`** | Encodings: `utftest_*` in UTF-8, UTF-16 and UTF-32, big- and little-endian, with and without BOM and XML declaration; Latin-1; truncation; empty files | small | ~1–2 h | Good for xpact's BOM and encoding handling (#158, F08-1). Get it from the GitHub tag archive; release tarballs may not include tests. [Mirror listing](https://gitverse.ru/githubmirror/omim/content/master/3party/pugixml/tests/data), [repo](https://github.com/zeux/pugixml) |
| 🟡 | **quick-xml (Rust) `tests/documents`** | Sample documents with expected event output, including a UTF-16 BOM file (`sample_5_utf16bom.xml`); some came from xml-rs | small | ~2 h | Expected outputs need mapping to Expat events. [Tests folder](https://docs.rs/crate/quick-xml/0.20.0/source/tests/), [UTF-16 PR](https://github.com/tafia/quick-xml/pull/308.patch) |
| 🟡 | **W3C SVG 1.1 test suite, Second Edition** (2011-08-16, 445 tests) | Real-world SVG documents: namespaces, entities, CSS in XML | medium | ~2–3 h | Week 8 asks for SVG cases; only well-formedness and events are relevant to xpact, not rendering. The suite is no longer maintained. [Suite](https://www.w3.org/Graphics/SVG/Test/20110816), [overview](https://www.w3.org/Graphics/SVG/Test/Overview.html), [trimmed copy](https://github.com/ElinamLLC/SvgTestSuites) |
| ⚪ | **web-platform-tests `domparsing/DOMParser-parseFromString-xml.html`** | Browsers' check that `<foo/>` parses and `<foo>` gives an error, for four XML media types | tiny | ~30 min | Only a few cases; a cross-check of the basics. [Test](https://chromium.googlesource.com/external/w3c/web-platform-tests/+/refs/heads/master/domparsing/DOMParser-parseFromString-xml.html) |
| ⚪ | **Apache Xerces-C `samples/data`** | Sample XML files for Xerces' SAX/DOM samples | small | ~1 h | Not a conformance suite (the search found none for Xerces-C); some extra real-world shapes. [Samples doc](https://apache.googlesource.com/xerces-c/+/refs/tags/v3.0.0/doc/samples.xml) |

## 2. Malformed input and encodings

| | Source | What it tests | Size | Effort | Notes |
|---|---|---|---|---|---|
| ⭐ | **Markus Kuhn, "UTF-8 decoder capability and stress test"** (`UTF-8-test.txt`) | Boundary cases, malformed sequences, overlong encodings (including overlong `/`, a security check), impossible bytes `FE`/`FF` | ~20 KB | ~1–2 h | Wrap each line (or each section) in `<r>…</r>` and compare xpact's verdict, error code and position with Expat. It complements #39, #122 and #123. Most new UTF-8 decoders fail something in it. [Canonical file](https://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt), [HTML version](https://w3.org/2001/06/utf-8-wrong/UTF-8-test.html) |

## 3. Security

| | Source | What it tests | Effort | Notes |
|---|---|---|---|---|
| ⭐ | **RUB-NDS DTD-Attacks** (Ruhr University Bochum) | Payloads by class: file disclosure, SSRF, recursive expansion, billion laughs, parameter-entity chains, written for parsers in many languages | ~2–3 h | Feeds directly into the open F05/F07 security findings (the external billion laughs, F07-1). It has no runner; each payload needs an expected result (reject, or accept without loading anything external). [Overview](https://starlog.pages.dev/articles/developer-tools/rub-nds-dtd-attacks); check the repository itself before use |
| 🟡 | **Billion-laughs and quadratic-blowup variants** (cheat sheet) | Exponential nesting, and the quadratic version (one large entity repeated thousands of times) | ~1 h | xpact's entity limits should stop both; the quadratic one also tests speed. [Cheat sheet](https://gist.github.com/mgeeky/4f726d3b374f0a34267d4f19c9004870) |
| ⚪ | **defusedxml** (Python) | Describes the attack classes (bombs, external entities, DTD retrieval) and the safe defaults | ~1 h | Mostly a checklist; its test files are in [the repository](https://github.com/tiran/defusedxml). [README](https://sources.debian.org/src/defusedxml/0.7.1-3/README.md) |

## 4. Fuzzing

| | Source | What it tests | Effort | Notes |
|---|---|---|---|---|
| 🟡 | **Expat's fuzz harnesses** (`fuzz/xml_parse_fuzzer.c`, `xml_parsebuffer_fuzzer.c`) | Feed random input to `XML_Parse`/`XML_ParseBuffer`: each input once as non-final, then as final, per encoding | ~0.5–1 day | Since xpact has Expat's API, the same harness can link against `xpact.lib`. It needs clang/libFuzzer on Windows. [Harness](https://android.googlesource.com/platform/external/expat/+/refs/heads/android13-dev/fuzz/xml_parse_fuzzer.c) |
| 🟡 | **AFL++ `dictionaries/xml.dict`** | XML tokens that make a fuzzer build valid-looking documents faster | included above | Use it with libFuzzer `-dict=` or AFL++ `-x`. [Dictionaries](https://android.kernel.org/platform/external/AFLplusplus/+/HEAD/dictionaries) |
| ⚪ | **OSS-Fuzz corpora for expat and libxml2** | Large, coverage-guided seed sets | — | The search found no public download; access normally goes through the OSS-Fuzz project. `AlotOfTests` 03 already ran 571,839 local fuzz inputs (0 crashes). |

## 5. Large real-world files

All of these are ⛔ over 10 MB unless the limit is raised for the test, or a cut-down piece is used. Feed them whole, not in pieces, until F05-1 is fixed.

| | Source | What it tests | Size | Notes |
|---|---|---|---|---|
| ⭐ | **dblp** (`dblp.xml` + `dblp.dtd`) | **Entities at scale:** Latin-1 characters are named entities from the DTD, and the DTD is a local SYSTEM file | GB (gzipped dump) | A good test of entity handling and limits; dblp itself warns that parsers may need a higher entity limit. Monthly snapshots give reproducible versions. [Download FAQ](https://dblp.uni-trier.de/faq/1474679.html), [parsing FAQ](https://dblp.dagstuhl.de/faq/1474681.html) |
| ⭐ | **University of Washington XML Data Repository** | Research datasets with DTDs: SwissProt (109 MB), Treebank (82 MB, deep nesting), Mondial (~1 MB, DTD present but the data is not valid) | 1–109 MB | Mondial fits under 10 MB today. The datasets are old (1998–2002) but stable. [Repository](https://aiweb.cs.washington.edu/research/projects/xmltk/xmldata/www/repository.html) |
| 🟡 | **PubMed baseline** | Real bibliographic XML with a DTD | many files of ~100 MB+ | Already planned for week 9, "if the correctness checks permit". [Baseline](https://ftp.ncbi.nlm.nih.gov/pubmed/baseline/), [README](https://ftp.ncbi.nlm.nih.gov/pubmed/baseline/README.txt) |
| 🟡 | **XMark `xmlgen`** | A scalable synthetic auction document; scale factor 1 ≈ 100 MB, with an option to include the DTD; public domain | any size | Good for speed benchmarks at controlled sizes, including below 10 MB. [Generator](https://projects.cwi.nl/xmark/generator.html), [downloads](https://projects.cwi.nl/xmark/downloads.html) |
| 🟡 | **UniProt Swiss-Prot** (`uniprot_sprot.xml.gz`) | Large, namespaced scientific XML (schema `uniprot.xsd`) | ~891 MB gzipped | Bulk files use a different namespace URI from single-entry downloads. [DDBJ mirror](https://ddbj.nig.ac.jp/public/mirror_database/uniprot/knowledgebase/complete/README), [download center](https://ebi.ac.uk/uniprot/download-center) |
| ⚪ | **Shakespeare in XML** (Jon Bosak, version 2.00) | Small, clean, classic XML files (one play per file, with a DTD) | ~200 KB each | Good, small real-world inputs; free to redistribute unmodified. Some 1999 links may be dead. [ibiblio mirror](https://www.ibiblio.org/xml/examples/shakespeare/), [background](https://xml.coverpages.org/bosakShakespeare200.html) |
| ⚪ | **OpenStreetMap OSM XML** (Geofabrik regional extracts, `.osm.bz2`) | Very many small elements with many attributes | MB to GB per region | Pick a small region; Geofabrik recommends PBF but still offers XML. ODbL licence. [Download server](https://geofabrik.de/data/download.html), [extracts](https://wiki.openstreetmap.org/wiki/Extract) |
| ⚪ | **Wikipedia dumps** (`pages-articles`) | Huge real-world XML | ~19–25 GB compressed | Only useful once streaming is linear; a small language wiki or a slice would be enough. [Database download](https://www.wikipedia.org/wiki/Wikipedia:DD), [sizes](https://meta.wikimedia.org/wiki/Data_dumps/Dumps_sizes_and_growth) |

---

## ➡️ Suggested order

- [ ] **Markus Kuhn's UTF-8 stress test** (~1–2 h): direct value for the open UTF-8 and event findings
- [ ] **Expat's `xmltest.log.expected`** (~2 h): xpact against Expat's own record of the W3C suite
- [ ] **pugixml encoding files** (~1–2 h): BOM, UTF-16 and UTF-32 variants
- [ ] **RUB-NDS DTD-Attacks** (~2–3 h): security, together with F05/F07
- [ ] **UW Mondial and a cut-down dblp** (~2 h): real files with DTDs and many entities, under 10 MB
- [ ] **SVG 1.1** (~2–3 h): week 8's "SVG cases"
- [ ] **Expat's fuzz harness on `xpact.lib`** (~0.5–1 day)
- [ ] **XMark, PubMed, UniProt, OSM, Wikipedia**: after the 10 MB limit is handled and, for streaming, after F05-1

Each run follows the usual steps: an issue, one folder under `student/results/`, the inputs' source and hash, xpact next to Expat 2.8.1, and every difference filed as its own finding.

## ⚪ Out of scope (looked at, not useful for xpact)

- **W3C XML Schema test suite:** it tests schema validation, and xpact is a non-validating parser.
- **XSLT, XPath and XQuery suites** (for example XMark's queries, Xalan's conformance tests): they test the layers above a parser.
