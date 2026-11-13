# pugixml's encoding test files

> **Issue:** [CodTanium/mass-xpact#85](https://github.com/CodTanium/mass-xpact/issues/85) · item 3 of [`moreTests.md`](../../notes/moreTests.md) · **Date:** 2026-11-06
> **xpact:** final `student-Mass` (parser `45d2f53`) `xpact.dll` · **Expat:** 2.8.1 `libexpat.dll` · harness and 14 ways of feeding as in [shared fixtures](../shared-fixtures/README.md)

28 files of [pugixml v1.14 `tests/data`](https://github.com/zeux/pugixml/tree/v1.14/tests/data) (MIT, [licence](fixtures/LICENSE)): UTF-8, UTF-16 and UTF-32 in both byte orders, with and without BOM and declaration; Latin-1; truncation; empty.

| | Result |
|---|---|
| ✅ Same verdict as Expat | **28 / 28** |
| ✅ Identical | 14 |
| 🟡 Only the error position differs | 12 (andersoxie#171) |
| 🟡 Error code differs | 1, `____.xml`: xpact 4, Expat 2 (andersoxie#170 kind) |
| 🔴 Events differ | 1, `latintest_utf8.xml`: UTF-8 BOM + `encoding="ISO-8859-1"`; xpact decodes UTF-8, Expat ISO-8859-1 → [#83](https://github.com/CodTanium/mass-xpact/issues/83) |

The `utftest_*` rejections (code 21) are the same in both: the files refer to a DTD that is not in the folder. Results: [`runs/final-normal/`](runs/final-normal/results.tsv).
python -I student/results/shared-fixtures/compare.py --manifest student/results/pugixml-encodings-2026-11-06/manifest.tsv --tag final-normal --xpact-dll build/fix72/native-eiffel/xpact.dll --expat-dll build/libexpat-R_2_8_1/Release/libexpat.dll
