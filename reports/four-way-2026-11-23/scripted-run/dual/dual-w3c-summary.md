# Dual W3C: finalized, assertions discarded

Status: complete_with_failures

Profile: XML 1.0 fifth edition; namespaces unless NAMESPACE=no; nonvalidating; external-resource cases included; local suite root supplied to each engine; binary verdicts only

| Implementation | Cases | Passed | Failed | Errors | Excluded |
|---|---:|---:|---:|---:|---:|
| xpact | 2585 | 1974 | 0 | 0 | 611 |
| xpact-core | 2585 | 1232 | 728 | 14 | 611 |

## Directed audit controls

| Implementation | Assertions | Passed | Failed | Control process/protocol errors |
|---|---|---:|---:|---:|
| xpact | on | 5 | 0 | 0 |
| xpact-core | on | 2 | 3 | 0 |
| xpact | off | 5 | 0 | 0 |
| xpact-core | off | 2 | 3 | 0 |

Every profile exclusion has the same explicit reason for both engines.
No known-failure allowlist is applied. Agreement alone is not a pass.
Wrong verdicts remain failures; crashes, inconsistent protocol, launch errors and timeouts remain errors.
Per-case original output and exit codes are retained under work/; input hashes are in suite-manifest.json.
Elapsed times include a fresh process and raw file read, not parser-only throughput.
Assertions-on builds supply directed audit controls; the full catalog runs on assertions-off builds.
Core's internal GC policy is retained; incoming caller GC state is restored.
This profile does not cover external entities, canonical output, full event equality or native DLLs.
