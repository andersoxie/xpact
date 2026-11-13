# Incremental Shim Audit

This audit records native chunk-adapter behavior shared by the production
checkpoint-resume path and its replay fallbacks.

It is intentionally a focused native API audit, not a claim that the production
parser has already stopped using replay internally. Since mass-xpact #2 the
adapter resumes from a checkpoint and replays only as a fallback
([incremental-resume.md](incremental-resume.md)); all rows are unchanged by it. Rows classified as
`current_gap` identify expected observations that should guide the
incremental-core design. The six current cases all require `passes` outcomes.
The [recorded October validation](../reports/issue-0104/report.md) includes a
successful shim-audit run; this documentation update does not rerun the DLL.

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
