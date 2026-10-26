# xpact vs Expat 2.8.1 through the C API (2026-10-26)

> **Issue:** [#121](https://github.com/andersoxie/xpact/issues/121) (week 5: C03, C10 part) · **Date:** 2026-10-26
> · **Code:** `student-Mass` @ `e30f0e6` · Builds: MSVC 19.51, finalized, assertions off and on

## In short

| | |
|---|---|
| ❓ The question | Does xpact answer like real Expat when the same small inputs are fed through the same C API, with every callback set and every chunk split? |
| 🔍 How | The C# DLL test program ([#37](https://github.com/andersoxie/xpact/issues/37)) run three times with `--dll`: on **Expat 2.8.1's own `libexpat.dll`**, on `xpact.dll` and on `xpact_assertions.dll`; then [`compare.py`](compare.py) case by case |
| ✅ Verdicts | **4,308 / 4,308 the same**: every input xpact accepts, Expat accepts; every input xpact rejects, Expat rejects. Whole, split at every byte and byte by byte |
| ✅ Chunking (C03) | Chunking never changes Expat's answer. It never changes xpact's verdict or error code either; only the position for `<root/>junk` moves (#124) |
| ❌ Differences | **5 findings**, each in its own issue (table below). None of them changes a verdict |
| ✅ Both xpact DLLs | `results.tsv` of `xpact.dll` and `xpact_assertions.dll` are byte-identical (SHA-256 `34bce072…`), 0 crashes |

## The five findings

| Issue | What is different | Cases | Cause |
|---|---|---|---|
| [#122](https://github.com/andersoxie/xpact/issues/122) | Malformed UTF-8: xpact reports the error at **1:0**, Expat at the bad byte (e.g. 1:3) | 3,096 | ❔ suspected: whole input checked before tokenizing |
| [#123](https://github.com/andersoxie/xpact/issues/123) | Malformed UTF-8: xpact gives **no events** before the error, Expat gives e.g. `start:r` | 598 | ❔ suspected: same place as #122 |
| [#124](https://github.com/andersoxie/xpact/issues/124) | `<root/>junk`: error **4** instead of **9**; column 7-10 depending on callbacks and chunks (Expat: always 7) | 72 | ❔ unknown |
| [#125](https://github.com/andersoxie/xpact/issues/125) | Default handler gets the mismatched `</root>` before the error | 21 | ❔ unknown |
| [#126](https://github.com/andersoxie/xpact/issues/126) | Default handler gets LF where the document has CR / CR LF (Expat passes raw text) | 38 | ❔ suspected: fed from the normalized input |

Not counted as differences:

- ✅ **Text divided differently** (2 cases): `hi` byte by byte arrives as `h` + `i`.
  Expat does not promise how character data is divided.
- ℹ️ **Which `XML_Parse` call reports the error** (649 chunked cases): xpact
  is sometimes one call later, sometimes earlier. Expat only promises the error
  by the final call, so this is recorded, not judged.

## The files

| File | What |
|---|---|
| [`summary.md`](summary.md) | all counts: per property, per group, chunk stability, one example per input |
| [`cases.tsv`](cases.tsv) | every case: both verdicts, codes, positions, failing call, events, the differences and the finding |
| [`compare.py`](compare.py) | makes `summary.md`, `cases.tsv` and the fixtures |
| [`runs/`](runs/) | the three runs: `summary.txt` each, `results.tsv` for Expat and xpact (the assertions one is identical) |
| [`../C03-chunks/`](../C03-chunks/README.md) | C03 view and its fixtures |
| [`../C10-utf8/`](../C10-utf8/README.md) | C10 view and its 42 UTF-8 fixtures |

## How to repeat

```powershell
# 1. Expat 2.8.1 as a DLL (build\ is not committed); the exact script: reports\issue-0121\expat-build.cmd
#    source: https://github.com/libexpat/libexpat/archive/refs/tags/R_2_8_1.tar.gz
#    (SHA-256 c999c8e5a345c70c7ebc2e1bcf5f156f98d363243f594660582691da0f423504)
cmake -S build\libexpat-R_2_8_1\libexpat-R_2_8_1\expat -B build\libexpat-R_2_8_1\build -G "NMake Makefiles" `
  -DCMAKE_BUILD_TYPE=Release -DEXPAT_BUILD_TESTS=OFF -DEXPAT_BUILD_TOOLS=OFF -DEXPAT_BUILD_EXAMPLES=OFF -DEXPAT_BUILD_DOCS=OFF
cmake --build build\libexpat-R_2_8_1\build      # in a VS x64 developer prompt

# 2. the same cases on each DLL
dotnet build tests\dotnet\XpactDllTests -c Release
$t = "build\dotnet\XpactDllTests\bin\Release\net10.0\XpactDllTests.exe"
& $t --dll build\libexpat-R_2_8_1\build\libexpat.dll --out build\w5-121\libexpat
& $t --dll build\native-eiffel\xpact.dll            --out build\w5-121\xpact
& $t --dll build\native-eiffel\xpact_assertions.dll --out build\w5-121\xpact_assertions

# 3. compare
python -I student\results\expat-2.8.1\compare.py --expat build\w5-121\libexpat --xpact build\w5-121\xpact
```

Expat was built with the upstream defaults (`XML_DTD`, `XML_GE`, `XML_NS` on,
context bytes 1024); the full configuration is in
[`expat-build.txt`](../../../reports/issue-0121/expat-build.txt).

## Limitations

- Small inputs only: the C02 matrix, 4 CR inputs and 48 UTF-8 inputs (C10 part).
  Larger documents and the W3C suite are compared in G03 (week 7).
- Only the start, end, character-data and default handlers are tested.
- "Expected" here means "what Expat 2.8.1 does". Where Expat's behaviour is a
  choice rather than a rule of the XML spec (positions, the default handler's
  raw text), a difference is a compatibility finding, not a conformance error.
- The causes of the findings are not traced; parser repairs (C08) stay with
  the experienced developers.
