# Markus Kuhn's UTF-8 decoder stress test

> **Issue:** [CodTanium/mass-xpact#85](https://github.com/CodTanium/mass-xpact/issues/85) · item 1 of [`moreTests.md`](../../notes/moreTests.md) · **Date:** 2026-11-06
> **xpact:** final `student-Mass` (parser `45d2f53`) `xpact.dll` · **Expat:** 2.8.1 `libexpat.dll` · harness and 14 ways of feeding as in [shared fixtures](../shared-fixtures/README.md)

**Result: ✅ 582 / 582 fixtures identical to Expat** (verdict, error code, events, position) in all 14 ways of feeding. Expat rejects 144 of them (malformed UTF-8, code 4) and xpact rejects the same 144 at the same position.

| Set | Fixtures | Identical | Expat accepts / rejects |
|---|---:|---:|---|
| each line as element text, `<r>LINE</r>` | 291 | 291 | 219 / 72 |
| each line as attribute value, `<r a="LINE"/>` | 291 | 291 | 219 / 72 |

Source: [UTF-8-test.txt](https://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt) (SHA-256 `b51cfe9a…`, checked by [`make_fixtures.py`](make_fixtures.py)); fixtures in [`fixtures/`](fixtures/), results in [`runs/final-normal/`](runs/final-normal/results.tsv).

```bash
curl -o build/downloads/kuhn/UTF-8-test.txt https://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt
python -I student/results/kuhn-utf8-2026-11-06/make_fixtures.py build/downloads/kuhn/UTF-8-test.txt
python -I student/results/shared-fixtures/compare.py --manifest student/results/kuhn-utf8-2026-11-06/manifest.tsv --tag final-normal --xpact-dll build/fix72/native-eiffel/xpact.dll --expat-dll build/libexpat-R_2_8_1/Release/libexpat.dll
