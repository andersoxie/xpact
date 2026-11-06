# RUB-NDS DTD-Attacks payloads

> **Issue:** [CodTanium/mass-xpact#85](https://github.com/CodTanium/mass-xpact/issues/85) · item 4 of [`moreTests.md`](../../notes/moreTests.md) · **Date:** 2026-11-06
> **xpact:** final `student-Mass` (parser `45d2f53`) `xpact.dll` · **Expat:** 2.8.1 `libexpat.dll` · harness and 14 ways of feeding as in [shared fixtures](../shared-fixtures/README.md)

104 payloads of [RUB-NDS/DTD-Attacks](https://github.com/RUB-NDS/DTD-Attacks) @ `6f703e9`, `code/xml_files_unix/` (billion laughs, quadratic blowup, parameter-entity chains, external entities, SSRF, file disclosure). The repository has **no licence**, so the files are not committed; [`manifest.tsv`](manifest.tsv) has every path and SHA-256. External entities are loaded only from each payload's own folder: nothing is fetched from the network or read outside it.

| | Result |
|---|---|
| ✅ Same verdict as Expat | **104 / 104**, no crash, no hang |
| ✅ Identical | 81 |
| 🟡 Error code differs | 12: xpact 2 (syntax error) where Expat names the problem: 10 (PE reference in internal subset) ×6, 4 ×4, 16 (external entity in an attribute) ×2 → andersoxie#170 |
| 🟡 Only the position differs | 6 (andersoxie#171) |
| 🟡 Events before the same error | 5 (`dos_3gb`: code 43 both; 4 parameter-entity payloads: code 21 both) |

```bash
git clone --depth 1 https://github.com/RUB-NDS/DTD-Attacks build/downloads/rub   # 6f703e9
python -I student/results/shared-fixtures/compare.py --manifest student/results/rub-nds-dtd-attacks-2026-11-06/manifest.tsv --tag final-normal --xpact-dll build/fix72/native-eiffel/xpact.dll --expat-dll build/libexpat-R_2_8_1/Release/libexpat.dll
```
