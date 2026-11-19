# W3C XML conformance

Source: https://www.w3.org/XML/Test/xmlts20130923.zip

Profile: XML 1.0 fifth edition; namespaces unless NAMESPACE=no; nonvalidating; external-resource cases included; local suite root supplied to each engine; binary verdicts only

| Engine | Cases | Passed (verdict checked) | No crash only | Failed | Errors | Skipped | Known | Unexpected | Elapsed ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| xpact | 2585 | 2283 | 302 | 0 | 0 | 0 | 0 | 0 | 125373.573 |
| gobo | 2585 | 1919 | 302 | 364 | 0 | 0 | 0 | 364 | 127228.992 |

## Lanes (--all-cases)

| Engine | Lane | Judged by | Cases | Passed | Failed | Errors | Skipped | Accepted | Rejected |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| xpact | core | verdict | 1974 | 1974 | 0 | 0 | 0 | 958 | 1016 |
| xpact | legacy-names | verdict | 309 | 309 | 0 | 0 | 0 | 0 | 309 |
| xpact | optional-error | no crash only | 28 | 28 | 0 | 0 | 0 | 14 | 14 |
| xpact | xml-1.1 | no crash only | 274 | 274 | 0 | 0 | 0 | 137 | 137 |
| gobo | core | verdict | 1974 | 1910 | 64 | 0 | 0 | 958 | 1016 |
| gobo | legacy-names | verdict | 309 | 9 | 300 | 0 | 0 | 300 | 9 |
| gobo | optional-error | no crash only | 28 | 28 | 0 | 0 | 0 | 8 | 20 |
| gobo | xml-1.1 | no crash only | 274 | 274 | 0 | 0 | 0 | 16 | 258 |

- `core`: the profile above
- `legacy-names`: XML 1.0 editions 1-4: fourth-edition name tables (--legacy-names, as the native DLL parser uses); W3C verdict
- `optional-error`: TYPE=error: the specification allows either verdict; only a crash, timeout or missing verdict fails
- `xml-1.1`: XML 1.1 / Namespaces 1.1: no XML 1.0 verdict exists; only a crash, timeout or missing verdict fails

Catalog expectations adjusted to the selected XML edition:
- rmt-e2e-38: catalog REJECT; profile ACCEPT. XML 1.0 fifth edition permits this 1.1 text declaration without non-1.0 features; fourth-edition erratum E10 reverses second-edition E38: https://www.w3.org/XML/xml-V10-4e-errata#E10

Known counts failures and errors listed in the known-failures file; they are still parser gaps.
Unexpected counts every other failure or error; any unexpected result fails the run.
Elapsed time includes a fresh process and file read per executed case; it is not parser-only throughput.
Skipped cases are excluded from conformance results. Canonical output comparisons are not implemented.
