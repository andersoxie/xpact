# Find the Python interpreter for the benchmark scripts (#308).
#   $env:XPACT_PYTHON  - full path to python.exe, used if set
#   otherwise          - `python` from PATH, but not the Microsoft Store alias in ...\WindowsApps\,
#                        which only prints "Python was not found" and fails late in a run.
# Dot-source this file, then call Resolve-XpactPython early, before any long build step.

function Resolve-XpactPython {
	$Candidate = $env:XPACT_PYTHON
	if ([string]::IsNullOrWhiteSpace($Candidate)) {
		$Command = Get-Command python -ErrorAction SilentlyContinue
		if ($null -eq $Command) {
			throw "Python not found. Put python on PATH or set XPACT_PYTHON to the full path of python.exe."
		}
		$Candidate = $Command.Source
		if ($Candidate -match "\\WindowsApps\\") {
			throw "python on PATH is the Microsoft Store alias ($Candidate), not an interpreter. Install Python, put it before WindowsApps on PATH, or set XPACT_PYTHON to the full path of python.exe."
		}
	} elseif (-not (Test-Path -LiteralPath $Candidate -PathType Leaf)) {
		throw "XPACT_PYTHON points to '$Candidate', which does not exist."
	}
	$Version = & $Candidate -c "import sys; print(sys.version.split()[0])" 2>$null
	if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($Version)) {
		throw "Python at '$Candidate' does not run. Set XPACT_PYTHON to a working python.exe."
	}
	return $Candidate
}
