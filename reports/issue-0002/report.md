# Fix report: issue #2, "Cannot find Eiffel runtime include directory"

Issue: [#2](https://github.com/andersoxie/xpact/issues/2)   Branch: `student-Mass`   Date: 2026-10-20
Error report: [error-reports/2026-10-19.md](../error-reports/2026-10-19.md), error 1

## Summary

| Item | Value |
|---|---|
| Script | `scripts\build_native_eiffel.ps1` |
| Chosen fix | Option 3: change the hard-coded fallback path |
| Changed | One line, `scripts\build_native_eiffel.ps1:42` |
| Result | The include-directory error is gone. The build now stops at a different, already-known error (see [Verification](#verification)). |

## Cause

`Get-IseInclude` (`scripts\build_native_eiffel.ps1:35-47`) looks for the Eiffel
runtime headers in two places:

1. `$env:ISE_EIFFEL\studio\spec\win64\include`. `ISE_EIFFEL` is not set on this PC.
2. The hard-coded fallback `C:\El2502E\studio\spec\win64\include`. This folder
   does not exist; it comes from a different install (EiffelStudio 25.02 Enterprise).

EiffelStudio is installed at
`C:\Program Files\Eiffel Software\EiffelStudio 25.12 Standard`, so both checks
fail and the script stops with `throw "Cannot find Eiffel runtime include directory."`

## Options

There are four ways to fix it, from quickest to most lasting.

### Option 1: set `ISE_EIFFEL` for the current window (no code change)

```powershell
$env:ISE_EIFFEL = "C:\Program Files\Eiffel Software\EiffelStudio 25.12 Standard"
.\scripts\build_native_eiffel.ps1
```

- **Good:** no code change; the script already supports `ISE_EIFFEL`.
- **Bad:** it is lost when the window closes, and has to be repeated every time.

### Option 2: set `ISE_EIFFEL` permanently for the user (no code change)

```powershell
[Environment]::SetEnvironmentVariable("ISE_EIFFEL", "C:\Program Files\Eiffel Software\EiffelStudio 25.12 Standard", "User")
```

Then open a new PowerShell window.

- **Good:** no code change; it also fixes `run_native_runtime_smoke.ps1`, which
  has the same lookup.
- **Bad:** it only fixes this PC, and nothing in the repository records that it
  is needed.

### Option 3: change the hard-coded fallback path (chosen)

In `scripts\build_native_eiffel.ps1`, line 42:

```diff
-	$Fallback = "C:\El2502E\studio\spec\win64\include"
+	$Fallback = "C:\Program Files\Eiffel Software\EiffelStudio 25.12 Standard\studio\spec\win64\include"
```

`ISE_EIFFEL` still takes priority when it is set.

- **Good:** one-line change; works in every new window without setup. This
  is the same fix used in week 1
  (`student/history/xpact-error-report.md` §3.1), and the `xpact-main` copy
  already has it.
- **Bad:** it only works on PCs with exactly this install path. Any other
  EiffelStudio version or folder fails again.

### Option 4: search for the installation (most robust)

Replace the fallback with a search of the standard install folders. This version
already exists in another local copy,
`xpact\xpactVsCode\xpact\scripts\build_native_eiffel.ps1:19-53`:

```powershell
function Get-IseInclude {
    if (-not [string]::IsNullOrWhiteSpace($env:ISE_EIFFEL)) {
        $Candidate = Join-Path $env:ISE_EIFFEL "studio\spec\win64\include"
        if (Test-Path -LiteralPath $Candidate -PathType Container) {
            return $Candidate
        }
    }

    $InstallRoots = @(
        "C:\Program Files\Eiffel Software",
        "C:\Program Files (x86)\Eiffel Software"
    )

    foreach ($Root in $InstallRoots) {
        if (Test-Path -LiteralPath $Root -PathType Container) {
            $Installations = Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "EiffelStudio *" }

            foreach ($Installation in $Installations) {
                $Candidate = Join-Path $Installation.FullName "studio\spec\win64\include"

                if (Test-Path -LiteralPath $Candidate -PathType Container) {
                    return $Candidate
                }
            }
        }
    }

    $Fallback = "C:\El2502E\studio\spec\win64\include"
    if (Test-Path -LiteralPath $Fallback -PathType Container) {
        return $Fallback
    }

    throw "Cannot find Eiffel runtime include directory."
}
```

- **Good:** works on any PC with a standard EiffelStudio install, of any
  version; keeps `ISE_EIFFEL` and the old fallback.
- **Bad:** bigger change. If several versions are installed, it picks the first
  one found, which may not match the `ec` on PATH. Getting the path from the
  location of `ec.exe` would avoid that.

### Comparison

| | Code change | Survives a new window | Works on other PCs |
|---|---|---|---|
| 1. `ISE_EIFFEL` for the window | No | No | Yes, if set there |
| 2. `ISE_EIFFEL` for the user | No | Yes | Yes, if set there |
| **3. New fallback path** | 1 line | Yes | Only with the same install path |
| 4. Search install folders | ~25 lines | Yes | Yes, with a standard install |

**Recommendation:** option 3 is enough to keep working on this PC. Option 4 is
the one to propose for `main`.

## Verification

Command, run on 2026-10-20 in a fresh PowerShell process with `ISE_EIFFEL`
unset (PATH length 1,038):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\build_native_eiffel.ps1
```

Full log: [build-log.txt](build-log.txt). Exit status: 1.

**Result:** "Cannot find Eiffel runtime include directory" no longer appears.
`Get-IseInclude` returned the new path, and the script went on to the first
`cl` call in `Invoke-VcCommand`. It then failed with a different error:

```text
Loaded Visual Studio C++ x64 environment from C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat
cmd.exe : 'vswhere.exe' is not recognized as an internal or external command,
At ...\scripts\build_native_eiffel.ps1:52 char:12
+     $Output = cmd.exe /c "`"$VcVars`" >nul && $Command" 2>&1
```

So the fix for issue #2 works, but the DLL is not built yet. The new error is
not part of this issue.

## Next blocker (not fixed here)

The `'vswhere.exe' is not recognized` error is already known:

- **Cause:** `vcvars64.bat` writes a harmless warning to stderr. Line 52 sends
  stderr into PowerShell (`2>&1`) while `$ErrorActionPreference = "Stop"`, so
  Windows PowerShell 5.1 turns the warning into a fatal error.
- **Known fix:** run the native calls under `Continue` and check
  `$LASTEXITCODE`. See `student/history/xpact-error-report.md` §4.4 and
  `student/history/patches/01-week1-build-fixes.patch`.
- **Later errors from week 1:** the same patch also fixes the missing `.lnk`
  link response file (`msc_vc140` backend), the precompile problem and the
  stale `ec.lock`. It is tracked in draft issue 22 (build fixes not in `main`).

## Also affected

`scripts\run_native_runtime_smoke.ps1:40` has the same `C:\El2502E` fallback
and will fail the same way. It is not changed here. Options 1, 2 and 4 would
cover it too.
