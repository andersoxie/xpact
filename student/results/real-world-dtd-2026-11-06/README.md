# Real-world files with a DTD: Mondial and a dblp slice

> **Issue:** [CodTanium/mass-xpact#85](https://github.com/CodTanium/mass-xpact/issues/85) · item 5 of [`moreTests.md`](../../notes/moreTests.md) · **Date:** 2026-11-06
> **xpact:** final `student-Mass` (parser `45d2f53`) `xpact.dll` · **Expat:** 2.8.1 `libexpat.dll` · harness and 14 ways of feeding as in [shared fixtures](../shared-fixtures/README.md)

| File | Size | Ways | Result |
|---|---:|---|---|
| [UW](https://aiweb.cs.washington.edu/research/projects/xmltk/xmldata/www/repository.html) `mondial-3.0.xml` | 1.7 MB | whole, 64, 1,024 bytes | ✅ identical to Expat |
| [dblp](https://dblp.org/xml/) slice with `dblp.dtd` (first 3 MB of `dblp.xml.gz`, cut at a record under 9 MB; 2,899+ records) | 8.9 MB | whole ✅ identical · 64 and 1,024 bytes: **xpact > 120 s timeout**, Expat ACCEPT | 🔴 [#84](https://github.com/CodTanium/mass-xpact/issues/84) |

**#84:** the dblp file declares `encoding="ISO-8859-1"`. In 1,024-byte pieces xpact's time grows with the square of the size (250 KB 3.2 s, 500 KB 11.6 s, 1 MB 45.7 s; Expat 0.04–0.22 s). The same pure-ASCII 250 KB declared UTF-8, or without a declaration: 0.10 s. So ISO-8859-1 input in pieces did not get the resume path that UTF-8 and UTF-16 have.

The large files are not committed (licences and size); [`manifest.tsv`](manifest.tsv) has their SHA-256. Mondial and the dblp files are downloaded with `curl` (dblp: `curl -r 0-2999999 https://dblp.org/xml/dblp.xml.gz`, then the cut in the #85 issue).
