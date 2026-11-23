# WSL2 GCC benchmarks

Generated: 2026-11-23T08:34:44.733548+00:00

Linux: Linux-6.18.58.1-microsoft-standard-WSL2-x86_64-with-glibc2.39

EiffelStudio: ISE EiffelStudio version 25.12.9.8922 - linux-x86-64

Gobo Eiffel: gec version 26.11.14+55e703f

GCC: gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0

Expat: expat_2.6.1 (/usr/lib/x86_64-linux-gnu/libexpat.so.1.9.1)

Workload: the same 2611-byte UTF-8 catalog with 100 item elements; 2000 documents per run.

Each engine has one untimed warmup. Values are the lower median of 3 measured runs. Times include Linux process startup and exclude compilation and wsl.exe startup.

| Engine | Median elapsed ms | Docs/sec | MiB/sec | Notes |
|---|---:|---:|---:|---|
| xpact Eiffel finalized, assertions discarded via WSL2 gcc | 206.246 | 9697.154 | 24.146 | Linux EiffelStudio/GCC; parser reused; no-op event handler; Linux process wall time |
| xpact Eiffel finalized, assertions discarded via WSL2 gcc, GC suspended during parse | 203.619 | 9822.26 | 24.458 | Linux EiffelStudio/GCC; parser reused; no-op event handler; Linux process wall time; calls parse_without_garbage_collection |
| xpact Eiffel finalized, assertions enabled via WSL2 gcc | 2466.627 | 810.824 | 2.019 | Linux EiffelStudio/GCC; parser reused; no-op event handler; Linux process wall time |
| xpact Eiffel finalized, assertions enabled via WSL2 gcc, GC suspended during parse | 2497.863 | 800.684 | 1.994 | Linux EiffelStudio/GCC; parser reused; no-op event handler; Linux process wall time; calls parse_without_garbage_collection |
| xpact Gobo Eiffel finalized, assertions discarded via WSL2 gcc | 167.829 | 11916.865 | 29.674 | Gobo Eiffel/GCC; Boehm GC; parser reused; no-op event handler; Linux process wall time; normal GC only in this runner; Base assertions disabled |
| xpact Gobo Eiffel finalized, xpact assertions requested via WSL2 gcc | 664.955 | 3007.722 | 7.489 | Gobo Eiffel/GCC; Boehm GC; parser reused; no-op event handler; Linux process wall time; normal GC only in this runner; Base assertions disabled; Assertion coverage is compiler-dependent; see docs/gobo-assertions.md |
| libexpat C callbacks via WSL2 gcc | 40.303 | 49623.873 | 123.566 | GCC -O2; distro libexpat; parser created per document; C callbacks; Linux process wall time |
| libexpat C tokenizer via WSL2 gcc | 38.286 | 52238.224 | 130.075 | GCC -O2; distro libexpat; parser created per document; no callbacks; Linux process wall time |

Using one Linux environment reduces OS and launch differences between the Eiffel and libexpat rows. Eiffel uses its own generated GCC options; the C harness uses -O2 and the installed distro libexpat. This does not isolate the effect of switching MSVC to GCC. Eiffel reuses its parser with a no-op handler; libexpat creates a parser per document, with callbacks enabled or disabled as labelled.

Raw repetitions: benchmark-results.tsv. Toolchain and run metadata: metadata.json. Build diagnostics: logs/.
