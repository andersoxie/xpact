# W3C XML conformance

Source: https://www.w3.org/XML/Test/xmlts20130923.zip

Profile: XML 1.0 fifth edition; namespaces unless NAMESPACE=no; nonvalidating; external-resource cases included; local suite root supplied to each engine; binary verdicts only

| Engine | Cases | Passed (verdict checked) | No crash only | Failed | Errors | Skipped | Known | Unexpected | Elapsed ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| gobo-nouf | 2585 | 1870 | 302 | 413 | 0 | 0 | 0 | 413 | 123116.454 |

## Lanes (--all-cases)

| Engine | Lane | Judged by | Cases | Passed | Failed | Errors | Skipped | Accepted | Rejected |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| gobo-nouf | core | verdict | 1974 | 1863 | 111 | 0 | 0 | 1039 | 935 |
| gobo-nouf | legacy-names | verdict | 309 | 7 | 302 | 0 | 0 | 302 | 7 |
| gobo-nouf | optional-error | no crash only | 28 | 28 | 0 | 0 | 0 | 11 | 17 |
| gobo-nouf | xml-1.1 | no crash only | 274 | 274 | 0 | 0 | 0 | 21 | 253 |

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
