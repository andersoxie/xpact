# 3 · Fuzzing

> **Question:** Does xpact crash or hang on random and mutated input?
> **Status:** ✅ run (2026-10-28) · ✅ **0 crashes, 0 hangs in 571,839 inputs** · nothing changed in xpact

[⬅ back to AlotOfTests](../README.md)

## In short

| | |
|---|---|
| Inputs | **571,839** in 30 minutes (seed 1) |
| Seeds | every W3C document up to 4 KB (about 2,300) |
| Mutations per input | 1–8: bit flips, deletions, inserted XML tokens (`<!DOCTYPE`, `&`, `]]>`, `%p;`, BOMs, broken UTF-8 …), copied and repeated ranges, pieces of other seeds |
| Feeding | whole (40 %), byte by byte, fixed small chunks, or one random split; 30 % with the namespace parser |
| ✅ Crashes (`CRASH`) | **0** |
| ✅ Hangs (> 10 s) | **0** |
| Same verdict as Expat | 571,749 (99.98 %) |
| Different verdict | 90 (86 xpact REJECT / Expat ACCEPT, 4 the other way): the same kinds as in test 4 |

Result: [logs/fuzz-xpact-seed1.json](logs/fuzz-xpact-seed1.json) · console: [logs/fuzz-xpact-seed1.txt](logs/fuzz-xpact-seed1.txt) · saved crash inputs: [findings/](findings/) (empty)

## How it works

[fuzz.py](fuzz.py) runs xpact in a child process ([harness/pool.py](../harness/pool.py)). A crash kills only the child: the input is saved to `findings/` with the way it was fed, and the child is restarted. A hang is retried whole with 60 s, to separate it from the known streaming slowdown (test 5, F05-1).

Reproduce: `python fuzz.py --seconds 1800 --seed 1`. The same seed gives the same inputs.

## Limitations

- **Not coverage-guided.** libFuzzer/AFL steer towards new code paths; this fuzzer is random. A coverage-guided build of `xpact.dll` (clang `-fsanitize=fuzzer,address`) is not possible with the Eiffel/MSVC toolchain on this PC.
- No AddressSanitizer: a memory error that does not crash is not seen (see test 9).
- Only the main document is mutated; external entities are not loaded in this test.
- Normal build only; the assertions build is the next run.

## To do

- [ ] Same run with `xpact_assertions.dll` (assertion violations show as crashes)
- [ ] More seeds: Expat's test documents, libxml2 corpus (test 7)
- [ ] Longer run (overnight)
