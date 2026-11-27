# Incremental Shim Audit

This audit records native chunk-adapter behavior shared by the production
checkpoint-resume path and its replay fallbacks.

The adapter resumes from a checkpoint for eligible input and uses
accumulated-buffer replay for input the checkpoint cannot handle.
Each of the eleven cases below requires the observed public API behavior.
The October validation covers the original six cases.
[Incremental resume](incremental-resume.md) · [October validation](../reports/issue-0104/report.md)

On 24 November 2026 both Windows DLLs passed all eleven cases. Native
libexpat 2.8.1 passed the five Latin-1 cases that check raw positions, reference
and CDATA callbacks, and state across successive uses of one parser.
[Per-case results](../reports/windows-dll-latin1-checkpoint-2026-11-24/native-audit.tsv)

## Run

```powershell
.\scripts\run_incremental_shim_audit.ps1 -SkipBuild
```

Without `-SkipBuild`, the script first rebuilds the Eiffel-backed Windows DLL.
The output is written to:

```text
build\incremental-shim-audit\incremental-shim-audit.tsv
```

## Covered behaviors

The audit covers these native API behaviors:

| Case | Required classification | Expected observation |
|---|---|---|
| `plain_start_nonfinal` | `passes` | A completed plain start tag in a non-final `XML_Parse` chunk emits a start callback and leaves the parser in `XML_PARSING`. |
| `parse_buffer_plain_start_nonfinal` | `passes` | The same plain start-tag case works through `XML_GetBuffer` / `XML_ParseBuffer`. |
| `attributed_start_nonfinal` | `passes` | A completed attributed start tag with literal attribute values emits its start callback on the non-final chunk. |
| `attributed_start_nonfinal_without_reparse_deferral` | `passes` | Disabling reparse deferral makes that attributed start callback arrive on the non-final chunk. |
| `input_context_uses_bounded_window` | `passes` | Callback-time `XML_GetInputContext` returns a bounded context window instead of the full accumulated prefix. |
| `suspend_resume_replay` | `passes` | A resumable stop from a character-data callback can be resumed without duplicating delivered character data. |
| `latin1_explicit_chunked` | `passes` | With explicit ISO-8859-1, callbacks receive UTF-8 values and report raw byte spans and character columns across a split CRLF and suspension. An empty final chunk completes the resumed document. |
| `latin1_mismatch_after_reset` | `passes` | After reset and `XML_SetEncoding`, a mismatched closing name following a high byte reports `XML_ERROR_TAG_MISMATCH` at the original byte and column. |
| `latin1_declared_parse_buffer_after_failure` | `passes` | Reset restores UTF-8 defaults and rejects an isolated Latin-1 high byte. A second reset accepts a split ISO-8859-1 declaration through `XML_ParseBuffer`, with fresh callback positions and raw input context. |
| `latin1_reference_and_cdata_spans` | `passes` | Text callbacks report the raw spans of split text, named and numeric references, and a CRLF split across an empty non-final call. CDATA boundary callbacks point to the opening and closing delimiters. |
| `latin1_default_spans` | `passes` | For one-byte chunks, the default handler receives the complete document in UTF-8. Each callback points to its original bytes in `XML_GetInputContext`, including adjacent high bytes and markup. |

## Design Implications

The true incremental session should keep the passing API behavior while
removing the remaining internal replay dependency:

- completed tokens should keep being emitted as soon as the token is complete;
- `XML_GetInputContext` should keep using a bounded context window;
- `XML_SetReparseDeferralEnabled` should control Expat-compatible deferral
  policy, not compensate for a whole-prefix parser architecture;
- `XML_ResumeParser` should continue from suspended state directly instead of
  replaying suppressed callbacks.

External entity child parsers are covered by the broader native DLL smoke tests
today. They still need a dedicated row in this audit before the production
incremental session replaces the shim.
