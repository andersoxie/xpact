# Fair speed test: xpact vs native Expat 2.8.1

Median time per parse, xpact / Expat (1.0 = as fast; 2.0 = xpact twice as slow). Same harness, same `expat.h` API, both DLLs loaded with `LoadLibrary`.

**Cells measured:** 200 · **median ratio** 17.82 · best 2.19 · worst 41504.39 · checksum mismatches 0 · not compared (timeout/crash/reject) 4


## Callbacks off

| Input | whole | 64 KB | 4 KB | 256 B | 16 B | 1 B |
|---|---:|---:|---:|---:|---:|---:|
| `attributes-10KB-utf8` | 2.60 | 2.19 | 3.17 | 4.02 | 6.75 | 29.06 |
| `attributes-10MB-utf8` | 2.96 | 4.20 | 4.06 | 4.62 | 6.92 | 25.57 |
| `attributes-1MB-utf8` | 2.66 | 3.70 | 3.62 | 4.30 | 6.23 | 25.59 |
| `dtd-10KB-utf8` | 8.86 | 9.62 | 9.98 | 9.09 | 13.17 | 36.11 |
| `dtd-10MB-utf8` | 8.81 | 11.00 | 11.94 | 12.81 | 20.00 | 36.02 |
| `dtd-1MB-utf8` | 10.62 | 12.94 | 10.89 | 11.81 | 19.88 | 42.06 |
| `elements-10KB-utf8` | 5.15 | 4.24 | 5.57 | 10.30 | 15.98 | 23.06 |
| `elements-10MB-utf8` | 5.62 | 11.24 | 12.24 | 12.56 | 17.50 | 23.01 |
| `elements-1MB-latin1` | 7.27 | 110.00 | 1592.92 | 24541.27 | TIMEOUT | TIMEOUT |
| `elements-1MB-utf16` | 5.79 | 14.80 | 14.61 | 13.52 | 16.18 | 25.55 |
| `elements-1MB-utf8` | 4.53 | 11.32 | 11.62 | 12.74 | 16.86 | 19.83 |
| `namespaces-10KB-utf8` | 15.39 | 9.12 | 17.01 | 18.18 | 16.26 | 32.02 |
| `namespaces-10MB-utf8` | 15.64 | 20.21 | 20.67 | 17.91 | 24.77 | 30.96 |
| `namespaces-1MB-utf8` | 17.35 | 17.96 | 21.61 | 18.77 | 21.75 | 29.42 |
| `text-10KB-utf8` | 3.20 | 5.05 | 4.29 | 7.53 | 20.10 | 39.11 |
| `text-10MB-utf8` | 8.72 | 13.48 | 11.68 | 12.57 | 24.47 | 34.79 |
| `text-1MB-utf8` | 8.73 | 11.42 | 11.33 | 12.86 | 25.54 | 32.02 |

## Callbacks on

| Input | whole | 64 KB | 4 KB | 256 B | 16 B | 1 B |
|---|---:|---:|---:|---:|---:|---:|
| `attributes-10KB-utf8` | 10.12 | 10.09 | 7.40 | 10.02 | 10.35 | 24.61 |
| `attributes-10MB-utf8` | 10.94 | 10.61 | 12.11 | 12.13 | 13.64 | 24.91 |
| `attributes-1MB-utf8` | 9.87 | 9.86 | 10.45 | 10.71 | 10.71 | 27.15 |
| `dtd-10KB-utf8` | 12.59 | 16.13 | 15.78 | 19.10 | 16.34 | 34.61 |
| `dtd-10MB-utf8` | 17.73 | 16.86 | 18.55 | 18.41 | 20.24 | 27.50 |
| `dtd-1MB-utf8` | 16.26 | 15.45 | 17.99 | 19.04 | 18.48 | 26.93 |
| `elements-10KB-utf8` | 13.09 | 15.68 | 22.51 | 17.69 | 21.92 | 22.26 |
| `elements-10MB-utf8` | 19.03 | 25.61 | 21.99 | 22.69 | 24.96 | 24.52 |
| `elements-1MB-latin1` | 20.80 | 148.48 | 2200.71 | 41504.39 | TIMEOUT | TIMEOUT |
| `elements-1MB-utf16` | 18.23 | 23.92 | 23.65 | 18.74 | 20.49 | 24.92 |
| `elements-1MB-utf8` | 20.08 | 24.57 | 25.44 | 23.04 | 22.39 | 26.34 |
| `namespaces-10KB-utf8` | 20.14 | 16.30 | 17.17 | 22.56 | 20.61 | 24.16 |
| `namespaces-10MB-utf8` | 24.32 | 26.02 | 22.53 | 23.96 | 22.87 | 28.52 |
| `namespaces-1MB-utf8` | 19.16 | 23.87 | 27.29 | 21.64 | 24.54 | 30.30 |
| `text-10KB-utf8` | 11.91 | 9.67 | 8.23 | 14.93 | 21.09 | 25.19 |
| `text-10MB-utf8` | 21.00 | 19.28 | 17.97 | 18.95 | 35.72 | 36.64 |
| `text-1MB-utf8` | 20.59 | 16.76 | 19.86 | 18.15 | 28.91 | 28.47 |

## Absolute times (ms per parse), callbacks on, whole and 1 byte

| Input | xpact whole | Expat whole | xpact 1 B | Expat 1 B |
|---|---:|---:|---:|---:|
| `attributes-10KB-utf8` | 1.4576 | 0.1440 | 9.6770 | 0.3932 |
| `attributes-10MB-utf8` | 1219.3221 | 111.4990 | 8556.5305 | 343.4966 |
| `attributes-1MB-utf8` | 118.4748 | 12.0090 | 868.4873 | 31.9846 |
| `dtd-10KB-utf8` | 2.5501 | 0.2026 | 16.0937 | 0.4650 |
| `dtd-10MB-utf8` | 2318.5220 | 130.8005 | 14055.4169 | 511.1932 |
| `dtd-1MB-utf8` | 227.7542 | 14.0113 | 1463.4175 | 54.3413 |
| `elements-10KB-utf8` | 2.5203 | 0.1925 | 13.0349 | 0.5857 |
| `elements-10MB-utf8` | 2440.6206 | 128.2413 | 12170.1812 | 496.2931 |
| `elements-1MB-latin1` | 253.4301 | 12.1818 | TIMEOUT | 36.0732 |
| `elements-1MB-utf16` | 291.1932 | 15.9706 | 1752.1431 | 70.3153 |
| `elements-1MB-utf8` | 261.7405 | 13.0356 | 1351.6447 | 51.3105 |
| `namespaces-10KB-utf8` | 3.4578 | 0.1717 | 12.0534 | 0.4989 |
| `namespaces-10MB-utf8` | 3159.9034 | 129.9389 | 12457.0275 | 436.7471 |
| `namespaces-1MB-utf8` | 388.3346 | 20.2674 | 1195.0537 | 39.4418 |
| `text-10KB-utf8` | 0.7574 | 0.0636 | 15.8280 | 0.6283 |
| `text-10MB-utf8` | 773.9637 | 36.8557 | 15593.4970 | 425.6103 |
| `text-1MB-utf8` | 66.0068 | 3.2061 | 1563.7683 | 54.9331 |

## Not compared or different

- `('elements-1MB-latin1.xml', '16', '0')`: xpact TIMEOUT warm-up over 900 s, Expat 1
- `('elements-1MB-latin1.xml', '16', '1')`: xpact TIMEOUT warm-up over 900 s, Expat 1
- `('elements-1MB-latin1.xml', '1', '0')`: xpact TIMEOUT warm-up over 900 s, Expat 1
- `('elements-1MB-latin1.xml', '1', '1')`: xpact TIMEOUT warm-up over 900 s, Expat 1
