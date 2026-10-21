# W3C XML conformance with assertions off and on

Issue: [#29](https://github.com/andersoxie/xpact/issues/29)   Finding: [#28](https://github.com/andersoxie/xpact/issues/28)   Revision: `2f0d441633fe036fabf0d972aa68c5e3836c60cd` (`student-Mass`, no local changes in `src/`, `benchmarks/`, `scripts/`)   Date: 2026-10-21

The first run of the W3C suite with the Python runner `scripts/run_w3c_conformance.py`
(see [`docs/w3c-xml-conformance.md`](../../../docs/w3c-xml-conformance.md)). The 2026-10-14
baseline used the older `run_xmlconf_conformance.ps1` with different verdict rules
(draft [12](../../github/issues/12-xmlconf-verdicts.md)), so its numbers are not comparable with these.

## Configuration

| Item | Value |
|---|---|
| Suite | https://www.w3.org/XML/Test/xmlts20130923.zip, SHA-256 `f9510b3532926e1b4c2e54855b021e4b8a66ec98a5337dcf4ff07e8a41968deb` (checked by the runner) |
| Profile | XML 1.0 fifth edition; namespaces unless `NAMESPACE="no"`; nonvalidating; no external entities; binary accept/reject verdicts |
| Runner | `scripts/run_w3c_conformance.py`, unchanged; Python 3.15.0 (installed with uv) |
| Program | `xpact_benchmarks.exe --conformance-file FILE [--namespaces]`, which calls `XP_PARSER.parse` directly with a no-op handler (`benchmarks/xp_benchmark_root.e:24-80`). Not the DLL. |
| Build `Finalized` | `benchmarks/xpact_benchmarks.ecf` target `xpact_benchmarks`, `ec -batch -clean -finalize`; assertions **off**. SHA-256 of the exe `e7459719adc273349923ab56257dad3ae703cffc667dd3b577c7a6e1dfcc34ed` |
| Build `FinalizedAssertions` | target `xpact_benchmarks_assertions`, `ec -batch -clean -finalize -keep`; assertions **on** (all kinds). SHA-256 of the exe `e93f6b42b44d7a9f43adb27e67d3a382c4de6a2e0fc5b8a07c7455e2c932c4c8` |
| C compilation | `finish_freezing` after `scripts/import_msvc_environment.ps1` (Visual Studio 18 Community, MSVC 14.51.36231) |
| Tools | EiffelStudio 25.12.9.8922 win64 · Windows 11 Home 10.0.26200 · Windows PowerShell 5.1 |
| Timeout | 10 s per case; every case is a fresh process |

## Commands

```powershell
ec -batch -clean -finalize       -config benchmarks\xpact_benchmarks.ecf -target xpact_benchmarks
ec -batch -clean -finalize -keep -config benchmarks\xpact_benchmarks.ecf -target xpact_benchmarks_assertions
# then, for each target:
. .\scripts\import_msvc_environment.ps1
cd EIFGENs\<target>\F_code; finish_freezing

python scripts\run_w3c_conformance.py `
  --engine "Finalized=EIFGENs/xpact_benchmarks/F_code/xpact_benchmarks.exe" `
  --engine "FinalizedAssertions=EIFGENs/xpact_benchmarks_assertions/F_code/xpact_benchmarks.exe" `
  --timeout 10
```

Exit status of the runner: **1** (some cases failed). Reports were written to
`build/benchmarks/w3c-xml-conformance/` (gitignored); the files in this folder are copied from there.

## Results

2,585 catalog cases; 1,727 applicable, 858 skipped with a reason (XML 1.1, other editions,
external entities, optional `error` cases).

| Build | Assertions | Passed | Failed | Errors (crash) | Skipped | Elapsed |
|---|---|---:|---:|---:|---:|---:|
| `Finalized` | off | 1,491 | 236 | 0 | 858 | 22-29 s |
| `FinalizedAssertions` | on | 270 | 97 | **1,360** | 858 | 35-36 s |

The same numbers came out in three runs (one with `Finalized` only, two with both builds).

### Failures with assertions off (236)

| Catalog type | Expected | Actual | Cases |
|---|---|---|---:|
| `not-wf` | REJECT | ACCEPT | **220** |
| `invalid` | ACCEPT | REJECT | 9 |
| `valid` | ACCEPT | REJECT | 7 |

By collection: eduni 72, ibm 59, oasis 43, xmltest 40, sun 22.

### Errors with assertions on (1,360)

| Cases | Where | What |
|---:|---|---|
| 1,357 | `XP_PARSER.normalized_input @8` | `a_input.count - i + 1`: Non-decreasing loop variant ([#28](https://github.com/andersoxie/xpact/issues/28)) |
| 2 | `not-wf-sa-050`, `o-p39fail3` | Empty (0-byte) files: exit 2, `conformance file read failed`. `Finalized` rejects both correctly |
| 1 | `rmt-e3e-12`, `XP_PARSER.parse_attlist_default_value @7` | `index_in_bounds`: Loop invariant violated |

The 97 failures with assertions on are all among the 236 failures with assertions off;
139 of those 236 crash with assertions on instead.

## The CR crash in 9 bytes

| File | Bytes | SHA-256 | Assertions off | Assertions on |
|---|---|---|---|---|
| [`lf.xml`](lf.xml) | `3C 72 3E 0A 3C 2F 72 3E` | `7b5783c08d18f9276eea591b0e50210fd77f15d18f829097a98333654d4881c5` | ACCEPT, exit 0 | ACCEPT, exit 0 |
| [`cr-lf.xml`](cr-lf.xml) | `3C 72 3E 0D 0A 3C 2F 72 3E` | `5b7e3147871965a78cccb9a0693be825766ba0125de44acf6f21debcff2a9fed` | ACCEPT, exit 0 | **crash, exit 1** |

```powershell
EIFGENs\xpact_benchmarks_assertions\F_code\xpact_benchmarks.exe --conformance-file student\results\w3c-conformance-2026-10-21\cr-lf.xml
```

[`.gitattributes`](.gitattributes) marks the `.xml` files as binary, so git does not change
their line ends (`core.autocrlf` is `true` on this PC).

## Observations

- All 1,357 `normalized_input` crashes are files with a CR byte (0x0D). Of the 1,365 applicable
  files with a CR, the other 8 do not crash there (not investigated why). No file without a CR crashes there.
- With assertions off the same files are parsed, so this crash hides every other assertion
  failure in the suite. The 53 crashes of 2026-10-14
  ([`xmlconf-crashes-2026-10-14/`](../xmlconf-crashes-2026-10-14/), draft
  [21](../../github/issues/21-finding-xmlconf-crashes.md)) cannot be rechecked until #28 is fixed.
  `rmt-e3e-12` is in the same routine as one of their crash sites.
- **0 errors with assertions off does not mean there are no contract failures:** the contracts
  are not compiled into that build.
- `xpact.exe` (`xpact.ecf`) has assertions on but only knows `--parse-file`, so the runner
  cannot use it. The DLL (`xpact.dll`, `xpact_assertions.dll`) is not tested by this lane.
- A first combined run was discarded: during it, something outside this session recompiled
  `EIFGENs/xpact_benchmarks` (W_code and F_code, 17:34:08-17:34:16), so every `Finalized`
  case failed with `[WinError 2]`. The runs above had no rebuild (exe timestamps checked
  before and after).

## Possible explanations (not confirmed)

- The 220 accepted `not-wf` cases: rules for DTD declarations, comments, PIs and character
  ranges that the parser does not check yet. Not analysed case by case.
- The two empty files: `run_conformance` may treat an empty read as a read failure only when
  assertions are on. Not investigated.

## Files

| File | Content |
|---|---|
| [`summary.md`](summary.md), [`summary.json`](summary.json) | The runner's summary of the last run |
| [`failures.tsv`](failures.tsv) | Every failed or crashed case of both builds: engine, case, type, expected, actual, status, path, first line of the message or the crash site (1,693 rows) |
| [`cr-lf.xml`](cr-lf.xml), [`lf.xml`](lf.xml) | Byte-exact repro of #28 and its control |
