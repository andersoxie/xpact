# Not-well-formed cases that expat accepts

60 cases, grouped by the first XML 1.0 section the W3C catalog gives.

| Section | Cases | Examples (catalog description) |
|---|---:|---|
| 3.4 | 32 | `not-wf-not-sa-001`: Conditional sections must be properly terminated ("]>" used instead of "]]>").; `not-wf-not-sa-003`: Conditional sections must be properly terminated ("]]>" omitted). |
| 2.8 | 6 | `not-wf-not-sa-009`: This test violates WFC:PE Between Declarations in Production 28a. The last character of a ; `o-p30fail1`: An XML declaration is not the same as a TextDecl |
| 4.3.2 | 5 | `not-wf-not-sa-007`: A <!DOCTYPE ...> declaration may not begin any external entity; it's only found once, in t; `ibm-not-wf-P78-ibm78n01.xml`: Tests extParsedEnt with wrong field ordering. The TextDecl occurs after the content in the |
| 4.3.1 | 5 | `not-wf-ext-sa-002`: External entities have "text declarations", which do not permit the "standalone=..." attri; `ibm-not-wf-P77-ibm77n01.xml`: Tests TextDecl with wrong field ordering. The VersionInfo occurs after the EncodingDecl in |
| ? | 5 | `cond01`: ; `cond02`:  |
| 2.6 | 2 | `not-wf-not-sa-002`: Processing instruction target names may not be "XML" in any combination of cases.; `not-wf-ext-sa-003`: Only one text declaration is permitted; a second one looks like an illegal processing inst |
| 4.1 | 2 | `not-wf-not-sa-008`: In DTDs, the '%' character must be part of a parameter entity reference.; `not-wf-ext-sa-001`: Tests the No Recursion WFC by having an external general entity be self-recursive. |
| 2.3 | 2 | `o-p09fail1`: EntityValue excludes '%'; `o-p09fail2`: EntityValue excludes '&' |
| 4.3.3 | 1 | `hst-lhs-007`: UTF-8 BOM plus xml decl of iso-8859-1 incompatible |
