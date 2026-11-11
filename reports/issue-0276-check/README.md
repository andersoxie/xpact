# Speed check for #273 and #274 with the fair speed harness (#275, PR #276)

| | |
|---|---|
| Date | 2026-11-11 |
| Old DLL | `xpact.dll` `02B7F95B…` (`incremental-test` @ `0785dbf`, before #273/#274) |
| New DLL | `xpact.dll` `ADAE03D2…` (`incremental-test` @ `2935a8a`: #273 rescue guards + #274 call lock) |
| Harness | `benchmarks/fair_speed/fair_speed.c` (cl /O2), inputs from `gen_inputs.py`, callbacks on |
| Command | `python -I reports/issue-0276-check/old_vs_new.py <fair_speed.exe> <inputs> <old dll> <new dll>` |
| Method | 5 rounds per case, order alternating (old/new, new/old), median; each run about 0.25 s |
| ⚠️ Conditions | PC **not idle** (other work running); numbers are indicative, repeat on an idle PC |

## Result ([table](old-vs-new.md))

- Whole documents and pieces ≥ 16 bytes: **no measurable cost** (new/old 0.97–1.03).
- 1-byte pieces: **about 2–4 % slower** (1.02 elements, 1.04 text): the extra `setjmp` (rescue) and lock per call, one call per byte.
- Checksums identical in every case: both DLLs do the same work.

The 2026-11-10 fair speed results ([student/results/fair-speed-2026-11-10](../../student/results/fair-speed-2026-11-10/README.md)) were measured with the old DLL; they still hold within these margins.
