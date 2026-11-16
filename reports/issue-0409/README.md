# #409: Gobo ECF on Windows: `eif_misc.h` not found (2026-11-16)

[← reports](../README.md) · issue [#409](https://github.com/andersoxie/xpact/issues/409) · background: [Gobo for xpact](../gobo-2026-11-16/README.md)

## In short
| | |
|---|---|
| Problem | `gec` 26.11.14 on Windows (built-in Zig C compiler) stopped with `fatal error: 'eif_misc.h' file not found` for the shared `benchmarks/xpact_gobo_benchmarks.ecf` |
| Fix | ✅ Eric Bezault's suggestion: `C inline use %"eif_misc.h%"` (quotes) instead of `<eif_misc.h>` in `src/xp_local_external_entity_resolver.e` (2 lines). The shared ECF is **unchanged** |
| Status | ✅ Fixed in our code and verified. Eric calls it a workaround until `gec` itself handles `<...>` here |

## Verification (Windows 11, Gobo 26.11.14+55e703f with Zig, EiffelStudio 25.12, from `incremental-test` `335ae82`)
| Check | Before | After |
|---|---|---|
| `gec --finalize --gc=boehm --target=xpact_benchmarks benchmarks\xpact_gobo_benchmarks.ecf` | ❌ `eif_misc.h` not found | ✅ builds |
| same, `--target=xpact_benchmarks_assertions` | ❌ | ✅ builds |
| EiffelStudio `ec -finalize -c_compile`, both targets | ✅ | ✅ builds (the quoted form works there too) |
| W3C profile, 2,585 cases, `scripts/run_w3c_conformance.py --jobs 16`, 4 engines | 1,974 passed / 0 failed / 0 errors each | **identical**: 1,974 / 0 / 0 each ([summary](w3c-summary.md)) |

Note: the first EiffelStudio attempt stopped with `Cannot start "nmake"` because the shell had no Visual Studio environment
(environment problem, not the change); rerun after `scripts/import_msvc_environment.ps1` passed.

## Result
- [x] The shared Gobo ECF builds on Windows without the workaround copy.
- [x] `reports/gobo-2026-11-16/xpact_gobo_benchmarks_win.ecf` is no longer needed (kept as a record of the earlier workaround).
- [ ] Gobo side: `gec` handling `<eif_misc.h>` itself (Eric).
