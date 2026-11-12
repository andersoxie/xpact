# Fair speed test: xpact vs native Expat 2.8.1

Median time per parse, xpact / Expat (1.0 = as fast; 2.0 = xpact twice as slow). Same harness, same `expat.h` API, both DLLs loaded with `LoadLibrary`.

**Cells measured:** 200 · **median ratio** 18.16 · best 2.25 · worst 36031.67 · checksum mismatches 0 · not compared (timeout/crash/reject) 4


## Callbacks off

| Input | whole | 64 KB | 4 KB | 256 B | 16 B | 1 B |
|---|---:|---:|---:|---:|---:|---:|
| `attributes-10KB-utf8` | 2.29 | 2.25 | 3.12 | 3.88 | 6.07 | 23.61 |
| `attributes-10MB-utf8` | 2.61 | 3.65 | 3.73 | 4.36 | 6.77 | 24.08 |
| `attributes-1MB-utf8` | 2.61 | 3.57 | 3.70 | 4.42 | 6.77 | 23.83 |
| `dtd-10KB-utf8` | 10.07 | 10.61 | 11.80 | 13.02 | 19.24 | 39.19 |
| `dtd-10MB-utf8` | 12.24 | 13.84 | 13.94 | 14.69 | 21.71 | 42.93 |
| `dtd-1MB-utf8` | 12.59 | 14.26 | 14.56 | 15.25 | 22.07 | 41.51 |
| `elements-10KB-utf8` | 4.85 | 4.84 | 10.56 | 11.64 | 15.11 | 22.13 |
| `elements-10MB-utf8` | 5.75 | 13.32 | 13.45 | 13.52 | 17.76 | 23.45 |
| `elements-1MB-latin1` | 6.72 | 113.79 | 1781.79 | 27625.10 | TIMEOUT | TIMEOUT |
| `elements-1MB-utf16` | 6.97 | 13.41 | 13.43 | 13.46 | 17.92 | 21.89 |
| `elements-1MB-utf8` | 5.60 | 13.19 | 13.38 | 13.70 | 17.70 | 22.96 |
| `namespaces-10KB-utf8` | 13.98 | 13.80 | 15.99 | 16.30 | 18.63 | 26.69 |
| `namespaces-10MB-utf8` | 16.14 | 18.75 | 18.75 | 18.81 | 20.50 | 27.79 |
| `namespaces-1MB-utf8` | 15.95 | 18.81 | 18.76 | 18.79 | 20.35 | 28.41 |
| `text-10KB-utf8` | 4.83 | 4.85 | 7.24 | 8.86 | 18.56 | 30.99 |
| `text-10MB-utf8` | 8.64 | 11.91 | 12.17 | 13.61 | 24.60 | 31.40 |
| `text-1MB-utf8` | 8.32 | 11.76 | 11.79 | 13.46 | 25.50 | 32.00 |

## Callbacks on

| Input | whole | 64 KB | 4 KB | 256 B | 16 B | 1 B |
|---|---:|---:|---:|---:|---:|---:|
| `attributes-10KB-utf8` | 8.91 | 8.94 | 9.15 | 9.63 | 10.36 | 23.06 |
| `attributes-10MB-utf8` | 10.34 | 10.18 | 10.22 | 10.58 | 11.48 | 23.53 |
| `attributes-1MB-utf8` | 10.47 | 10.52 | 10.66 | 11.12 | 11.98 | 22.06 |
| `dtd-10KB-utf8` | 16.76 | 17.35 | 16.93 | 18.64 | 19.92 | 26.40 |
| `dtd-10MB-utf8` | 18.89 | 19.66 | 19.52 | 19.72 | 21.69 | 26.20 |
| `dtd-1MB-utf8` | 19.10 | 19.55 | 20.22 | 19.87 | 21.47 | 25.70 |
| `elements-10KB-utf8` | 14.83 | 14.52 | 18.89 | 19.92 | 20.91 | 22.61 |
| `elements-10MB-utf8` | 16.68 | 22.56 | 22.55 | 22.52 | 23.94 | 24.56 |
| `elements-1MB-latin1` | 17.89 | 157.01 | 2337.65 | 36031.67 | TIMEOUT | TIMEOUT |
| `elements-1MB-utf16` | 16.95 | 21.82 | 21.59 | 21.47 | 23.32 | 21.03 |
| `elements-1MB-utf8` | 17.22 | 22.47 | 22.66 | 22.93 | 23.77 | 23.18 |
| `namespaces-10KB-utf8` | 17.73 | 18.00 | 18.83 | 19.64 | 20.37 | 25.69 |
| `namespaces-10MB-utf8` | 20.24 | 22.31 | 22.14 | 22.45 | 22.62 | 26.17 |
| `namespaces-1MB-utf8` | 20.10 | 22.10 | 22.06 | 22.35 | 22.75 | 27.16 |
| `text-10KB-utf8` | 12.46 | 12.53 | 12.27 | 13.17 | 20.38 | 28.03 |
| `text-10MB-utf8` | 19.91 | 17.94 | 18.01 | 19.25 | 27.01 | 29.38 |
| `text-1MB-utf8` | 19.83 | 17.91 | 18.13 | 18.19 | 26.97 | 29.27 |

## Absolute times (ms per parse), callbacks on, whole and 1 byte

| Input | xpact whole | Expat whole | xpact 1 B | Expat 1 B |
|---|---:|---:|---:|---:|
| `attributes-10KB-utf8` | 0.8920 | 0.1001 | 5.8583 | 0.2540 |
| `attributes-10MB-utf8` | 875.2661 | 84.6508 | 5620.7224 | 238.8612 |
| `attributes-1MB-utf8` | 89.5552 | 8.5495 | 583.8502 | 26.4686 |
| `dtd-10KB-utf8` | 2.1297 | 0.1271 | 10.3298 | 0.3913 |
| `dtd-10MB-utf8` | 1806.3825 | 95.6014 | 9552.8873 | 364.6681 |
| `dtd-1MB-utf8` | 177.8401 | 9.3095 | 952.8310 | 37.0692 |
| `elements-10KB-utf8` | 1.6266 | 0.1097 | 8.6069 | 0.3806 |
| `elements-10MB-utf8` | 1492.2423 | 89.4761 | 7998.3811 | 325.6298 |
| `elements-1MB-latin1` | 162.6982 | 9.0950 | TIMEOUT | 34.7942 |
| `elements-1MB-utf16` | 172.9051 | 10.1994 | 1035.5798 | 49.2316 |
| `elements-1MB-utf8` | 161.2406 | 9.3622 | 798.5827 | 34.4462 |
| `namespaces-10KB-utf8` | 2.2742 | 0.1283 | 8.3605 | 0.3255 |
| `namespaces-10MB-utf8` | 2085.5527 | 103.0377 | 7823.3386 | 298.9417 |
| `namespaces-1MB-utf8` | 212.6516 | 10.5799 | 802.5106 | 29.5424 |
| `text-10KB-utf8` | 0.4808 | 0.0386 | 10.2747 | 0.3666 |
| `text-10MB-utf8` | 455.0054 | 22.8505 | 10001.1493 | 340.4337 |
| `text-1MB-utf8` | 46.2300 | 2.3316 | 997.6701 | 34.0824 |

## Assertions build (subset), ms per parse

| Input | Piece | assertions | production | ratio |
|---|---|---:|---:|---:|
| `elements-1MB-utf8` | whole | 1621.3987 | 161.2406 | 10.1 |
| `elements-1MB-utf8` | 1 B | 14088.2919 | 798.5827 | 17.6 |
| `elements-1MB-utf8` | 16 B | 3290.3933 | 309.8152 | 10.6 |
| `elements-1MB-utf8` | 256 B | 2214.4393 | 232.6821 | 9.5 |
| `elements-1MB-utf8` | 4 KB | 2114.6875 | 225.9074 | 9.4 |
| `elements-1MB-utf8` | 64 KB | 2103.7988 | 223.2533 | 9.4 |
| `text-1MB-utf8` | whole | 633.6464 | 46.2300 | 13.7 |
| `text-1MB-utf8` | 1 B | 21613.2459 | 997.6701 | 21.7 |
| `text-1MB-utf8` | 16 B | 2104.7466 | 120.3770 | 17.5 |
| `text-1MB-utf8` | 256 B | 828.9359 | 61.0406 | 13.6 |
| `text-1MB-utf8` | 4 KB | 737.3381 | 56.6224 | 13.0 |
| `text-1MB-utf8` | 64 KB | 722.3150 | 56.1614 | 12.9 |

## Not compared or different

- `('elements-1MB-latin1.xml', '16', '0')`: xpact TIMEOUT warm-up over 900 s, Expat 1
- `('elements-1MB-latin1.xml', '16', '1')`: xpact TIMEOUT warm-up over 900 s, Expat 1
- `('elements-1MB-latin1.xml', '1', '0')`: xpact TIMEOUT warm-up over 900 s, Expat 1
- `('elements-1MB-latin1.xml', '1', '1')`: xpact TIMEOUT warm-up over 900 s, Expat 1
