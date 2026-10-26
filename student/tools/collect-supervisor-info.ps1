# Collects, into one text file, what the student needs from the supervisor's
# machine for the open dual-implementation steps (newUpdates.txt) and for the
# Jenkins checks of #74 and #79 (issue #140).
#
# Read-only by default: it reads tools, the repository, local build results,
# Jenkins build logs and WSL. It changes no file, setting or Jenkins job. Only
# -RunDualLanes runs something (the two dual lanes, into new build folders).
#
# Usage, in Windows PowerShell from the repository root:
#   powershell -NoProfile -ExecutionPolicy Bypass -File student\tools\collect-supervisor-info.ps1
# Options:
#   -JenkinsHome <dir>      Jenkins home (default: $env:JENKINS_HOME, else %LOCALAPPDATA%\Jenkins\.jenkins)
#   -MaxBuilds <n>          newest builds per xpact Jenkins job (default 3)
#   -LargeXml <files>       large XML corpus files to describe (size and SHA-256)
#   -RunDualLanes           also run run_dual_catalog.ps1 and run_dual_w3c.ps1 (-Offline) and include the results
#   -Output <file>          default: Desktop\xpact-supervisor-info-<date>.txt
# Send the output file to the student. E-mail addresses are masked.
param(
	[string] $RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
	[string] $JenkinsHome = "",
	[int] $MaxBuilds = 3,
	[string[]] $LargeXml = @(),
	[switch] $RunDualLanes,
	[string] $Output = ""
)

Set-StrictMode -Version 2
# With -File, "-LargeXml a.xml,b.xml" arrives as one string; split it.
$LargeXml = @($LargeXml | ForEach-Object { $_ -split "," } | Where-Object { $_ -ne "" })
$ErrorActionPreference = "Continue"

if ([string]::IsNullOrWhiteSpace($Output)) {
	$Output = Join-Path ([Environment]::GetFolderPath("Desktop")) ("xpact-supervisor-info-{0}.txt" -f (Get-Date -Format "yyyy-MM-dd-HHmm"))
}
if ([string]::IsNullOrWhiteSpace($JenkinsHome)) {
	if (-not [string]::IsNullOrWhiteSpace($env:JENKINS_HOME)) {
		$JenkinsHome = $env:JENKINS_HOME
	} else {
		$JenkinsHome = Join-Path $env:LOCALAPPDATA "Jenkins\.jenkins"
	}
}

$Lines = New-Object System.Collections.Generic.List[string]

function Add-Line([string] $Text) {
	# Jenkins console notes and colour codes are dropped; e-mail addresses are masked.
	$Text = [regex]::Replace($Text, "\x1b\[8mha:[^\x1b]*\x1b\[0m", "")
	$Text = [regex]::Replace($Text, "\x1b\[[0-9;]*m", "")
	$Masked = [regex]::Replace($Text, "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", "<email>")
	$Lines.Add($Masked)
}

function Add-Section([string] $Title) {
	Add-Line ""
	Add-Line ("=" * 78)
	Add-Line $Title
	Add-Line ("=" * 78)
}

function Add-Command([string] $Label, [scriptblock] $Block) {
	# Runs a read-only command and records its output, or the error.
	Add-Line ("--- {0}" -f $Label)
	try {
		$Result = & $Block 2>&1 | ForEach-Object {
			if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ }
		} | Out-String
		foreach ($Line in ($Result.TrimEnd() -split "`r?`n")) {
			Add-Line ("    " + $Line)
		}
	} catch {
		Add-Line ("    (failed: {0})" -f $_.Exception.Message)
	}
}

function Add-File([string] $Path, [int] $MaxChars = 6000) {
	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		Add-Line ("    (not found: {0})" -f $Path)
		return
	}
	$Text = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
	if ($null -eq $Text) { $Text = "" }
	if ($Text.Length -gt $MaxChars) {
		$Text = $Text.Substring(0, $MaxChars) + "`n... (cut at $MaxChars characters)"
	}
	Add-Line ("--- file: {0}" -f $Path)
	foreach ($Line in ($Text.TrimEnd() -split "`r?`n")) {
		Add-Line ("    " + $Line)
	}
}

function Get-Tool([string] $Name) {
	$Command = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
	if ($null -eq $Command) { return $null }
	return $Command.Source
}

function Add-NewestRuns([string] $Root, [string] $Filter, [int] $Count, [string[]] $Files) {
	# The newest run folders under $Root (relative to the repository) whose name matches $Filter.
	$RootPath = Join-Path $RepoRoot $Root
	if (-not (Test-Path -LiteralPath $RootPath)) {
		Add-Line ("    (not found: {0})" -f $RootPath)
		return
	}
	$Dirs = @(Get-ChildItem -LiteralPath $RootPath -Directory -Filter $Filter -ErrorAction SilentlyContinue)
	if ($Dirs.Count -eq 0 -and $Filter -eq "*") {
		$Dirs = @(Get-Item -LiteralPath $RootPath)
	}
	if ($Dirs.Count -eq 0) {
		Add-Line ("    (no runs matching {0} in {1})" -f $Filter, $RootPath)
		return
	}
	foreach ($Dir in ($Dirs | Sort-Object LastWriteTime -Descending | Select-Object -First $Count)) {
		Add-Line ("run: {0}  ({1})" -f $Dir.FullName, $Dir.LastWriteTime.ToString("yyyy-MM-dd HH:mm"))
		foreach ($Name in $Files) {
			$Found = @(Get-ChildItem -LiteralPath $Dir.FullName -Recurse -File -Filter $Name -ErrorAction SilentlyContinue | Select-Object -First 2)
			foreach ($File in $Found) { Add-File $File.FullName 4000 }
		}
	}
}

# --------------------------------------------------------------------------
Add-Line "xpact supervisor information (issue #140)"
Add-Line ("Collected: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"))
Add-Line ("Script:    {0}" -f $PSCommandPath)
Add-Line ("Options:   MaxBuilds={0} LargeXml={1} RunDualLanes={2}" -f $MaxBuilds, $LargeXml.Count, [bool] $RunDualLanes)

Add-Section "1. Machine and tools (#74, step 1)"
Add-Line ("Windows:    {0}" -f [Environment]::OSVersion.VersionString)
Add-Line ("PowerShell: {0}" -f $PSVersionTable.PSVersion)
foreach ($Name in @("ISE_EIFFEL", "ISE_PLATFORM", "ISE_C_COMPILER", "ISE_LIBRARY")) {
	$Values = foreach ($Scope in @("Process", "User", "Machine")) {
		"{0}={1}" -f $Scope, [Environment]::GetEnvironmentVariable($Name, $Scope)
	}
	Add-Line ("{0,-15} {1}" -f $Name, ($Values -join "  "))
}
foreach ($Tool in @("ec", "finish_freezing", "cl", "python", "py", "git", "dotnet", "cmake", "wsl")) {
	$Path = Get-Tool $Tool
	if ($null -eq $Path) { $Path = "(not on PATH)" }
	Add-Line ("{0,-15} {1}" -f $Tool, $Path)
}
if (Get-Tool "ec") { Add-Command "ec -version" { ec -version } }
if (Get-Tool "py") { Add-Command "py -0" { py -0 } }
if (Get-Tool "python") { Add-Command "python --version" { python --version } }
if (Get-Tool "git") { Add-Command "git --version" { git --version } }
if (Get-Tool "dotnet") { Add-Command "dotnet --list-sdks" { dotnet --list-sdks } }
$VsWhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path -LiteralPath $VsWhere) {
	Add-Command "vswhere (installations)" { & $VsWhere -all -products * -format text -property displayName }
	Add-Command "vswhere (installation paths)" { & $VsWhere -all -products * -property installationPath }
}

Add-Section "2. Repository"
Add-Line ("Path: {0}" -f $RepoRoot)
if (Test-Path -LiteralPath (Join-Path $RepoRoot ".git")) {
	Add-Command "branch and commit" { git -C $RepoRoot log -1 --format="%H %cd %s" --date=iso; git -C $RepoRoot rev-parse --abbrev-ref HEAD }
	Add-Command "local changes (count)" { (git -C $RepoRoot status --porcelain | Measure-Object).Count }
	Add-Command "remotes" { git -C $RepoRoot remote -v }
	Add-Command "student-Mass in this checkout?" { git -C $RepoRoot log -1 --format="%h %s" --grep="#138" }
} else {
	Add-Line "    (not a git checkout)"
}

Add-Section "3. Pinned Xpact-core checkout (steps 1, 4, 6)"
$Lock = Join-Path $RepoRoot "dependencies\xpact-core.json"
Add-File $Lock 2000
$CoreCache = Join-Path $RepoRoot "build\dependencies\xpact-core"
if (Test-Path -LiteralPath $CoreCache) {
	foreach ($Dir in (Get-ChildItem -LiteralPath $CoreCache -Directory -ErrorAction SilentlyContinue)) {
		Add-Line ("checkout: {0}" -f $Dir.FullName)
		if (Test-Path -LiteralPath (Join-Path $Dir.FullName ".git")) {
			Add-Command "  HEAD" { git -C $Dir.FullName log -1 --format="%H %cd %s" --date=iso }
			Add-Command "  status (count)" { (git -C $Dir.FullName status --porcelain | Measure-Object).Count }
		}
	}
} else {
	Add-Line ("    (no cached checkout at {0})" -f $CoreCache)
}

Add-Section "4. Local dual-implementation runs (steps 7-9)"
Add-NewestRuns "build\dual-catalog" "*" 2 @("run.json", "summary.json", "dual-catalog.json")
Add-NewestRuns "build\dual-w3c" "*" 2 @("run.json", "summary.json", "dual-w3c.json")
Add-NewestRuns "build" "dual-ci-*" 2 @("run.json", "xpact-summary.json")
Add-Command "newest files in benchmarks\results" {
	Get-ChildItem -LiteralPath (Join-Path $RepoRoot "benchmarks\results") -File -ErrorAction SilentlyContinue |
		Sort-Object LastWriteTime -Descending | Select-Object -First 12 |
		ForEach-Object { "{0}  {1,10}  {2}" -f $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm"), $_.Length, $_.Name }
}

Add-Section "5. Jenkins (Jenkins run, #74, #79, #130, #131)"
Add-Line ("Jenkins home: {0}" -f $JenkinsHome)
$JobsDir = Join-Path $JenkinsHome "jobs"
if (-not (Test-Path -LiteralPath $JobsDir)) {
	Add-Line "    (not found; pass -JenkinsHome <dir> if Jenkins lives elsewhere)"
} else {
	$Jobs = @(Get-ChildItem -LiteralPath $JobsDir -Directory | Where-Object { $_.Name -match "xpact" })
	Add-Line ("xpact jobs: {0}" -f (($Jobs | ForEach-Object { $_.Name }) -join ", "))
	$KeyPattern = "\[Pipeline\] \{ \(|Finished:|smoke: ok|FAIL|Phase 1 tests|test matrix|Dual Implementation|run\.json|ISE_C_COMPILER|msc_vc140|Cannot find|HTTP 401|W3C|Exception|error"
	foreach ($Job in $Jobs) {
		$Builds = @(Get-ChildItem -LiteralPath (Join-Path $Job.FullName "builds") -Directory -ErrorAction SilentlyContinue |
			Where-Object { $_.Name -match "^\d+$" } | Sort-Object { [int] $_.Name } -Descending | Select-Object -First $MaxBuilds)
		foreach ($Build in $Builds) {
			Add-Line ""
			Add-Line ("### job {0}, build {1}" -f $Job.Name, $Build.Name)
			$BuildXml = Join-Path $Build.FullName "build.xml"
			if (Test-Path -LiteralPath $BuildXml) {
				$Xml = Get-Content -LiteralPath $BuildXml -Raw
				foreach ($Tag in @("result", "timestamp", "duration")) {
					$Match = [regex]::Match($Xml, "<$Tag>([^<]*)</$Tag>")
					if ($Match.Success) {
						$Value = $Match.Groups[1].Value
						if ($Tag -eq "timestamp") {
							$Value = ([DateTimeOffset]::FromUnixTimeMilliseconds([long] $Value)).ToLocalTime().ToString("yyyy-MM-dd HH:mm")
						}
						Add-Line ("{0}: {1}" -f $Tag, $Value)
					}
				}
				$Commit = [regex]::Match($Xml, "<sha1>([0-9a-f]{40})</sha1>")
				if ($Commit.Success) { Add-Line ("commit: {0}" -f $Commit.Groups[1].Value) }
			}
			$Log = Join-Path $Build.FullName "log"
			if (Test-Path -LiteralPath $Log) {
				$All = @(Get-Content -LiteralPath $Log -ErrorAction SilentlyContinue)
				Add-Line ("log lines: {0}" -f $All.Count)
				Add-Line "key lines (line number: text):"
				$Shown = 0
				for ($i = 0; $i -lt $All.Count -and $Shown -lt 400; $i++) {
					if ($All[$i] -match $KeyPattern) {
						$Text = $All[$i]
						if ($Text.Length -gt 300) { $Text = $Text.Substring(0, 300) + " ..." }
						Add-Line ("  {0}: {1}" -f ($i + 1), $Text)
						$Shown++
					}
				}
				Add-Line "last 40 lines:"
				foreach ($Line in ($All | Select-Object -Last 40)) { Add-Line ("  " + $Line) }
			}
			$Archive = Join-Path $Build.FullName "archive"
			if (Test-Path -LiteralPath $Archive) {
				foreach ($Name in @("run.json", "xpact-summary.json")) {
					foreach ($File in @(Get-ChildItem -LiteralPath $Archive -Recurse -File -Filter $Name -ErrorAction SilentlyContinue | Select-Object -First 2)) {
						Add-File $File.FullName 4000
					}
				}
			}
		}
	}
}

Add-Section "6. WSL (step 7)"
if (Get-Tool "wsl") {
	$Saved = [Console]::OutputEncoding
	try {
		[Console]::OutputEncoding = [System.Text.Encoding]::Unicode
		Add-Command "wsl -l -v" { wsl -l -v }
		$null = wsl -l -q 2>&1
		$HasDistribution = ($LASTEXITCODE -eq 0)
	} finally {
		[Console]::OutputEncoding = $Saved
	}
	if ($HasDistribution) {
		Add-Command "EiffelStudio in the default distribution" { wsl -e sh -lc "command -v ec || echo 'ec not on PATH'; uname -a" }
	} else {
		Add-Line "    (no WSL distribution; EiffelStudio check skipped)"
	}
} else {
	Add-Line "    (wsl not installed)"
}

Add-Section "7. Large XML corpora (step 7)"
if ($LargeXml.Count -eq 0) {
	Add-Line "    (none given; rerun with -LargeXml <file1>,<file2> to describe them)"
}
foreach ($File in $LargeXml) {
	if (Test-Path -LiteralPath $File -PathType Leaf) {
		$Item = Get-Item -LiteralPath $File
		$Hash = (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLower()
		Add-Line ("{0}  {1:N0} bytes  sha256 {2}" -f $Item.FullName, $Item.Length, $Hash)
	} else {
		Add-Line ("    (not found: {0})" -f $File)
	}
}
Add-NewestRuns "build\large-xml-benchmarks" "*" 1 @("*.json", "*.tsv")

if ($RunDualLanes) {
	Add-Section "8. Dual lanes run now (-RunDualLanes, step 9 baseline)"
	foreach ($Lane in @("run_dual_catalog.ps1", "run_dual_w3c.ps1")) {
		$Script = Join-Path $RepoRoot "scripts\$Lane"
		Add-Line ("--- {0} -Offline (started {1})" -f $Lane, (Get-Date -Format "HH:mm:ss"))
		$Text = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script -Offline 2>&1 | ForEach-Object {
			if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ }
		} | Out-String
		Add-Line ("    exit code: {0}" -f $LASTEXITCODE)
		foreach ($Line in (($Text.TrimEnd() -split "`r?`n") | Select-Object -Last 60)) { Add-Line ("    " + $Line) }
	}
	Add-NewestRuns "build\dual-catalog" "*" 1 @("run.json", "summary.json", "dual-catalog.json")
	Add-NewestRuns "build\dual-w3c" "*" 1 @("run.json", "summary.json", "dual-w3c.json")
}

Add-Section "End"
Add-Line ("Lines: {0}. Send this file to the student." -f ($Lines.Count + 1))

$Lines | Out-File -LiteralPath $Output -Encoding utf8
Write-Host ("Written: {0}" -f $Output)
