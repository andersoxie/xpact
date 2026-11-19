# Find the Python interpreter for the benchmark scripts (#308).
# Order: $env:XPACT_PYTHON; `python` on PATH unless it is the Microsoft Store alias (...\WindowsApps\, which only
# prints "Python was not found"); the `py` launcher; uv-managed interpreters; the standard per-user install folder.
# Dot-source this file, then call Resolve-XpactPython early, before any long build step.

function Test-XpactPython([string] $Candidate) {
	if ([string]::IsNullOrWhiteSpace($Candidate) -or -not (Test-Path -LiteralPath $Candidate -PathType Leaf)) { return $false }
	$Version = & $Candidate -c "import sys; print(sys.version.split()[0])" 2>$null
	return ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($Version))
}

function Resolve-XpactPython {
	if (-not [string]::IsNullOrWhiteSpace($env:XPACT_PYTHON)) {
		if (Test-XpactPython $env:XPACT_PYTHON) { return $env:XPACT_PYTHON }
		throw "XPACT_PYTHON points to '$($env:XPACT_PYTHON)', which does not exist or does not run."
	}
	$Candidates = New-Object System.Collections.Generic.List[string]
	$Command = Get-Command python -ErrorAction SilentlyContinue
	if ($Command -and $Command.Source -notmatch "\\WindowsApps\\") { $Candidates.Add($Command.Source) }
	$Launcher = Get-Command py -ErrorAction SilentlyContinue
	if ($Launcher) {
		$FromLauncher = & $Launcher.Source -3 -c "import sys; print(sys.executable)" 2>$null
		if ($LASTEXITCODE -eq 0 -and $FromLauncher) { $Candidates.Add($FromLauncher.Trim()) }
	}
	foreach ($Pattern in @("$env:APPDATA\uv\python\cpython-3*\python.exe", "$env:LOCALAPPDATA\Programs\Python\Python3*\python.exe")) {
		Get-ChildItem -Path $Pattern -ErrorAction SilentlyContinue | Sort-Object FullName -Descending |
			ForEach-Object { $Candidates.Add($_.FullName) }
	}
	foreach ($Candidate in $Candidates) {
		if (Test-XpactPython $Candidate) { return $Candidate }
	}
	throw "No working Python found (python on PATH is missing or the Microsoft Store alias). Install Python or set XPACT_PYTHON to the full path of python.exe."
}
