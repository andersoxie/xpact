# W3C XML conformance

Source: https://www.w3.org/XML/Test/xmlts20130923.zip

Profile: XML 1.0 fifth edition; namespaces unless NAMESPACE=no; nonvalidating; external-resource cases included; local suite root supplied to each engine; binary verdicts only

| Engine | Cases | Passed | Failed | Errors | Skipped | Known | Unexpected | Elapsed ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| EsFinalized | 2585 | 1974 | 0 | 0 | 611 | 0 | 0 | 237951.563 |
| EsAssertions | 2585 | 1974 | 0 | 0 | 611 | 0 | 0 | 236383.698 |
| GoboFinalized | 2585 | 1974 | 0 | 0 | 611 | 0 | 0 | 246899.146 |
| GoboAssertions | 2585 | 1974 | 0 | 0 | 611 | 0 | 0 | 262678.562 |

Catalog expectations adjusted to the selected XML edition:
- rmt-e2e-38: catalog REJECT; profile ACCEPT. XML 1.0 fifth edition permits this 1.1 text declaration without non-1.0 features; fourth-edition erratum E10 reverses second-edition E38: https://www.w3.org/XML/xml-V10-4e-errata#E10

Known counts failures and errors listed in the known-failures file; they are still parser gaps.
Unexpected counts every other failure or error; any unexpected result fails the run.
Elapsed time includes a fresh process and file read per executed case; it is not parser-only throughput.
Skipped cases are excluded from conformance results. Canonical output comparisons are not implemented.
