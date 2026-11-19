# #304 trial: normal vs multi-threaded xpact.dll

- normal `native-eiffel/xpact.dll` SHA-256 `adae03d277752a2c…` · mt `native-eiffel-mt/xpact_mt.dll` `5f7f8f4f4cb3e539…`
- 32000 parses in total per cell, split over N threads; median of 3 alternating runs; a run counts only with 0 wrong results

| Test | Threads | Parses | normal (s) | mt (s) | mt speed-up | notes |
|---|---:|---:|---:|---:|---:|---|
| threads | 1 | 32000 | 0.86 | 1.50 | 0.58 |  |
| threads | 2 | 32000 | 1.21 | ❌ FAIL | - | exit 3221225477 |
| threads | 4 | 32000 | 1.25 | ❌ FAIL | - | exit 3221225477 |
| threads | 8 | 32000 | 1.29 | ❌ FAIL | - | exit 3221225477 |
| threads | 16 | 32000 | 1.32 | ❌ FAIL | - | exit 3221225477 |
| threads2 | 1 | 32000 | 2.10 | 3.51 | 0.60 |  |
| threads2 | 2 | 32000 | 2.98 | ❌ FAIL | - | exit 3221225477 |
| threads2 | 4 | 32000 | 3.16 | ❌ FAIL | - | exit 3221225477 |
| threads2 | 8 | 32000 | 3.28 | ❌ FAIL | - | exit 3221225477 |
| threads2 | 16 | 32000 | 3.34 | ❌ FAIL | - | exit 3221225477 |
