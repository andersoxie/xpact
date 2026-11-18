
### W3C verdicts, harness lane (1,974 core cases)

| Engine | Core pass | Core fail | Same verdict as Expat | Crash/timeout/exception |
|---|---|---|---|---|
| xpact | 1654 | 320 | 1973 | 0 |
| gobo | 1910 | 64 | 1627 | 0 |

### Where xpact and Gobo disagree (core)

| Case group | Cases |
|---|---|
| valid expected ACCEPT: xpact REJECT, Gobo ACCEPT, Expat REJECT | 301 |
| not-wf expected REJECT: xpact REJECT, Gobo ACCEPT, Expat REJECT | 31 |
| valid expected ACCEPT: xpact ACCEPT, Gobo REJECT, Expat ACCEPT | 11 |
| invalid expected ACCEPT: xpact ACCEPT, Gobo REJECT, Expat ACCEPT | 3 |
| not-wf expected ACCEPT: xpact ACCEPT, Gobo REJECT, Expat ACCEPT | 1 |
| not-wf expected REJECT: xpact ACCEPT, Gobo REJECT, Expat REJECT | 1 |

### W3C output (canonical XML, 432 cases)

| Engine | Exact | Engine only wrong | Both wrong | Total |
|---|---|---|---|---|
| xpact | 375 | 4 | 53 | 432 |
| gobo | 319 | 60 | 53 | 432 |

### Encodings (146 cases; expected = Expat, or the XML spec where explicit)

| Engine | Right | Wrong | Not supported (encoding override API) | Total |
|---|---|---|---|---|
| xpact | 144 | 2 | 0 | 146 |
| gobo | 142 | 1 | 3 | 146 |

Gobo wrong, xpact right (1): utf16le-decl-utf16le


xpact wrong, Gobo right (2): bom-utf8-decl-utf16, create-utf8-overrides-latin1


### libxml2 corpus (Expat = reference)

| Engine | Files | Same verdict | Same verdict + events | Timeout | Crash | Exception |
|---|---|---|---|---|---|---|
| xpact | 1417 | 1412 | 1295 | 2 | 0 | 0 |
| gobo | 1417 | 1398 | 1055 | 3 | 0 | 1 |

### Project W3C runner, strict Gobo (Unicode filter on)

| Engine | core pass/fail | legacy-names pass/fail | optional-error pass/fail | xml-1.1 pass/fail |
|---|---|---|---|---|
| xpact | 1974/0 | 309/0 | 28/0 | 274/0 |
| gobo | 1910/64 | 9/300 | 28/0 | 274/0 |

### Project W3C runner, Gobo without Unicode filter

| Engine | core pass/fail | legacy-names pass/fail | optional-error pass/fail | xml-1.1 pass/fail |
|---|---|---|---|---|
| gobo-nouf | 1863/111 | 7/302 | 28/0 | 274/0 |

### Fuzzing (mutated W3C documents, seed 1)

| Engine | Inputs | Same verdict as Expat | Crash/timeout/exception | Both accept, events differ |
|---|---|---|---|---|
| xpact | 870,295 | 99.996 % | 0 | - |
| gobo | 79,717 | 97.642 % | 0 | - |

### Differential vs Expat (generated documents, seed 1)

| Engine | Inputs | Same verdict as Expat | Crash/timeout/exception | Both accept, events differ |
|---|---|---|---|---|
| xpact | 1,039,865 | 99.995 % | 0 | 0 |

Security and limits: xpact 20/29 as expected, Gobo 21/29; Gobo timeout/crash/exception: billion-laughs, quadratic-blowup, entity-chain-100k, deep-nesting-1m


### Security and limits (expected = what a safe Expat-compatible parser does)

| Case | Expected | xpact | Gobo |
|---|---|---|---|
| billion-laughs | REJECT | ✅ REJECT 3.0824 s 130.9 MB | ❌ TIMEOUT  s  MB |
| billion-laughs-attr | REJECT | ✅ REJECT 0.9458 s 34.0 MB | ✅ REJECT 0.0464 s 9.0 MB |
| billion-laughs-pe | REJECT | ✅ REJECT 0.0004 s 19.5 MB | ✅ REJECT 0.0386 s 7.9 MB |
| quadratic-blowup | REJECT | ✅ REJECT 0.174 s 43.9 MB | ❌ TIMEOUT  s  MB |
| small-amplification-ok | ACCEPT | ✅ ACCEPT 0.0008 s 19.6 MB | ✅ ACCEPT 0.1197 s 9.4 MB |
| recursive-direct | REJECT | ✅ REJECT 0.0005 s 19.6 MB | ✅ REJECT 0.0395 s 7.9 MB |
| recursive-indirect | REJECT | ✅ REJECT 0.0005 s 19.3 MB | ✅ REJECT 0.038 s 8.0 MB |
| recursive-pe | REJECT | ✅ REJECT 0.0004 s 19.2 MB | ✅ REJECT 0.0383 s 7.9 MB |
| entity-chain-10k | ACCEPT | ✅ ACCEPT 0.0643 s 33.9 MB | ✅ ACCEPT 0.6157 s 221.8 MB |
| entity-chain-100k | ACCEPT | ✅ ACCEPT 1.2001 s 112.5 MB | ❌ EXCEPTION 5.3892 s 2045.0 MB |
| deep-nesting-100k | ACCEPT | ❌ REJECT 0.0079 s 23.4 MB | ✅ ACCEPT 3.4948 s 159.1 MB |
| deep-nesting-1m | ACCEPT | ❌ REJECT 0.0666 s 59.5 MB | ❌ TIMEOUT  s  MB |
| huge-name-10mb | ACCEPT | ❌ REJECT 0.0431 s 49.2 MB | ✅ ACCEPT 1.0055 s 174.2 MB |
| huge-attribute-50mb | ACCEPT | ❌ REJECT 0.2145 s 169.3 MB | ✅ ACCEPT 2.8462 s 486.5 MB |
| huge-text-100mb | ACCEPT | ❌ REJECT 0.4277 s 319.2 MB | ✅ ACCEPT 5.4447 s 965.5 MB |
| huge-comment-50mb | ACCEPT | ❌ REJECT 0.2073 s 169.0 MB | ✅ ACCEPT 2.8849 s 486.5 MB |
| many-attributes-100k | ACCEPT | ❌ REJECT 0.0116 s 25.8 MB | ✅ ACCEPT 0.3606 s 59.3 MB |
| duplicate-attribute-late | REJECT | ✅ REJECT 0.0011 s 19.7 MB | ✅ REJECT 0.0487 s 8.5 MB |
| many-namespaces-50k | ACCEPT | ❌ REJECT 0.012 s 26.1 MB | ✅ ACCEPT 0.1435 s 37.8 MB |
| big-token-small-chunks | ACCEPT | ✅ ACCEPT 0.1252 s 72.3 MB | ✅ ACCEPT 0.3077 s 52.9 MB |
| big-text-byte-chunks | ACCEPT | ✅ ACCEPT 0.6859 s 34.1 MB | ✅ ACCEPT 0.0721 s 10.2 MB |
| xxe-general-no-handler | ACCEPT | ✅ ACCEPT 0.0004 s 19.5 MB | ❌ REJECT 0.0386 s 7.9 MB |
| xxe-parameter-no-handler | ACCEPT | ✅ ACCEPT 0.0005 s 19.2 MB | ❌ REJECT 0.0388 s 7.9 MB |
| xxe-dtd-no-handler | ACCEPT | ✅ ACCEPT 0.0004 s 19.2 MB | ❌ REJECT 0.0408 s 7.9 MB |
| ns-separator-in-uri | REJECT | ❌ ACCEPT 0.0004 s 19.2 MB | ❌ ACCEPT 0.0379 s 7.9 MB |
| bad-utf8-in-name-2byte | REJECT | ✅ REJECT 0.0003 s 19.3 MB | ✅ REJECT 0.0396 s 7.9 MB |
| bad-utf8-in-name-3byte | REJECT | ✅ REJECT 0.0003 s 19.2 MB | ✅ REJECT 0.0386 s 7.9 MB |
| bad-utf8-in-attr | REJECT | ✅ REJECT 0.0003 s 19.1 MB | ✅ REJECT 0.0394 s 7.9 MB |
| nul-byte | REJECT | ✅ REJECT 0.0004 s 19.4 MB | ✅ REJECT 0.0379 s 7.9 MB |

### Large files, whole document (seconds incl. harness)

| File | Handlers | xpact | Gobo | Gobo / xpact time |
|---|---|---|---|---|
| records-1mb.xml | none | ACCEPT 0.0306 s | ACCEPT 0.2322 s | 7.6x |
| records-1mb.xml | all | ACCEPT 0.1537 s | ACCEPT 0.4708 s | 3.1x |
| records-5mb.xml | none | ACCEPT 0.143 s | ACCEPT 0.8523 s | 6.0x |
| records-5mb.xml | all | ACCEPT 0.8688 s | ACCEPT 1.8962 s | 2.2x |
| records-9mb.xml | none | ACCEPT 0.2514 s | ACCEPT 1.3741 s | 5.5x |
| records-9mb.xml | all | ACCEPT 1.6693 s | ACCEPT 3.3811 s | 2.0x |
| records-20mb.xml | none | REJECT 0.0845 s | ACCEPT 2.5917 s | - |
| records-20mb.xml | all | REJECT 0.0841 s | ACCEPT 7.2067 s | - |
| text-1mb.xml | none | ACCEPT 0.0541 s | ACCEPT 0.2899 s | 5.4x |
| text-1mb.xml | all | ACCEPT 0.1128 s | ACCEPT 0.8902 s | 7.9x |
| text-5mb.xml | none | ACCEPT 0.2731 s | ACCEPT 1.0791 s | 4.0x |
| text-5mb.xml | all | ACCEPT 0.5882 s | ACCEPT 3.5685 s | 6.1x |
| text-9mb.xml | none | ACCEPT 0.4938 s | ACCEPT 1.7538 s | 3.6x |
| text-9mb.xml | all | ACCEPT 1.2288 s | ACCEPT 6.3332 s | 5.2x |
| text-20mb.xml | none | REJECT 0.0891 s | ACCEPT 3.5854 s | - |
| text-20mb.xml | all | REJECT 0.0913 s | ACCEPT 13.5672 s | - |
| ns-1mb.xml | none | ACCEPT 0.1602 s | ACCEPT 0.3371 s | 2.1x |
| ns-1mb.xml | all | ACCEPT 0.4941 s | ACCEPT 0.8267 s | 1.7x |
| ns-5mb.xml | none | ACCEPT 0.7502 s | ACCEPT 1.2395 s | 1.7x |
| ns-5mb.xml | all | ACCEPT 2.9592 s | ACCEPT 4.0232 s | 1.4x |
| ns-9mb.xml | none | ACCEPT 1.3854 s | ACCEPT 2.0031 s | 1.4x |
| ns-9mb.xml | all | ACCEPT 5.4643 s | ACCEPT 6.9379 s | 1.3x |
| ns-20mb.xml | none | REJECT 0.084 s | ACCEPT 3.6749 s | - |
| ns-20mb.xml | all | REJECT 0.0829 s | ACCEPT 15.7505 s | - |
| nested-1mb.xml | none | ACCEPT 0.031 s | ACCEPT 0.3153 s | 10.2x |
| nested-1mb.xml | all | ACCEPT 0.2134 s | ACCEPT 0.6084 s | 2.9x |
| nested-5mb.xml | none | ACCEPT 0.1528 s | ACCEPT 1.1723 s | 7.7x |
| nested-5mb.xml | all | ACCEPT 1.3088 s | ACCEPT 2.6741 s | 2.0x |
| nested-9mb.xml | none | ACCEPT 0.2728 s | ACCEPT 1.8507 s | 6.8x |
| nested-9mb.xml | all | ACCEPT 2.3828 s | ACCEPT 4.5196 s | 1.9x |
| nested-20mb.xml | none | REJECT 0.0808 s | ACCEPT 3.4563 s | - |
| nested-20mb.xml | all | REJECT 0.0835 s | ACCEPT 9.285 s | - |

### Speed per document (ms; Eiffel processes, start-up removed, median of 3)

| File | xpact ms | Gobo ms | Expat (pyexpat) ms | Gobo / xpact | Gobo verdict |
|---|---|---|---|---|---|
| attributes-10KB-utf8.xml | 0.368 | 2.2 | 0.077 | 5.98x | ok |
| attributes-10MB-utf8.xml | 360.546 | 1599.714 | 74.702 | 4.44x | ok |
| attributes-1MB-utf8.xml | 36.445 | 198.746 | 7.323 | 5.45x | ok |
| dtd-10KB-utf8.xml | 0.897 | 30.122 | 0.081 | 33.59x | ok |
| dtd-10MB-utf8.xml | 831.055 | 21084.501 | 74.448 | 25.37x | ok |
| dtd-1MB-utf8.xml | 85.258 | 2790.617 | 7.076 | 32.73x | ok |
| elements-10KB-utf8.xml | 0.553 | 3.057 | 0.078 | 5.53x | ok |
| elements-10MB-utf8.xml | 511.272 | 1980.773 | 69.044 | 3.87x | ok |
| elements-1MB-latin1.xml | 82.563 | 281.286 | 7.231 | 3.41x | ok |
| elements-1MB-utf16.xml | 89.68 | 424.107 | 7.803 | 4.73x | ok |
| elements-1MB-utf8.xml | 52.371 | 256.859 | 6.933 | 4.9x | ok |
| namespaces-10KB-utf8.xml | 0.35 | 2.612 | 0.069 | 7.46x | ok |
| namespaces-10MB-utf8.xml | 320.324 | 1676.068 | 62.498 | 5.23x | ok |
| namespaces-1MB-utf8.xml | 32.914 | 228.327 | 6.058 | 6.94x | ok |
| text-10KB-utf8.xml | 0.172 | 1.486 | 0.019 | 8.64x | ok |
| text-10MB-utf8.xml | 166.115 | 1025.575 | 16.597 | 6.17x | ok |
| text-1MB-utf8.xml | 16.441 | 133.155 | 1.407 | 8.1x | ok |
