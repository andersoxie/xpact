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
**In short:** before a visitor-related value is written to the server log, a new helper puts it on one line. Line breaks become ` | ` and other hidden characters become `?`. A visitor can then never add a fake line to the log.

*Illustration (made up, not a real log):*

**Before:** a value with a line break could add a fake line to the log.
```
info: Parsed 120 bytes from 1.2.3.4 with production: Valid in 5 ms
info: Admin logged in          ← fake line, typed by a visitor
```

**After:** the same value stays on its own line, so the fake text is easy to spot.
```
info: Parsed 120 bytes from 1.2.3.4 with production | info: Admin logged in: Valid in 5 ms
```

**What changed:**

| File | Change |
|---|---|
| `website/backend/src/Xpact.Api/LogText.cs` (new) | `LogText.OneLine(value)`: line breaks → ` \| `, other control characters → `?`; an empty or missing value → `""` |
| `website/backend/src/Xpact.Api/Workers/WorkerRunner.cs` | The 3 log lines that write a visitor value (client, build, the worker's error text; lines 67, 79-81, 225) now pass it through `LogText.OneLine` |
| `website/backend/tests/Xpact.Api.Tests/LogTextTests.cs` (new) | 8 tests: normal text unchanged; `\r\n`, `\r`, `\n` turned into ` \| `; tabs, bell and color codes turned into `?`; no control character left |

**Why it fixes both alerts, whatever the cause turns out to be:** the alerts are only suspected false alarms, so the fix doesn't rely on that. Every value now gets cleaned before it reaches the log.

**One mistake on the way:** in the first version, an empty value was handed back unchanged, so CodeQL still saw an uncleaned path and kept both alerts. The second commit (`4806915`) returns a new empty string instead, and CodeQL then found 0 alerts.

Pull request: [#427](https://github.com/andersoxie/xpact/pull/427) (merge commit `4c958cb`).

## Verification

| Check | Expected | Observed |
|---|---|---|
| `website\scripts\test.ps1` | all pass | ✅ **56 / 56** (48 before + 8 new in `LogTextTests.cs`), frontend build OK |
| New tests | `\r\n`, `\r`, `\n` → ` | `; other control characters → `?`; null → empty; no control character left | ✅ all pass |
| CodeQL on the PR, first version | 0 `cs/log-forging` alerts | ❌ still 2: the empty-input shortcut returned the input itself, so CodeQL saw an uncleaned path |
| CodeQL on the PR, after `4806915` | 0 `cs/log-forging` alerts | ✅ **0** (C# analysis of the PR merge commit: 0 results) |

Log: [test-424.txt](test-424.txt).
