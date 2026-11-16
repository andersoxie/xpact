# Fair speed test: xpact vs native Expat 2.8.1

Median time per parse, xpact / Expat (1.0 = as fast; 2.0 = xpact twice as slow). Same harness, same `expat.h` API, both DLLs loaded with `LoadLibrary`.

**Cells measured:** 200 · **median ratio** 18.91 · best 2.18 · worst 41589.21 · checksum mismatches 0 · not compared (timeout/crash/reject) 4


## Callbacks off

| Input | whole | 64 KB | 4 KB | 256 B | 16 B | 1 B |
|---|---:|---:|---:|---:|---:|---:|
| `attributes-10KB-utf8` | 2.25 | 2.37 | 3.12 | 2.94 | 5.19 | 25.31 |
| `attributes-10MB-utf8` | 2.89 | 3.68 | 4.25 | 4.98 | 6.63 | 26.46 |
| `attributes-1MB-utf8` | 2.77 | 3.88 | 3.89 | 4.91 | 6.95 | 27.57 |
| `dtd-10KB-utf8` | 10.84 | 10.24 | 12.04 | 12.91 | 19.50 | 39.78 |
| `dtd-10MB-utf8` | 11.41 | 13.43 | 12.52 | 14.05 | 19.73 | 43.27 |
| `dtd-1MB-utf8` | 11.70 | 13.54 | 12.40 | 15.28 | 19.46 | 44.85 |
| `elements-10KB-utf8` | 4.96 | 5.18 | 10.88 | 11.60 | 14.96 | 23.57 |
| `elements-10MB-utf8` | 5.97 | 12.34 | 11.74 | 13.94 | 17.56 | 25.64 |
| `elements-1MB-latin1` | 6.55 | 105.80 | 1613.39 | 27459.07 | TIMEOUT | TIMEOUT |
| `elements-1MB-utf16` | 6.07 | 12.95 | 13.01 | 13.33 | 19.96 | 23.16 |
| `elements-1MB-utf8` | 5.25 | 12.53 | 13.26 | 13.78 | 19.64 | 24.29 |
| `namespaces-10KB-utf8` | 11.37 | 12.95 | 14.77 | 14.20 | 17.59 | 23.74 |
| `namespaces-10MB-utf8` | 16.09 | 19.64 | 18.77 | 19.32 | 22.40 | 30.46 |
| `namespaces-1MB-utf8` | 14.89 | 17.63 | 20.60 | 17.05 | 21.51 | 26.25 |
| `text-10KB-utf8` | 2.18 | 3.30 | 6.79 | 8.78 | 16.50 | 39.05 |
| `text-10MB-utf8` | 8.11 | 12.54 | 12.30 | 15.48 | 23.00 | 33.91 |
| `text-1MB-utf8` | 8.27 | 10.78 | 12.64 | 15.14 | 22.79 | 32.93 |

## Callbacks on

| Input | whole | 64 KB | 4 KB | 256 B | 16 B | 1 B |
|---|---:|---:|---:|---:|---:|---:|
| `attributes-10KB-utf8` | 8.20 | 9.52 | 8.14 | 7.71 | 8.36 | 23.34 |
| `attributes-10MB-utf8` | 10.59 | 11.30 | 10.95 | 11.00 | 12.22 | 25.81 |
| `attributes-1MB-utf8` | 10.89 | 11.48 | 10.88 | 11.72 | 12.28 | 24.04 |
| `dtd-10KB-utf8` | 16.17 | 17.91 | 15.24 | 16.11 | 16.40 | 30.20 |
| `dtd-10MB-utf8` | 17.05 | 19.13 | 22.18 | 20.67 | 21.42 | 29.85 |
| `dtd-1MB-utf8` | 18.98 | 20.17 | 20.89 | 20.48 | 21.62 | 28.76 |
| `elements-10KB-utf8` | 16.92 | 15.69 | 19.28 | 20.46 | 22.61 | 26.03 |
| `elements-10MB-utf8` | 19.06 | 24.53 | 26.21 | 25.43 | 26.02 | 27.15 |
| `elements-1MB-latin1` | 19.90 | 170.59 | 2332.32 | 41589.21 | TIMEOUT | TIMEOUT |
| `elements-1MB-utf16` | 19.46 | 24.54 | 24.56 | 22.14 | 26.33 | 22.11 |
| `elements-1MB-utf8` | 19.46 | 24.95 | 23.23 | 21.83 | 24.67 | 27.48 |
| `namespaces-10KB-utf8` | 18.83 | 18.12 | 21.30 | 21.80 | 21.81 | 28.42 |
| `namespaces-10MB-utf8` | 21.52 | 22.28 | 24.40 | 21.01 | 24.10 | 26.40 |
| `namespaces-1MB-utf8` | 21.85 | 23.82 | 21.87 | 21.37 | 23.61 | 27.46 |
| `text-10KB-utf8` | 12.63 | 11.53 | 11.44 | 8.60 | 11.56 | 29.24 |
| `text-10MB-utf8` | 20.54 | 19.19 | 20.14 | 20.18 | 29.55 | 34.00 |
| `text-1MB-utf8` | 18.19 | 19.39 | 19.31 | 20.47 | 28.32 | 31.34 |

## Absolute times (ms per parse), callbacks on, whole and 1 byte

| Input | xpact whole | Expat whole | xpact 1 B | Expat 1 B |
|---|---:|---:|---:|---:|
| `attributes-10KB-utf8` | 1.3901 | 0.1695 | 10.0411 | 0.4303 |
| `attributes-10MB-utf8` | 1113.6690 | 105.1835 | 8028.3545 | 311.0564 |
| `attributes-1MB-utf8` | 115.1507 | 10.5710 | 772.4842 | 32.1290 |
| `dtd-10KB-utf8` | 2.4757 | 0.1531 | 13.8394 | 0.4583 |
| `dtd-10MB-utf8` | 2429.0647 | 142.4826 | 13832.2831 | 463.3724 |
| `dtd-1MB-utf8` | 241.2529 | 12.7082 | 1374.3010 | 47.7932 |
| `elements-10KB-utf8` | 2.3550 | 0.1392 | 11.6891 | 0.4490 |
| `elements-10MB-utf8` | 2342.8178 | 122.9433 | 11565.5809 | 426.0327 |
| `elements-1MB-latin1` | 244.9600 | 12.3126 | TIMEOUT | 36.3802 |
| `elements-1MB-utf16` | 281.9166 | 14.4881 | 1613.0057 | 72.9525 |
| `elements-1MB-utf8` | 244.7342 | 12.5787 | 1275.5115 | 46.4209 |
| `namespaces-10KB-utf8` | 3.5324 | 0.1876 | 11.8830 | 0.4181 |
| `namespaces-10MB-utf8` | 3091.8025 | 143.6583 | 11441.9410 | 433.3755 |
| `namespaces-1MB-utf8` | 305.0693 | 13.9630 | 1219.1168 | 44.4040 |
| `text-10KB-utf8` | 0.7553 | 0.0598 | 15.1621 | 0.5186 |
| `text-10MB-utf8` | 641.3222 | 31.2168 | 14945.8773 | 439.6162 |
| `text-1MB-utf8` | 63.1778 | 3.4736 | 1580.9548 | 50.4520 |

## Not compared or different

- `('elements-1MB-latin1.xml', '16', '0')`: xpact TIMEOUT warm-up over 900 s, Expat 1
- `('elements-1MB-latin1.xml', '16', '1')`: xpact TIMEOUT warm-up over 900 s, Expat 1
- `('elements-1MB-latin1.xml', '1', '0')`: xpact TIMEOUT warm-up over 900 s, Expat 1
- `('elements-1MB-latin1.xml', '1', '1')`: xpact TIMEOUT warm-up over 900 s, Expat 1
