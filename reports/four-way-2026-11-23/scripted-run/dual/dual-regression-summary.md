# Dual regression lane: functional cases, whole and chunked

Expected results are written in `run_dual_regression.py`, independently of both parsers.

## Builds

| Build | Revision | Configuration | SHA-256 |
|---|---|---|---|
| xpact/assertions-on | `2862a1802b11` | finalized/assertions-on/msvc-x64 | `12223fbafdbf…` |
| xpact-core/assertions-on | `6c017fb5b6e0` | finalized/assertions-on/msvc-x64 | `c6e64a35189b…` |
| xpact/assertions-off | `2862a1802b11` | finalized/assertions-off/msvc-x64 | `11c740593971…` |
| xpact-core/assertions-off | `6c017fb5b6e0` | finalized/assertions-off/msvc-x64 | `b9cadbf7eba0…` |

## Results per build (every chunking)

| Build | Runs | PASS | WRONG-VERDICT | WRONG-EVENTS | CRASH | TIMEOUT | MISSING |
|---|---|---|---|---|---|---|---|
| xpact/assertions-on | 910 | 910 | 0 | 0 | 0 | 0 | 0 |
| xpact-core/assertions-on | 910 | 887 | 23 | 0 | 0 | 0 | 0 |
| xpact/assertions-off | 910 | 910 | 0 | 0 | 0 | 0 | 0 |
| xpact-core/assertions-off | 910 | 887 | 23 | 0 | 0 | 0 | 0 |

## Per group

| Build | Group | Runs | Not PASS |
|---|---|---|---|
| xpact/assertions-on | c02 | 85 | 0 |
| xpact/assertions-on | cr | 42 | 0 |
| xpact/assertions-on | basic | 140 | 0 |
| xpact/assertions-on | utf8 | 643 | 0 |
| xpact-core/assertions-on | c02 | 85 | 3 |
| xpact-core/assertions-on | cr | 42 | 9 |
| xpact-core/assertions-on | basic | 140 | 5 |
| xpact-core/assertions-on | utf8 | 643 | 6 |
| xpact/assertions-off | c02 | 85 | 0 |
| xpact/assertions-off | cr | 42 | 0 |
| xpact/assertions-off | basic | 140 | 0 |
| xpact/assertions-off | utf8 | 643 | 0 |
| xpact-core/assertions-off | c02 | 85 | 3 |
| xpact-core/assertions-off | cr | 42 | 9 |
| xpact-core/assertions-off | basic | 140 | 5 |
| xpact-core/assertions-off | utf8 | 643 | 6 |

## Lifecycle (one reused parser)

| Step | Expected | xpact/assertions-on | xpact-core/assertions-on | xpact/assertions-off | xpact-core/assertions-off |
|---|---|---|---|---|---|
| 1-valid | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| 2-mismatched | REJECT | REJECT | REJECT | REJECT | REJECT |
| 3-valid-after-failure | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| 4-incomplete | REJECT | REJECT | REJECT | REJECT | REJECT |
| 5-valid-after-incomplete | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| 6-partial-then-final | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| 7-bad-utf8 | REJECT | REJECT | REJECT | REJECT | REJECT |
| 8-valid-after-bad-utf8 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| 9-empty | REJECT | REJECT | REJECT | REJECT | REJECT |
| 10-valid-after-empty | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |

## Cases that are not PASS (first 60 distinct case/build/result)

| Build | Case | Runs | Result | Chunkings (first 4) | Observed events | Error |
|---|---|---|---|---|---|---|
| xpact-core/assertions-on | c02-valid | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 8 of 8: No element found |
| xpact-core/assertions-on | c02-valid-pair | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 14 of 14: No element found |
| xpact-core/assertions-on | c02-text | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 16 of 16: No element found |
| xpact-core/assertions-on | cr-crlf | 2 | WRONG-VERDICT | bytes, bytes-final | `-` | status 0, code 0, call 4 of 10:  |
| xpact-core/assertions-on | cr-lone | 2 | WRONG-VERDICT | bytes, bytes-final | `-` | status 0, code 0, call 4 of 9:  |
| xpact-core/assertions-on | cr-last-byte | 3 | WRONG-VERDICT | split@4, bytes, bytes-final | `start:r · end:r` | status 0, code 0, call 2 of 2:  |
| xpact-core/assertions-on | cr-attribute | 2 | WRONG-VERDICT | bytes, bytes-final | `-` | status 0, code 0, call 8 of 13:  |
| xpact-core/assertions-on | elem-nested | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 20 of 20: No element found |
| xpact-core/assertions-on | attr-two | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 17 of 17: No element found |
| xpact-core/assertions-on | text-entities | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 21 of 21: No element found |
| xpact-core/assertions-on | text-charrefs | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 19 of 19: No element found |
| xpact-core/assertions-on | text-whitespace | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 15 of 15: No element found |
| xpact-core/assertions-on | utf8-valid-e9-text | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 10 of 10: No element found |
| xpact-core/assertions-on | utf8-valid-e9-attribute | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 12 of 12: No element found |
| xpact-core/assertions-on | utf8-valid-e9-name | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 7 of 7: No element found |
| xpact-core/assertions-on | utf8-valid-e9-comment | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 17 of 17: No element found |
| xpact-core/assertions-on | utf8-valid-e9-pi | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 17 of 17: No element found |
| xpact-core/assertions-on | utf8-valid-e9-cdata | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 22 of 22: No element found |
| xpact-core/assertions-off | c02-valid | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 8 of 8: No element found |
| xpact-core/assertions-off | c02-valid-pair | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 14 of 14: No element found |
| xpact-core/assertions-off | c02-text | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 16 of 16: No element found |
| xpact-core/assertions-off | cr-crlf | 2 | WRONG-VERDICT | bytes, bytes-final | `-` | status 0, code 0, call 4 of 10:  |
| xpact-core/assertions-off | cr-lone | 2 | WRONG-VERDICT | bytes, bytes-final | `-` | status 0, code 0, call 4 of 9:  |
| xpact-core/assertions-off | cr-last-byte | 3 | WRONG-VERDICT | split@4, bytes, bytes-final | `start:r · end:r` | status 0, code 0, call 2 of 2:  |
| xpact-core/assertions-off | cr-attribute | 2 | WRONG-VERDICT | bytes, bytes-final | `-` | status 0, code 0, call 8 of 13:  |
| xpact-core/assertions-off | elem-nested | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 20 of 20: No element found |
| xpact-core/assertions-off | attr-two | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 17 of 17: No element found |
| xpact-core/assertions-off | text-entities | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 21 of 21: No element found |
| xpact-core/assertions-off | text-charrefs | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 19 of 19: No element found |
| xpact-core/assertions-off | text-whitespace | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 15 of 15: No element found |
| xpact-core/assertions-off | utf8-valid-e9-text | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 10 of 10: No element found |
| xpact-core/assertions-off | utf8-valid-e9-attribute | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 12 of 12: No element found |
| xpact-core/assertions-off | utf8-valid-e9-name | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 7 of 7: No element found |
| xpact-core/assertions-off | utf8-valid-e9-comment | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 17 of 17: No element found |
| xpact-core/assertions-off | utf8-valid-e9-pi | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 17 of 17: No element found |
| xpact-core/assertions-off | utf8-valid-e9-cdata | 1 | WRONG-VERDICT | bytes | `-` | status 0, code 3, call 22 of 22: No element found |
