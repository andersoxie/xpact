# Incremental Shim Audit

This audit records the current native chunk adapter behavior before replacing
the accumulated-buffer replay path with a true incremental parser session.

It is intentionally a focused native API audit, not a claim that the production
parser has already stopped using replay internally. Rows classified as
`current_gap` identify expected observations that should guide the
incremental-core design; the current audit rows are green.

## Run

```powershell
.\scripts\run_incremental_shim_audit.ps1 -SkipBuild
```

Without `-SkipBuild`, the script first rebuilds the Eiffel-backed Windows DLL.
The output is written to:

```text
build\incremental-shim-audit\incremental-shim-audit.tsv
```

## Current Observations

The audit covers these native API behaviors:

| Case | Classification | Current observation |
|---|---|---|
| `plain_start_nonfinal` | `passes` | A completed plain start tag in a non-final `XML_Parse` chunk emits a start callback and leaves the parser in `XML_PARSING`. |
| `parse_buffer_plain_start_nonfinal` | `passes` | The same plain start-tag case works through `XML_GetBuffer` / `XML_ParseBuffer`. |
| `attributed_start_nonfinal` | `passes` | A completed attributed start tag with literal attribute values emits its start callback on the non-final chunk. |
| `attributed_start_nonfinal_without_reparse_deferral` | `passes` | Disabling reparse deferral makes that attributed start callback arrive on the non-final chunk. |
| `input_context_uses_bounded_window` | `passes` | Callback-time `XML_GetInputContext` returns a bounded context window instead of the full accumulated prefix. |
| `suspend_resume_replay` | `passes` | A resumable stop from a character-data callback can be resumed without duplicating delivered character data. |

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
