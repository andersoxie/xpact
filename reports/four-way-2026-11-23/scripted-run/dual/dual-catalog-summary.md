# Dual catalog: finalized, assertions discarded

Status: complete; both assertion configurations passed the scoped correctness gate.

Workload: catalog-100-items, 2611 bytes, 32000 documents per sample.

| Implementation | Revision | GC policy | Median ms | Median MiB/s |
|---|---|---|---:|---:|
| xpact | `2862a1802b11fecc413bb8a1ea497f5defbb0f49` | normal | 3044.272 | 26.174 |
| xpact-core | `6c017fb5b6e04fd0ae401bc54bb3c6a3c3bd6676` | core-managed-off-full-collect | 1490.012 | 53.477 |

Median xpact time / core time: 2.0475; pair range 1.9828–2.0700.

Ratios above 1 favor core. This is an end-to-end implementation comparison:
core disables GC internally and performs a full collection on final input; that cost is timed.
The caller requests no additional GC suspension for either implementation.
Parser reset/reuse and process startup are timed; compilation and qualification are excluded.
Both use no-op handlers during timing. Observing-handler checks run before measurements.

Raw alternating AB/BA pairs, calibration, executable hashes and all build manifests are retained.
This gate covers the catalog and directed reuse/recovery checks, not general XML conformance.
