[CmdletBinding()]
param(
	[string] $OutputDir = "build\contributed-examples",
	[switch] $SkipEiffelBuild,
	[switch] $RunWslExpatComparison
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$OutputRoot = Join-Path $RepoRoot $OutputDir
$ExampleRoot = Join-Path $RepoRoot "examples\contributed\xpact-incremental-example"
$LibraryRoot = Join-Path $RepoRoot "examples\contributed\xpact-incremental-library"
$CExampleRoot = Join-Path $RepoRoot "examples\contributed\c-expat-xml-tag-counter"

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

function Assert-PathExists {
	param(
		[string] $Path,
		[string] $Description
	)
	if (-not (Test-Path -LiteralPath $Path)) {
		throw "$Description not found: $Path"
	}
}

function Save-CommandOutput {
	param(
		[object[]] $Output,
		[string] $Path
	)
	$Output | Set-Content -LiteralPath $Path -Encoding UTF8
	foreach ($Line in $Output) {
		Write-Host $Line
	}
}

function Write-SkipLog {
	param(
		[string] $Message,
		[string] $LogName
	)
	Save-CommandOutput @($Message) (Join-Path $OutputRoot $LogName)
}

function Invoke-CapturedNativeCommand {
	param(
		[string] $Executable,
		[string[]] $Arguments
	)
	$PreviousErrorActionPreference = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try {
		$Output = & $Executable @Arguments 2>&1
		$ExitCode = $LASTEXITCODE
	} finally {
		$ErrorActionPreference = $PreviousErrorActionPreference
	}
	[pscustomobject]@{
		Output = $Output
		ExitCode = $ExitCode
	}
}

function Invoke-EcBuild {
	param([string] $LogName)
	$LogPath = Join-Path $OutputRoot $LogName
	$Arguments = @("-batch", "-clean", "-config", "xpact_example.ecf", "-target", "classic")
	Write-Host "== contributed xpact incremental example: Eiffel build =="
	Push-Location $ExampleRoot
	try {
		$Result = Invoke-CapturedNativeCommand -Executable "ec" -Arguments $Arguments
	} finally {
		Pop-Location
	}
	Save-CommandOutput $Result.Output $LogPath
	if ($Result.ExitCode -ne 0) {
		throw "Contributed xpact incremental example build failed with exit code $($Result.ExitCode). Log: $LogPath"
	}
}

function Invoke-FinishFreezingIfNeeded {
	param(
		[string] $CodeDir,
		[string] $LogName
	)
	if (-not (Test-Path -LiteralPath (Join-Path $CodeDir "Makefile.SH") -PathType Leaf)) {
		return
	}

	Write-Host "== contributed xpact incremental example: finish_freezing =="
	. (Join-Path $PSScriptRoot "import_msvc_environment.ps1")
	$LogPath = Join-Path $OutputRoot $LogName
	Push-Location $CodeDir
	try {
		$Result = Invoke-CapturedNativeCommand -Executable "finish_freezing" -Arguments @()
	} finally {
		Pop-Location
	}
	Save-CommandOutput $Result.Output $LogPath
	if ($Result.ExitCode -ne 0) {
		throw "Contributed xpact incremental example finish_freezing failed with exit code $($Result.ExitCode). Log: $LogPath"
	}
}

function Invoke-ExampleRun {
	param(
		[string] $Operation,
		[string] $XmlFile,
		[string] $LogName,
		[string[]] $ExpectedPatterns
	)
	$Exe = Join-Path $ExampleRoot "EIFGENs\classic\W_code\xpact_example.exe"
	if (-not (Test-Path -LiteralPath $Exe -PathType Leaf)) {
		throw "Contributed xpact example executable not found: $Exe"
	}
	$LogPath = Join-Path $OutputRoot $LogName
	Write-Host "== contributed xpact incremental example: $Operation $XmlFile =="
	$Result = Invoke-CapturedNativeCommand -Executable $Exe -Arguments @($Operation, $XmlFile)
	Save-CommandOutput $Result.Output $LogPath
	if ($Result.ExitCode -ne 0) {
		throw "Contributed xpact example run failed with exit code $($Result.ExitCode). Log: $LogPath"
	}
	$Text = ($Result.Output | Out-String)
	foreach ($Pattern in $ExpectedPatterns) {
		if ($Text -notmatch $Pattern) {
			throw "Contributed xpact example output did not match '$Pattern'. Log: $LogPath"
		}
	}
}

function ConvertTo-WslPath {
	param(
		[string] $WindowsPath,
		[string] $WslExecutable
	)
	$Normalized = $WindowsPath -replace "\\", "/"
	(& $WslExecutable -- wslpath -a $Normalized | Out-String).Trim()
}

function Invoke-WslExpatComparison {
	$Wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
	if ($null -eq $Wsl) {
		Write-SkipLog `
			-Message "Contributed C expat tag counter skipped: wsl.exe was not found." `
			-LogName "expat-tag-counter-skipped.log"
		return
	}

	$Probe = & $Wsl.Source -- bash -lc "command -v gcc >/dev/null && printf available" 2>$null
	if ($LASTEXITCODE -ne 0 -or (($Probe | Out-String).Trim()) -ne "available") {
		Write-SkipLog `
			-Message "Contributed C expat tag counter skipped: gcc was not visible in WSL." `
			-LogName "expat-tag-counter-skipped.log"
		return
	}

	$ExpatProbeCommand = 'tmp=$(mktemp /tmp/xpact-expat-probe.XXXXXX); printf "#include <expat.h>\nint main(void){return 0;}\n" | gcc -x c - -lexpat -o "$tmp" >/dev/null 2>&1; status=$?; rm -f "$tmp"; exit $status'
	& $Wsl.Source -- bash -lc $ExpatProbeCommand
	if ($LASTEXITCODE -ne 0) {
		Write-SkipLog `
			-Message "Contributed C expat tag counter skipped: WSL gcc could not compile and link a trivial expat program." `
			-LogName "expat-tag-counter-skipped.log"
		return
	}

	$SourceWsl = ConvertTo-WslPath (Join-Path $CExampleRoot "xmlcount_byfreq.c") $Wsl.Source
	$ExeWin = Join-Path $OutputRoot "xmlcount_byfreq"
	$ExeWsl = ConvertTo-WslPath $ExeWin $Wsl.Source
	$CompileLog = Join-Path $OutputRoot "expat-tag-counter-build.log"
	$CompileCommand = "gcc -O3 -fPIC -m64 -o '$ExeWsl' '$SourceWsl' -lexpat"
	Write-Host "== contributed C expat tag counter: WSL build =="
	$CompileResult = Invoke-CapturedNativeCommand -Executable $Wsl.Source -Arguments @("--", "bash", "-lc", $CompileCommand)
	Save-CommandOutput $CompileResult.Output $CompileLog
	if ($CompileResult.ExitCode -ne 0) {
		throw "Contributed C expat tag counter build failed with exit code $($CompileResult.ExitCode). Log: $CompileLog"
	}

	$XmlWsl = ConvertTo-WslPath (Join-Path $ExampleRoot "data\sample.xml") $Wsl.Source
	$RunLog = Join-Path $OutputRoot "expat-count-tags-sample.log"
	Write-Host "== contributed C expat tag counter: sample.xml =="
	$RunResult = Invoke-CapturedNativeCommand -Executable $Wsl.Source -Arguments @("--", "bash", "-lc", "'$ExeWsl' '$XmlWsl'")
	Save-CommandOutput $RunResult.Output $RunLog
	if ($RunResult.ExitCode -ne 0) {
		throw "Contributed C expat tag counter failed with exit code $($RunResult.ExitCode). Log: $RunLog"
	}
	$RunText = ($RunResult.Output | Out-String)
	foreach ($Pattern in @("TAG: <book> occurrences 2", "TAG: <title> occurrences 2", "TAG: <bookstore> occurrences 1")) {
		if ($RunText -notmatch $Pattern) {
			throw "Contributed C expat tag counter output did not match '$Pattern'. Log: $RunLog"
		}
	}
}

Assert-PathExists (Join-Path $ExampleRoot "xpact_example.ecf") "Contributed xpact example ECF"
Assert-PathExists (Join-Path $LibraryRoot "xpact-incremental.ecf") "Contributed xpact incremental library ECF"
Assert-PathExists (Join-Path $CExampleRoot "xmlcount_byfreq.c") "Contributed C expat tag counter source"

$OldXpactIncremental = $env:XPACT_INCREMENTAL
try {
	$env:XPACT_INCREMENTAL = $LibraryRoot
	if (-not $SkipEiffelBuild) {
		Invoke-EcBuild -LogName "xpact-incremental-example-build.log"
		Invoke-FinishFreezingIfNeeded `
			-CodeDir (Join-Path $ExampleRoot "EIFGENs\classic\W_code") `
			-LogName "xpact-incremental-example-finish-freezing.log"
	}
	Invoke-ExampleRun `
		-Operation "count_tags" `
		-XmlFile (Join-Path $ExampleRoot "data\sample.xml") `
		-LogName "xpact-count-tags-sample.log" `
		-ExpectedPatterns @("TAG: <book> occurrences 2", "TAG: <title> occurrences 2", "TAG: <bookstore> occurrences 1")
	Invoke-ExampleRun `
		-Operation "print" `
		-XmlFile (Join-Path $ExampleRoot "data\word-rdf.xml") `
		-LogName "xpact-print-word-rdf.log" `
		-ExpectedPatterns @("rdf:Description:", "CDATA:")
	if ($RunWslExpatComparison) {
		Invoke-WslExpatComparison
	} else {
		Write-Host "Contributed C expat tag counter WSL comparison skipped."
	}
} finally {
	if ($null -eq $OldXpactIncremental) {
		Remove-Item Env:\XPACT_INCREMENTAL -ErrorAction SilentlyContinue
	} else {
		$env:XPACT_INCREMENTAL = $OldXpactIncremental
	}
}

Write-Host "Contributed examples completed. Logs written to $OutputRoot"
