# W3C SVG 1.1 test suite (Second Edition)

> **Issue:** [CodTanium/mass-xpact#85](https://github.com/CodTanium/mass-xpact/issues/85) · item 6 of [`moreTests.md`](../../notes/moreTests.md) · **Date:** 2026-11-06
> **xpact:** final `student-Mass` (parser `45d2f53`) `xpact.dll` · **Expat:** 2.8.1 `libexpat.dll` · harness and 14 ways of feeding as in [shared fixtures](../shared-fixtures/README.md)

The 525 test sources (`svg/*.svg`) of the [W3C SVG 1.1 Second Edition test suite](https://www.w3.org/Graphics/SVG/Test/20110816/) (`W3C_SVG_11_TestSuite.tar.gz`, 14.6 MB; W3C licence, so not committed; SHA-256 per file in [`manifest.tsv`](manifest.tsv)). Namespaces on. Only parsing is compared, not rendering.

| | Result |
|---|---|
| ✅ Same verdict as Expat | **525 / 525** |
| ✅ Identical in all 14 ways of feeding | **521** |
| 🟡 Only the error position differs | 4 (andersoxie#171) |
| ✅ The same verdict, code and events in every configuration pair | 7,350 / 7,350 |
