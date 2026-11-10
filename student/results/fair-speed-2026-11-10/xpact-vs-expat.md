# xpact vs Expat 2.8.1: summary of all results (2026-11-10)

Sources: this speed test ([README](README.md), [summary.md](summary.md)), [ActualReport.md](../../report/ActualReport.md), open issues on andersoxie/xpact.

## ✅ Same as Expat
| Check | Result |
|---|---|
| C API cases (C# DLL tests) | ✅ 4,308 / 4,308 same verdict |
| Input in pieces (G03) | ✅ 1,302 / 1,302 same verdict |
| W3C suite through the DLL | ✅ 2,585 cases, 0 failures, both builds |
| Speed-test events | ✅ 0 checksum mismatches in 102 cells |
| UTF-16 | ✅ same relative cost as UTF-8 |
| Drop-in | ✅ same `expat.h` C API |

## 🟢 Better than Expat
| Point | Detail |
|---|---|
| Language safety | Eiffel: managed memory, bounds checks |
| Contracts | assertions build checks the parser's own logic |
| Fuzzing | 3,879,031 inputs: 0 crashes, 0 hangs |

## 🟠 Close, not the same
| Point | Detail |
|---|---|
| Differential fuzzing | 99.94 % same verdict (3,148,557 documents) |
| Error codes and positions | differ in places ([#170](https://github.com/andersoxie/xpact/issues/170), [#171](https://github.com/andersoxie/xpact/issues/171)) |
| Expat's `runtests` | 399 checks, 38 known allocator-test failures |

## 🔴 Worse than Expat
| Point | xpact vs Expat |
|---|---|
| Whole document, callbacks on | 9–20× slower |
| Whole document, callbacks off | 2.3–16× slower |
| 1-byte pieces | 21–43× slower |
| All 200 cells | median 18.2× slower |
| `elements-10MB`, whole | 1,492 ms vs 89 ms |
| ISO-8859-1 in pieces ([#272](https://github.com/andersoxie/xpact/issues/272)) | 157× / 2,338× / 36,032× at 64 KB / 4 KB / 256 B; 16 B and 1 B time out (> 900 s) |
| Assertions build | another 9–22× slower than production |
| Threads ([#274](https://github.com/andersoxie/xpact/issues/274)) | not thread-safe |
| DLL crash ([#273](https://github.com/andersoxie/xpact/issues/273)) | no trace |
| Input size | 10 MiB limit |

## Why slower (earlier profile, [mass-xpact-issue-0014](../../../reports/mass-xpact-issue-0014/logs/profile-after.txt))
- ✔ measured: ~17 % `STRING_8.item` (per-character calls), ~10 % building strings per character, ~10 % allocation, ~8 % position tracking and UTF-8 checks.
- ❔ suspected (not profiled): callbacks convert strings to new C strings; small pieces re-check the kept input; ISO-8859-1 conversion redone per call (#272).
