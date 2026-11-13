# Expat's own W3C record (xmltest.sh) with xpact

> **Issue:** [CodTanium/mass-xpact#85](https://github.com/CodTanium/mass-xpact/issues/85) · item 2 of [`moreTests.md`](../../notes/moreTests.md) · **Date:** 2026-11-06
> **xpact:** final `student-Mass` (parser `45d2f53`) `xpact.dll` · **Expat:** 2.8.1 `libexpat.dll` · harness and 14 ways of feeding as in [shared fixtures](../shared-fixtures/README.md)

Expat's `tests/xmltest.sh` runs `xmlwf` over the W3C suite: well-formed cases must parse and give the canonical output in `out/`, not-well-formed cases must be rejected. `xmlwf` was built twice from Expat 2.8.1's source: with Expat, and against `xpact.lib` ([build](logs/tools/build-xmlwf.ps1), [script](logs/tools/xmltest.sh), only the paths changed).

| Run | Passed | Failed | Log |
|---|---:|---:|---|
| Expat's expected record (`xmltest.log.expected`) | 1,801 | 8 | [expected](logs/xmltest.log.expected-2.8.1) |
| `xmlwf` with Expat 2.8.1, here | 1,802 | 8 (the same 8 lines) | [log](logs/log-expat.txt) |
| `xmlwf` with xpact | 1,798 | 12 | [log](logs/log-xpact.txt) |

**Result: ✅ xpact gives Expat's own result on every case except 4**: `ibm/invalid/P68/ibm68i01.xml`–`ibm68i04.xml`, where `xmlwf` exits non-zero ([#82](https://github.com/CodTanium/mass-xpact/issues/82), pre-existing). Output is byte-identical to the canonical files wherever Expat's is. (1,802 against 1,801: this `xmlconf` copy has one more file.)
