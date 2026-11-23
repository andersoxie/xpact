# Four-way W3C XML conformance

Suite: W3C xmlts 20130923, 2585 cases, profile and exclusions of dual-W3C run `20261123T082355Z-fa59144d573f` (same case list, same expected verdicts for every engine).

| Parser | Passed | Failed | Errors | Excluded | Pass rate | Accepts not-wf (too lenient) | Rejects valid/invalid (too strict) |
|---|---:|---:|---:|---:|---:|---:|---:|
| xpact (EiffelStudio, Windows) | 1974 | 0 | 0 | 611 | 100.0% | 0 | 0 |
| xpact (Gobo gec, Linux) | 1974 | 0 | 0 | 611 | 100.0% | 0 | 0 |
| expat 2.8.5 (Windows) | 1596 | 378 | 0 | 611 | 80.9% | 60 | 318 |
| expat 2.6.1 (Linux) | 1596 | 378 | 0 | 611 | 80.9% | 60 | 318 |
| xpact-core (pinned) | 1232 | 728 | 14 | 611 | 62.4% | 400 | 328 |

## Failures by test collection

| Collection | Cases run | xpact (EiffelStudio, Windows) | xpact (Gobo gec, Linux) | expat 2.8.5 (Windows) | expat 2.6.1 (Linux) | xpact-core (pinned) |
|---|---:|---:|---:|---:|---:|---:|
| invalid | 229 | 0 | 0 | 12 | 12 | 12 |
| not-wf | 1017 | 0 | 0 | 60 | 60 | 414 |
| valid | 728 | 0 | 0 | 306 | 306 | 316 |

## Agreement between parsers (cases run by all)

| | xpact (EiffelStudio, Windows) | xpact (Gobo gec, Linux) | expat 2.8.5 (Windows) | expat 2.6.1 (Linux) | xpact-core (pinned) |
|---|---:|---:|---:|---:|---:|
| xpact (EiffelStudio, Windows) | 100.0% | 100.0% | 80.9% | 80.9% | 62.4% |
| xpact (Gobo gec, Linux) | 100.0% | 100.0% | 80.9% | 80.9% | 62.4% |
| expat 2.8.5 (Windows) | 80.9% | 80.9% | 100.0% | 100.0% | 81.0% |
| expat 2.6.1 (Linux) | 80.9% | 80.9% | 100.0% | 100.0% | 81.0% |
| xpact-core (pinned) | 62.4% | 62.4% | 81.0% | 81.0% | 100.0% |

## Who fails which cases (top patterns)

| Failing parsers | Cases |
|---|---:|
| expat 2.8.5 (Windows), expat 2.6.1 (Linux), xpact-core (pinned) | 372 |
| xpact-core (pinned) | 370 |
| expat 2.8.5 (Windows), expat 2.6.1 (Linux) | 6 |
