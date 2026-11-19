# XML collections for xpact verification

Research date: 27 September 2026; implementation status reviewed 13 November 2026. This note supplements the ten-week student assignment, especially tasks G01 (portable corpus) and G03 (cross-engine comparison). Collection counts and external-source research retain their September date.

**Recommendation:** use the W3C XML conformance suite as the main correctness collection, Xpact-core's fixtures for targeted regressions, SVG and selected libxml2 inputs for variety, and PubMed for large-file streaming tests. Keep assertions enabled in xpact and Xpact-core builds used for verification.

The repository now has [pinned dual builds](implementation-builds.md),
[catalog](dual-catalog-lane.md), [W3C](dual-w3c-lane.md) and
[chunked regression](dual-regression-lane.md) comparisons with Xpact-core.
Their primary catalog/W3C campaigns use assertions off, with separate
assertion-enabled directed controls; this differs from the student verification
recommendation above. The [all-cases W3C extension](w3c-xml-conformance.md#all-cases---all-cases)
also runs the 611 profile exclusions, with 302 explicitly scored only for a
non-crashing verdict. Native core DLL integration and canonical-output parity
are not established by these direct Eiffel lanes.

## What Xpact-core actually provides

Inspected commit: [`9fe21cc66897a9a5b2160ab4344802bdecc2898c`](https://github.com/andersoxie/Xpact-core/tree/9fe21cc66897a9a5b2160ab4344802bdecc2898c).

| Location | Files | Total bytes |
| --- | ---: | ---: |
| `tools/data` | 42 | 3,819,030 |
| `tools/data-large` | 2 | 3,105,421 |
| Combined | **44** | **6,924,451** |

These are 44 distinct file hashes: 23 XML, 11 HTML, four XSL, three SVG, one Atom, one DTD and one Eant file. They include malformed documents and entity-expansion cases; they are not all valid standalone XML documents. A DTD is a dependency, not a standalone document test.

The [upstream testing report](https://github.com/andersoxie/Xpact-core/blob/9fe21cc66897a9a5b2160ab4344802bdecc2898c/docs/Testing-report.txt) records **152,335 passed comparisons**. The [corpus configuration](https://github.com/andersoxie/Xpact-core/blob/9fe21cc66897a9a5b2160ab4344802bdecc2898c/corpus-data/test-corpus-all.xml) points to the author's Linux installation, Steam files, Eiffel installation, mounted Windows installation and personal document directories. These files are not included in the repository.

That historical result is useful evidence of broad testing, but it is not a portable collection of 152,335 unique valid XML documents. Matching parser rejections also count as successful comparisons. Archive members introduce another counting level, and the report has no per-input hashes for deduplication. Its displayed rows sum to 148,901; the difference from the footer may reflect archive accounting, but the original run cannot be reconstructed from the checked-in files alone.

The runner is most directly reusable under Linux/WSL: it depends on the Eiffel `xml_reader`, an Expat comparison executable, `find` and `unzip`. Its existing CRC checks do not replace native API tests or comparisons across chunk boundaries.

## Recommended public collections

| Collection | Verified scale | Main purpose | Priority |
| --- | --- | --- | --- |
| [W3C XML conformance suite](https://www.w3.org/XML/Test/) | **2,585 active catalog cases**; downloaded archive contains **3,078 `.xml` files** | Expected acceptance/rejection, encodings, entities, namespaces and XML syntax | First |
| [Xpact-core fixtures](https://github.com/andersoxie/Xpact-core/tree/9fe21cc66897a9a5b2160ab4344802bdecc2898c/tools/data) | **44 assets** including `tools/data-large` | Small, relevant regressions and comparison with upstream | First |
| [W3C SVG 1.1 suite](https://www.w3.org/Graphics/SVG/Test/20110816/) | Approved index lists **433 test entries**, including a compressed SVG case | More realistic namespaces, attributes, nested elements and text | Second |
| [libxml2 regression inputs](https://github.com/GNOME/libxml2/tree/master/test) | Exact eligible input count not measured | Additional parser regressions and malformed inputs | Second |
| [PubMed 2026 baseline](https://ftp.ncbi.nlm.nih.gov/pubmed/baseline/) | **1,334 compressed XML files**, confirmed in its README | Large-file streaming, throughput and memory behavior | Selected files first |
| [DBLP XML snapshots](https://dblp.org/xml/release/) | One large XML dataset per snapshot; live compressed download listed at approximately **1 GB** when checked | Optional sustained streaming and memory stress | Later |

W3C SVG's 433 entries are rendering tests, not 433 independent XML-conformance verdicts. Use its documents as input diversity. The [archive is available here](https://www.w3.org/Graphics/SVG/Test/20110816/archives/W3C_SVG_11_TestSuite.tar.gz).

For libxml2, start with parser-related inputs selected using its [runner's test definitions](https://github.com/GNOME/libxml2/blob/master/runtest.c). The repository also contains HTML, schemas, XPath and expected-output files, and some parser input filenames have no extension. Preserve parser options when interpreting results; libxml2 recovery-mode output is not an acceptance requirement for xpact. Pin a commit before importing cases.

The [PubMed README](https://ftp.ncbi.nlm.nih.gov/pubmed/baseline/README.txt) identifies files `pubmed26n0001` through `pubmed26n1334` and provides integrity-check instructions. Use a small fixed subset initially. These documents exercise scale more than grammatical diversity; they cannot replace negative conformance tests.

Existing local large-file inputs are already available:

| File under `build/large-xml-corpus` | Uncompressed bytes |
| --- | ---: |
| `pubmed26n0001.xml` | 195,452,577 |
| `pubmed26n1380.xml` | 10,236,490 |
| `pubmed26n1380-first-records-512k.xml` | 504,561 |

The last file is a derived sample; record its parent and extraction method in the eventual corpus manifest. These sizes were inspected, not revalidated as parser results in this research task.

## W3C collection prepared locally

Downloaded [the 20130923 ZIP](https://www.w3.org/XML/Test/xmlts20130923.zip) and extracted it without changing file contents or directory structure:

- Archive: `build/comparison/xmlts20130923.zip`.
- Extracted root: `build/validation-corpora/w3c-xml-20130923/xmlconf/`.
- File inventory with sizes and SHA-256 hashes: `build/validation-corpora/w3c-xml-20130923/inventory.json`.
- Archive size: **1,574,648 bytes**; extracted payload: **2,722,978 bytes**.
- Archive contents: **3,386 files**, including **3,078 `.xml` files**, 149 DTD files and 141 `.ent` files. Other extensions also contain dependencies.
- Archive SHA-256: `f9510b3532926e1b4c2e54855b021e4b8a66ec98a5337dcf4ff07e8a41968deb`.

The `.xml` count includes catalog and expected-output files. **Do not count every file as a test or assume every input should be accepted.** Use `xmlconf.xml` and its included catalogs to identify test cases. The download and inventory are under ignored `build/`. The suite is now integrated into `scripts/run_benchmarks.ps1` and both Jenkins benchmark pipelines through `scripts/run_w3c_conformance.py`; see [W3C conformance benchmarks](w3c-xml-conformance.md) for execution, reports, and offline setup. The automatic runner caches its verified ZIP at `build/validation-corpora/w3c-xml-20130923/xmlts20130923.zip`, independently of the earlier research download above.

Catalog inspection found **2,585 active cases**: 812 `valid`, 242 `invalid`, 1,498 `not-wf` and 33 `error`. These are counts before filtering for supported configurations. One commented-out case was excluded. The implemented importer accommodates the root catalog's misencoded comment in memory with an ISO-8859-1 override, while child catalogs retain their declared encodings. It also corrects the root catalog's `eduni/namespaces/misc/` base to `eduni/misc/` in memory. Both accommodations require the exact known root catalog hash; original files remain unchanged.

The [W3C test matrix](https://www.w3.org/XML/Test/xmlconf-20130923.html) distinguishes these outcomes:

| Catalog type | Meaning for a nonvalidating parser such as Expat |
| --- | --- |
| `valid` | Accept applicable supported cases. |
| `invalid` | Well-formed but violates DTD validity constraints; normally accept. |
| `not-wf` | Reject, subject to the documented external-entity processing rules. |
| `error` | Optional error detection; there is no universal accept/reject requirement. |

The standard core profile selects XML 1.0 fifth-edition binary tests, with namespaces enabled unless `NAMESPACE="no"`, using a nonvalidating parser and a suite-local external-resource loader. It selects **1,974 cases per build** and, without the all-cases extension, reports the remaining **611 cases as skipped** with reasons. External general/parameter entities and DTD subsets use their declaring file's base; no network resources are fetched. The hash-qualified E38 fifth-edition correction retains the original catalog expectation beside the profile expectation. XML 1.1, other editions and optional-error cases remain outside this profile. Missing, denied or unreadable parsed resources are harness errors, never successful XML rejections. Per-case parser results and strict failure status are recorded separately from skipped cases. See [the W3C profile and verification](w3c-xml-conformance.md).

This standard lane does not compare canonical output. A separate October DLL
study checks the 432 cases with expected-output files; its repairs and recorded
results are indexed in [the reports overview](../reports/README.md), starting
with [issue #154](../reports/issue-0154/report.md). Those output checks are
distinct from binary verdict and no-crash scoring.

## Student work and completion criteria

| Difficulty | Task | Evidence of completion |
| --- | --- | --- |
| D1 — beginner | Inventory the prepared W3C collection and 44 core fixtures; record source, version, path, size and hash. | Reproducible manifest and clear distinction between input, dependency and expected output. |
| D2 — guided | Start with 50–100 applicable W3C cases, then expand to the applicable full catalog. | Expected results mapped from metadata; accepted, rejected, skipped and failed totals reconcile. |
| D2 — guided | Compare xpact and Expat across whole-buffer and selected chunk sizes through both parse APIs. | Build and assertion settings recorded; each required engine actually ran; differences have saved traces. |
| D2 — guided | Add SVG and selected libxml2 parser inputs. | Pinned sources, declared parser modes and a reviewed expectation for each case. |
| D3 — advanced | Measure the existing PubMed files with practical chunk sizes. | Repeatable elapsed-time and peak-memory results; timeouts and incomplete parses are failures. |
| D3 — optional | Extend the existing Xpact-core lanes to the selected shared corpus and required API boundary. | Comparable outcomes and event traces for all three engines; keep direct Eiffel and native DLL evidence distinct. |

Use small inputs for one-byte chunk tests and larger chunks for large documents. Preserve event order and text content; callback segmentation can legitimately vary with chunk size. Keep accepted, rejected, crashed, timed-out, unsupported and not-run counts separate. A checksum agreement is supporting evidence, not proof of full compatibility.

Keep original source notices with imported assets. Xpact-core's `DTD-attlist-default-values.xml` contains a GPLv2+ notice, so the code repository's MIT label does not describe every fixture. PubMed's README provides its data terms, and DBLP publishes its metadata under [CC0](https://dblp.org/xml/README.txt). A manifest plus reproducible downloads is preferable to adding large datasets to this repository.
