# #209 recheck on `incremental-test` (2026-11-08)

**Question:** does the DLL still re-parse the whole document on every `XML_Parse` call (input in pieces slow, F05-1)?

| | |
|---|---|
| Code | andersoxie/xpact `incremental-test` @ `df75792` |
| DLL | `build/native-eiffel/xpact.dll` (SHA-256 `b3f661e2bf909a57…`), built with `website/scripts/build-dll.ps1` |
| Reference | Python 3.14.0 `pyexpat` (Expat 2.7.3) |
| Command | `python -I pieces209.py <path>\xpact.dll` |
| Input | `<r>` + `<e a="1">t</e>` × n + `</r>`, start-element handler set |

**Expected:** time grows linearly with the size, not with its square. **Before (F05-1):** 8 KB fed byte by byte took **58 s** (Expat 5 ms).

| Size | Piece | XPact | Expat 2.7.3 |
|---|---|---|---|
| 1 KB | 1 byte | 1.7 ms | 0.2 ms |
| 8 KB | 1 byte | **12.2 ms** | 1.1 ms |
| 64 KB | 1 byte | 99.1 ms | 9.6 ms |
| 64 KB | 64 bytes | 15.4 ms | 1.7 ms |
| 64 KB | 4 KB | 13.2 ms | 1.4 ms |

**Result:** ✅ linear (8× the size → 8× the time); 8 KB byte by byte 58 s → 12 ms. Same element count as Expat in every row ([raw](pieces209-incremental.jsonl)). XPact is still ~10× slower than Expat. ISO-8859-1 input in pieces is still quadratic: CodTanium/mass-xpact#84 (separate problem). Measured while other tests ran on the PC.
