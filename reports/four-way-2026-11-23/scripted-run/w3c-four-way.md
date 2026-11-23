# Four-way W3C XML conformance

Suite: W3C xmlts 20130923, 2585 cases, profile and exclusions of dual-W3C run `20261123T092605Z-235920f340c6` (same case list, same expected verdicts for every engine).

| Parser | Passed | Failed | Errors | Excluded | Pass rate | Accepts not-wf (too lenient) | Rejects valid/invalid (too strict) |
|---|---:|---:|---:|---:|---:|---:|---:|
| xpact (EiffelStudio, Windows) | 1974 | 0 | 0 | 611 | 100.0% | 0 | 0 |
| xpact (Gobo gec, Linux) | 1974 | 0 | 0 | 611 | 100.0% | 0 | 0 |
| expat 2.8.5 (Windows) | 1655 | 319 | 0 | 611 | 83.8% | 1 | 318 |
| expat 2.6.1 (Linux) | 1655 | 319 | 0 | 611 | 83.8% | 1 | 318 |
| xpact-core (pinned) | 1232 | 728 | 14 | 611 | 62.4% | 400 | 328 |

## Failures by test collection

| Collection | Cases run | xpact (EiffelStudio, Windows) | xpact (Gobo gec, Linux) | expat 2.8.5 (Windows) | expat 2.6.1 (Linux) | xpact-core (pinned) |
|---|---:|---:|---:|---:|---:|---:|
| invalid | 229 | 0 | 0 | 12 | 12 | 12 |
| not-wf | 1017 | 0 | 0 | 1 | 1 | 414 |
| valid | 728 | 0 | 0 | 306 | 306 | 316 |

## Agreement between parsers (cases run by all)

| | xpact (EiffelStudio, Windows) | xpact (Gobo gec, Linux) | expat 2.8.5 (Windows) | expat 2.6.1 (Linux) | xpact-core (pinned) |
|---|---:|---:|---:|---:|---:|
| xpact (EiffelStudio, Windows) | 100.0% | 100.0% | 83.8% | 83.8% | 62.4% |
| xpact (Gobo gec, Linux) | 100.0% | 100.0% | 83.8% | 83.8% | 62.4% |
| expat 2.8.5 (Windows) | 83.8% | 83.8% | 100.0% | 100.0% | 78.0% |
| expat 2.6.1 (Linux) | 83.8% | 83.8% | 100.0% | 100.0% | 78.0% |
| xpact-core (pinned) | 62.4% | 62.4% | 78.0% | 78.0% | 100.0% |

## Who fails which cases (top patterns)

| Failing parsers | Cases |
|---|---:|
| xpact-core (pinned) | 429 |
| expat 2.8.5 (Windows), expat 2.6.1 (Linux), xpact-core (pinned) | 313 |
| expat 2.8.5 (Windows), expat 2.6.1 (Linux) | 6 |
