# EMAIL_RECIPIENTS: Declarative compilation follow-up

Related issue: [#90](https://github.com/andersoxie/xpact/issues/90).
Date: 2026-10-25. Branch: `codex/fix-email-parameter-default`.
Base revision: `18a4444` (the merge of email notification PR #91).

## Problem and cause

Starting the Windows Jenkins pipeline fails while compiling
`ci/Jenkinsfile.windows-phase1`, before stages start. The same parameter
definition is present in `ci/Jenkinsfile.all-tests`.

Expected: Jenkins loads the pipeline and makes `EMAIL_RECIPIENTS` available.
Observed: the Declarative parser rejects the bare method call in the default:

```groovy
defaultValue: (params.EMAIL_RECIPIENTS ?: '').trim(),
```

The reported diagnostic is `Expected a symbol` at line 705. The earlier
notification tests used ordinary Groovy with stubbed Pipeline steps, so they
did not cover this stricter parsing layer.

The correction quotes the calculation as a Groovy interpolated string in both
files:

```groovy
defaultValue: "${(params.EMAIL_RECIPIENTS ?: '').trim()}",
```

Recipient handling still starts empty, retains a submitted value, and allows
clearing it. Notification timing and delivery behavior are unchanged.

## Expected validation results

- The installed Declarative parser rejects a fixture with the original default
  and accepts the quoted default.
- Both corrected complete Jenkinsfiles pass the same offline parsing check.
- All 19 existing notification scenarios pass, including retaining, clearing,
  and re-adding recipients across successive build results.
- No Pipeline steps or SMTP requests execute during these checks.

## Verification

Environment: Windows, Jenkins 2.580.1 libraries, Declarative plugin
`2.2293.v6e7193cec599`, Groovy 2.4.21, Temurin Java 25.0.4.1. Java assertions
were enabled; Groovy assertions remained active. Eiffel build mode and
`ISE_C_COMPILER` do not apply to this parsing-only correction.

The installed `Converter.compilationUnitToPipelineDef`, `ModelParser`, and
`ModelValidatorImpl` rejected the original expression and accepted the corrected
fixture and both complete Jenkinsfiles. The offline process supplies metadata
from the installed agent, parameter, and option descriptor classes because no
live Jenkins instance loads its extension list. It does not replace parser or
validator logic or ignore validation errors.
An unknown parameter type was also rejected, checking that model validation
remains active. The runner passed under both PowerShell 7 and Windows
PowerShell 5; Java deprecation warnings were displayed without hiding a
nonzero process exit.

The existing 19 behavior scenarios also passed against both corrected complete
Jenkinsfiles. They cover result filtering, recipient lifecycle, notification
contents, publication ordering, delivery errors, and interruption propagation.
An independent read-only review found no actionable issue in the two-line
correction.

Reproducible command from the repository root:

```powershell
.\scripts\test_jenkins_pipelines.ps1 `
  -JenkinsWarDirectory 'C:\Users\ander\AppData\Local\Jenkins\war' `
  -JenkinsPluginsDirectory 'C:\Users\ander\AppData\Local\Jenkins\.jenkins\plugins' `
  -JavaPath 'C:\Program Files\Eclipse Adoptium\jdk-25.0.4.101-hotspot\bin\java.exe'
```

| Check | Original default | Corrected default |
|---|---|---|
| Minimal Declarative regression fixture | Rejected: `Expected a symbol` | Accepted |
| Both complete Jenkinsfiles, offline Declarative parsing | Windows failure reported; all-tests not rerun before the fix | Accepted |
| Existing notification behavior suite | Previously passed despite this bug | 19 scenarios passed |

The complete runner transcript is saved in [validation.txt](validation.txt).

## Limitations

Offline parsing and stubbed behavior checks do not prove actual Jenkins job
parameter persistence, runtime step or SCM descriptors, plugin validator
contributors, CPS execution, or SMTP delivery. No live Jenkins build or email
delivery was run for this follow-up.

## Revert

Revert the fix commit on a branch. This restores the rejected parameter
expression, so a Jenkins build will fail before executing stages again.
