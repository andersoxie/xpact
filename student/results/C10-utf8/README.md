# C10 (part): malformed UTF-8, xpact vs Expat 2.8.1

> **Issue:** [#121](https://github.com/andersoxie/xpact/issues/121) · **Draft:** [15-C10](../../github/issues/15-C10.md) · **Date:** 2026-10-26
> · Full comparison: [`../expat-2.8.1/`](../expat-2.8.1/README.md)

## In short

| | |
|---|---|
| 🎯 Rule | Malformed UTF-8 must be rejected, in every place and at every split; valid UTF-8 (`é`) must be accepted |
| ✅ Verdict | xpact and Expat **agree in all 3,606 UTF-8 cases**: the 6 bad sequences are rejected everywhere, `é` accepted everywhere (on 2026-10-22 xpact accepted 2,106 bad ones, [#39](https://github.com/andersoxie/xpact/issues/39), fixed in #80) |
| ✅ Error code | 4 (invalid token) in both |
| ❌ Position | xpact says 1:0, Expat the bad byte ([#122](https://github.com/andersoxie/xpact/issues/122)) |
| ❌ Events | xpact gives none before the error, Expat does ([#123](https://github.com/andersoxie/xpact/issues/123)) |

## The fixtures

[`fixtures/`](fixtures/): 42 byte-exact files, 7 sequences × 6 places;
[`fixtures/fixtures.tsv`](fixtures/fixtures.tsv) gives each one's bytes and both results.

| Sequence | Bytes | Why it is bad |
|---|---|---|
| `bad-continuation` | `C3 28` | lead byte without its continuation byte |
| `overlong` | `C0 AF` | `/` written with two bytes |
| `surrogate` | `ED A0 80` | U+D800, a UTF-16 surrogate |
| `above-10ffff` | `F4 90 80 80` | above the last code point U+10FFFF |
| `lone-continuation` | `80` | continuation byte with no lead byte (new 2026-10-26) |
| `ff` | `FF` | never valid in UTF-8 (new 2026-10-26) |
| `valid-e9` (control) | `C3 A9` | valid `é`: must be accepted |

Places: text `<r>…</r>`, attribute `<r a='…'/>`, element name `<r…/>`,
comment, PI and CDATA. Each runs whole, split at every byte and byte by byte,
with all six callback sets.

| Place | Expat position (whole) | xpact position |
|---|---|---|
| text | 1:3 | 1:0 |
| attribute | 1:6 | 1:0 |
| name | 1:2 | 1:0 |
| comment | 1:7 | 1:0 |
| PI | 1:8 | 1:0 |
| CDATA | 1:12 | 1:0 |

## Done when (draft 15)

- [x] Byte-exact fixtures: `C3 28`, `80`, `C0 AF`, `ED A0 80`, `F4 90 80 80`, `FF`
- [x] For each fixture: xpact vs Expat verdict, whole and at every split
- [x] Results table here. Parser repairs (C08) stay with the experienced developers: #122 and #123 are reported, not fixed

Names and attributes are covered, so the "if time permits" part of C10 is done
for these sequences. Not covered: other encodings, and UTF-8 in DTDs.
