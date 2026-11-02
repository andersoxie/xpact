# Dual regression lane: functional cases, whole and chunked

Expected results are written in `run_dual_regression.py`, independently of both parsers.

## Builds

| Build | Revision | Configuration | SHA-256 |
|---|---|---|---|
| xpact/assertions-on | `7028e687357e` | finalized/assertions-on/msvc-x64 | `a5736abede14…` |
| xpact/assertions-off | `7028e687357e` | finalized/assertions-off/msvc-x64 | `56f26de89c1d…` |
| xpact-core/assertions-on | build failed | Pinned Xpact-core is not cached at C:\Users\masou\Desktop\Lia\xpact\w10-attr-defaults\build\dependencies\xpact-core\6c017fb5b6e04fd0ae401bc54bb3c6a3c3bd6676; run without --offline once | |
| xpact-core/assertions-off | build failed | Pinned Xpact-core is not cached at C:\Users\masou\Desktop\Lia\xpact\w10-attr-defaults\build\dependencies\xpact-core\6c017fb5b6e04fd0ae401bc54bb3c6a3c3bd6676; run without --offline once | |

## Results per build (every chunking)

| Build | Runs | PASS | WRONG-VERDICT | WRONG-EVENTS | CRASH | TIMEOUT | MISSING |
|---|---|---|---|---|---|---|---|
| xpact/assertions-on | 910 | 910 | 0 | 0 | 0 | 0 | 0 |
| xpact/assertions-off | 910 | 910 | 0 | 0 | 0 | 0 | 0 |

## Per group

| Build | Group | Runs | Not PASS |
|---|---|---|---|
| xpact/assertions-on | c02 | 85 | 0 |
| xpact/assertions-on | cr | 42 | 0 |
| xpact/assertions-on | basic | 140 | 0 |
| xpact/assertions-on | utf8 | 643 | 0 |
| xpact/assertions-off | c02 | 85 | 0 |
| xpact/assertions-off | cr | 42 | 0 |
| xpact/assertions-off | basic | 140 | 0 |
| xpact/assertions-off | utf8 | 643 | 0 |

## Lifecycle (one reused parser)

| Step | Expected | xpact/assertions-on | xpact/assertions-off |
|---|---|---|---|
| 1-valid | ACCEPT | ACCEPT | ACCEPT |
| 2-mismatched | REJECT | REJECT | REJECT |
| 3-valid-after-failure | ACCEPT | ACCEPT | ACCEPT |
| 4-incomplete | REJECT | REJECT | REJECT |
| 5-valid-after-incomplete | ACCEPT | ACCEPT | ACCEPT |
| 6-partial-then-final | ACCEPT | ACCEPT | ACCEPT |
| 7-bad-utf8 | REJECT | REJECT | REJECT |
| 8-valid-after-bad-utf8 | ACCEPT | ACCEPT | ACCEPT |
| 9-empty | REJECT | REJECT | REJECT |
| 10-valid-after-empty | ACCEPT | ACCEPT | ACCEPT |

## Cases that are not PASS (first 60 distinct case/build/result)

| Build | Case | Runs | Result | Chunkings (first 4) | Observed events | Error |
|---|---|---|---|---|---|---|
