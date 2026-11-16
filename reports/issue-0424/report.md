# #424: CodeQL log forging in WorkerRunner.cs

> Issue [#424](https://github.com/andersoxie/xpact/issues/424) · branch `fix/424-log-forging` from `incremental-test` @ `5ba4a88` · 2026-11-16

## Problem
CodeQL (`cs/log-forging`, medium) reported 2 open alerts: a value that can come from a visitor is written to the server log.
A line break in such a value would add a fake line to the log.

| Alert | Line | Values |
|---|---|---|
| [#1](https://github.com/andersoxie/xpact/security/code-scanning/1) | `WorkerRunner.cs:80` | `request.Client`, `request.Build` |
| [#2](https://github.com/andersoxie/xpact/security/code-scanning/2) | `WorkerRunner.cs:224` | `request.Build`, the worker's error output |

## Environment
Windows 11 Home, .NET 10 SDK, DLLs `xpact.dll` `32171ECD…` / `xpact_assertions.dll` `4B224D0A…` (built 2026-11-16 from `0c7e114`).

## Investigation
- `Build` is checked against the list of builds before use (`ApiEndpoints.cs:99`); CodeQL does not see that check.
- `Client` is `Connection.RemoteIpAddress.ToString()`, an IP address.
- The worker's error output is free text; whether it can repeat text from the uploaded document was not checked.

## Cause
- `Build`, `Client`: ❓ suspected false positives.
- Worker error output: ❔ unknown whether it can carry visitor text.

## Fix
New `LogText.OneLine` (`website/backend/src/Xpact.Api/LogText.cs`): line breaks become ` | `, any other control character becomes `?`.
Used for every visitor-dependent value in `WorkerRunner.cs` (lines 67, 79-81, 225). This closes both alerts whatever the answer to the open question above.

## Verification

| Check | Expected | Observed |
|---|---|---|
| `website\scripts\test.ps1` | all pass | ✅ **56 / 56** (48 before + 8 new in `LogTextTests.cs`), frontend build OK |
| New tests | `\r\n`, `\r`, `\n` → ` | `; other control characters → `?`; null → empty; no control character left | ✅ all pass |
| CodeQL on the PR, first version | 0 `cs/log-forging` alerts | ❌ still 2: the empty-input shortcut returned the input itself, so CodeQL saw an uncleaned path |
| CodeQL on the PR, after `4806915` | 0 `cs/log-forging` alerts | ✅ **0** (C# analysis of the PR merge commit: 0 results) |

Log: [test-424.txt](test-424.txt).
