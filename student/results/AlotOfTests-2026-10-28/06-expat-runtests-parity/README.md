# 6 · Expat's own unit tests (runtests) against xpact

> **Question:** How many of Expat's own C unit tests pass when they run against xpact instead of Expat?
> **Status:** ✅ run (2026-10-28) · ✅ every test except the allocator tests passes (normal build) · 🔴 3 timeouts in the assertions build, confirmed on an idle PC (F06-1)

[⬅ back to AlotOfTests](../README.md)

## In short

Expat 2.8.1's `tests/runtests.c` (all 399 `START_TEST` cases) was built against `xpact.lib` and run, the same way Jenkins runs the stage `libexpat Adapter` with `RUN_LIBEXPAT_NATIVE_SUITE`.

| Test file | Tests | Normal build | Assertions build |
|---|---:|---|---|
| `basic_tests.c` | 252 | ✅ 252 | 🟡 248 + 4 timeouts |
| `ns_tests.c` | 33 | ✅ 33 | ✅ 33 |
| `misc_tests.c` | 22 | ✅ 22 | ✅ 22 |
| `acc_tests.c` | 4 | ✅ 4 | ✅ 4 |
| `alloc_tests.c` | 61 | ⚪ 36 + 25 expected failures | ⚪ the same |
| `nsalloc_tests.c` | 27 | ⚪ 14 + 13 expected failures | ⚪ the same |
| **Total** | **399** | **361 passed, 38 expected failures** | 357 passed, 38 expected, **4 timeouts** |

**Expected failures:** only the allocator tests. They make Expat's `malloc` fail on purpose, but xpact's Eiffel core manages its own memory, so the failure never reaches it ("Parsing worked despite failing reallocation"). This is documented in [`adapters/libexpat/parity.tsv`](../../../../adapters/libexpat/parity.tsv) (the only 2 `red` rows: `test_alloc_*`, `test_nsalloc_*`).

> Correction: an earlier summary said "15 red rows in `parity.tsv`". There are **2 red patterns**; the other 152 rows are green.

## 🟡 Assertions build: 4 timeouts (> 120 s)

| Test | What it does |
|---|---|
| `test_big_tokens_scale_linearly` | big tokens in growing buffers must scale linearly: this is the streaming slowdown of [test 5, F05-1](../05-security-limits/README.md) |
| `test_varying_buffer_fills` | many partial buffer fills (same area) |
| `test_deep_nested_attribute_entity` | deeply nested entities in an attribute |
| `test_deep_nested_entity_delayed_interpretation` | deeply nested entities, delayed |

- **First run:** the PC also ran three other test runs at the same time.
- **Rerun on an idle PC (2026-10-28):** 399 checks, 41 failed. These are 38 expected allocator failures plus **3 timeouts that stay**:
  - ⏱ `test_big_tokens_scale_linearly`;
  - ⏱ `test_varying_buffer_fills`;
  - ⏱ `test_deep_nested_attribute_entity`.

  ✅ `test_deep_nested_entity_delayed_interpretation` now passes, so it was caused by the busy PC.
  Log: [logs/xpact_assertions_idle/libexpat-native-suite.log](logs/xpact_assertions_idle/libexpat-native-suite.log)
- **Cause of the 3:** 🟡 suspected. They are real in the assertions build (over 120 s), and they pass in the normal build. Two of them test exactly the buffer and streaming behaviour of F05-1 (whole-buffer re-parse), and the extra checks of the assertions build make it slower still. Not confirmed with a profiler.
- **Problem ID:** F06-1, linked to F05-1.

## Commands

```powershell
# in this folder; uses the w9-latest worktree and the libexpat source in xpactGit\build
powershell -ExecutionPolicy Bypass -File run-native-suite.ps1                     # normal build
powershell -ExecutionPolicy Bypass -File run-native-suite.ps1 -Library build\native-eiffel\xpact_assertions.lib -Tag xpact_assertions
```

Logs: [logs/xpact/libexpat-native-suite.log](logs/xpact/libexpat-native-suite.log), [logs/xpact_assertions/libexpat-native-suite.log](logs/xpact_assertions/libexpat-native-suite.log), console: [logs/run-xpact.txt](logs/run-xpact.txt), [logs/run-xpact_assertions.txt](logs/run-xpact_assertions.txt)

## Limitations

- Expat's tests check the C API contract as Expat defines it; a pass does not prove the XML rules (that is the W3C suite, tests 1 and 2).
- `runtests` uses Expat's own default chunking; the quadratic streaming cost (F05-1) only shows in the timing tests.

## To do

- [x] Rerun the assertions build on an idle PC: 3 timeouts stay (F06-1)
- [ ] Time the 3 tests in the normal build, to see how close they are to the 120 s limit
- [ ] Decide with the supervisor: should xpact honour `XML_ParserCreate_MM` allocators (then the alloc tests could pass)?
