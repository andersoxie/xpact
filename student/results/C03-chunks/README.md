# C03: final input across chunk boundaries, compared with Expat 2.8.1

> **Issue:** [#121](https://github.com/andersoxie/xpact/issues/121) · **Draft:** [14-C03](../../github/issues/14-C03.md) · **Date:** 2026-10-26
> · Full comparison: [`../expat-2.8.1/`](../expat-2.8.1/README.md)

## In short

| | |
|---|---|
| 🎯 Rule | Chunking must not change the answer: the same input gives the same verdict, error code and position whether it comes whole, split at any byte, or byte by byte |
| ✅ Expat 2.8.1 | holds for all **318** input/callback pairs |
| ✅ xpact verdict and code | hold for all 318 pairs; the same verdict as Expat in **4,308 / 4,308** cases |
| ❌ xpact position | moves for `<root/>junk` only: 1:7 to 1:10 depending on the split and on the callbacks ([#124](https://github.com/andersoxie/xpact/issues/124)) |
| ✅ Crash of #40 | gone: 0 crashes on the assertions DLL (fixed in #80) |

## Differences from Expat in the C02 and CR inputs

| Fixture | Bytes | Expat 2.8.1 | xpact | Issue |
|---|---|---|---|---|
| [`c02-trailing-junk.xml`](fixtures/c02-trailing-junk.xml) | `<root/>junk` | error 9 at 1:7 | error **4** at 1:7-1:10 | [#124](https://github.com/andersoxie/xpact/issues/124) |
| [`c02-mismatched.xml`](fixtures/c02-mismatched.xml) | `<root><child></root>` | default handler: `<root>`, `<child>` | also `</root>`, before the error | [#125](https://github.com/andersoxie/xpact/issues/125) |
| [`cr-crlf.xml`](fixtures/cr-crlf.xml), [`cr-lone.xml`](fixtures/cr-lone.xml), [`cr-last-byte.xml`](fixtures/cr-last-byte.xml), [`cr-attribute.xml`](fixtures/cr-attribute.xml) | CR, CR LF | default handler: the raw CR | LF (and an extra event for `<r/>\r`) | [#126](https://github.com/andersoxie/xpact/issues/126) |

The other C02 inputs (`<root/>`, `<root></root>`, `<root>hi</root>`, empty,
`<root>`) match Expat in verdict, code, position and events, in every split.

The fixtures are byte-exact (CR stays CR); [`fixtures/fixtures.tsv`](fixtures/fixtures.tsv)
lists bytes, callback set and both results. "Minimized": each is already the
smallest input of the C02 matrix that shows the difference.

## Done when (draft 14)

- [x] Each C02 case whole, split at every position and byte by byte (2026-10-22, #37; again 2026-10-26)
- [x] Status, error code and position compared with Expat 2.8.1
- [x] Differences saved as byte-exact fixtures here
