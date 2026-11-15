# #197: test 2 with --jobs 16 vs --jobs 1

- DLL: `C:\xpact\xpact-student-Mass\website\backend\native\xpact.dll` SHA-256 `adae03d277752a2c996a83e3f0fefb57c9efd6747a6d2709cc5b5daa28a3e8a5`
- Runs: 3 rounds, alternating --jobs 1 and --jobs 16 ([timings.tsv](timings.tsv))
- **Same results:** ✅ yes, every TSV and summary is byte-identical (6 runs, 1 distinct output)
- **Median time:** --jobs 1 = 148.4 s · --jobs 16 = 27.5 s · **5.4× faster**
- Summary (all runs):

```json
{
  "ok": 2564,
  "xpact-only": 16,
  "both": 5,
  "total": 2585
}
```
