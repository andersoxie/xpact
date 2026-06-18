# Chunked Parse CRC Harness

`tests/native/xpact_chunked_crc.c` is an expat-compatible C harness for
measuring whether repeated `XML_Parse` calls over different chunk sizes produce
the same parse event stream.

The same source can be compiled in two ways:

- against `include/xpact.h` and the Eiffel-backed Windows `xpact.dll`;
- against system libexpat by defining `XPACT_USE_SYSTEM_EXPAT`.

The harness records two CRC-32 values per run:

- `semantic_crc` digests start-element names, attributes, end-element names,
  and character data while coalescing adjacent character-data callbacks;
- `trace_crc` also records character-data callback boundaries, so it can expose
  callback splitting differences that are legal but still useful to inspect.

The semantic CRC is the release-facing value. If chunk sizes change parser
callback boundaries but not XML meaning, `semantic_crc` should stay stable.

## Run Against xpact

Build or reuse the Eiffel-backed Windows DLL, compile the harness with MSVC,
and run both direct bytes and `XML_GetBuffer` / `XML_ParseBuffer` modes:

```powershell
.\scripts\run_chunked_crc_harness.ps1 `
  -Target Xpact `
  -ParseMode All `
  -Repeat 100
```

The script writes:

```text
build\chunked-crc\chunked-crc-results.tsv
```

By default, any semantic mismatch makes the script fail. To collect diagnostic
rows while investigating a suspected mismatch:

```powershell
.\scripts\run_chunked_crc_harness.ps1 `
  -Target Xpact `
  -ParseMode All `
  -Repeat 100 `
  -AllowMismatches
```

## Run Against libexpat

When WSL has a distro with `gcc` and libexpat development headers installed,
the same script can compile the harness against system libexpat:

```powershell
.\scripts\run_chunked_crc_harness.ps1 `
  -Target LibexpatWsl `
  -ParseMode All
```

To run both engines and compare shared rows:

```powershell
.\scripts\run_chunked_crc_harness.ps1 `
  -Target All `
  -ParseMode All
```

## Run Real Documents

Use `-XmlFile` for caller-supplied XML. Files are read as bytes and fed through
the same chunk matrix:

```powershell
.\scripts\run_chunked_crc_harness.ps1 `
  -Target Xpact `
  -XmlFile C:\data\sample.xml `
  -ParseMode All
```

Use `-ChunkSizes` to focus on suspicious split points:

```powershell
.\scripts\run_chunked_crc_harness.ps1 `
  -Target Xpact `
  -ChunkSizes 1,2,31,64,whole `
  -AllowMismatches
```

## Regression Case

The first local run against the previous Eiffel-backed Windows DLL found a
silent semantic mismatch in both direct and parse-buffer modes:

- generated catalog document, 564 bytes;
- chunk size 31;
- status `OK`, error `XML_ERROR_NONE`;
- expected `semantic_crc` `01b319c0`, observed `59836860`;
- expected text bytes 121, observed 99.

The root cause was native replay suppression for character data. The adapter
suppressed the first N replay callbacks, but a previously delivered text
callback can grow when later chunks arrive. The fix tracks delivered
character-data length by callback sequence index and emits only the new suffix
on replay.

This case is now a strict harness gate:

```powershell
.\scripts\run_chunked_crc_harness.ps1 `
  -Target Xpact `
  -ParseMode All `
  -Repeat 10
```
