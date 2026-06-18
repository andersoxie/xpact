[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[string[]] $XmlFile,
	[int] $Iterations = 1,
	[int] $Repetitions = 3,
	[string] $OutputDir = "build\large-xml-benchmarks",
	[ValidateSet("Finalized", "Workbench")]
	[string] $EiffelBuild = "Finalized",
	[int64] $MaxFileBytes = 536870912,
	[switch] $SkipBuild,
	[switch] $SkipWslC,
	[switch] $SkipNativeXpactC,
	[switch] $NoPublishDocs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($Iterations -le 0) {
	throw "Iterations must be positive."
}
if ($Repetitions -le 0) {
	throw "Repetitions must be positive."
}
if ($MaxFileBytes -le 0) {
	throw "MaxFileBytes must be positive."
}

$RepoRoot = Split-Path -Parent $PSScriptRoot
$OutputRoot = Join-Path $RepoRoot $OutputDir
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

function Resolve-InputFile {
	param([string] $Path)
	$Resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
	$Info = Get-Item -LiteralPath $Resolved.Path
	if (-not $Info.Exists -or $Info.PSIsContainer) {
		throw "XML input is not a file: $Path"
	}
	if ($Info.Length -gt $MaxFileBytes) {
		throw "XML input exceeds the current whole-file benchmark limit ($MaxFileBytes bytes): $($Info.FullName)"
	}
	$Info
}

function Invoke-TimedCommand {
	param(
		[string] $CorpusId,
		[string] $FilePath,
		[int64] $FileBytes,
		[string] $Executable,
		[string[]] $Arguments,
		[string] $Engine,
		[string] $Version,
		[string] $Notes
	)
	$Rows = New-Object System.Collections.Generic.List[object]
	foreach ($Rep in 1..$Repetitions) {
		$Watch = [System.Diagnostics.Stopwatch]::StartNew()
		$Output = & $Executable @Arguments 2>&1
		$ExitCode = $LASTEXITCODE
		$Watch.Stop()
		if ($ExitCode -ne 0) {
			throw "$Engine failed for ${CorpusId} with exit code ${ExitCode}: $($Output | Out-String)"
		}
		$ElapsedSeconds = $Watch.Elapsed.TotalSeconds
		$Rows.Add([pscustomobject]@{
			CorpusId = $CorpusId
			FilePath = $FilePath
			FileBytes = $FileBytes
			Engine = $Engine
			Version = $Version
			Repetition = $Rep
			Iterations = $Iterations
			ElapsedMs = [math]::Round($Watch.Elapsed.TotalMilliseconds, 3)
			DocsPerSecond = [math]::Round($Iterations / $ElapsedSeconds, 6)
			MiBPerSecond = [math]::Round((($Iterations * $FileBytes) / 1MB) / $ElapsedSeconds, 3)
			Notes = $Notes
		})
	}
	,$Rows
}

function Get-MedianRow {
	param([object[]] $Rows)
	$Sorted = @($Rows | Sort-Object ElapsedMs)
	$Sorted[[int][math]::Floor(($Sorted.Count - 1) / 2)]
}

function Format-MarkdownRow {
	param([object] $Row)
	"| $($Row.CorpusId) | $($Row.Engine) | $($Row.Version) | $($Row.Iterations) | $($Row.FileBytes) | $($Row.ElapsedMs) | $($Row.DocsPerSecond) | $($Row.MiBPerSecond) | $($Row.Notes) |"
}

function ConvertTo-WslPath {
	param(
		[string] $WindowsPath,
		[string] $WslExecutable
	)
	$Normalized = $WindowsPath -replace "\\", "/"
	(& $WslExecutable -- wslpath -a $Normalized | Out-String).Trim()
}

function Get-VcVars {
	$VsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
	if (-not (Test-Path -LiteralPath $VsWhere -PathType Leaf)) {
		throw "vswhere.exe not found."
	}
	$VsRoot = (& $VsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Out-String).Trim()
	if ([string]::IsNullOrWhiteSpace($VsRoot)) {
		throw "Visual Studio C++ tools not found."
	}
	$VcVars = Join-Path $VsRoot "VC\Auxiliary\Build\vcvars64.bat"
	if (-not (Test-Path -LiteralPath $VcVars -PathType Leaf)) {
		throw "vcvars64.bat not found: $VcVars"
	}
	$VcVars
}

function Invoke-VcCommand {
	param([string] $Command)
	$VcVars = Get-VcVars
	cmd.exe /c "`"$VcVars`" >nul && $Command"
	if ($LASTEXITCODE -ne 0) {
		throw "Visual C++ command failed: $Command"
	}
}

function Add-Note {
	param([string] $Note)
	if (-not [string]::IsNullOrWhiteSpace($Note)) {
		$script:Notes.Add($Note)
	}
}

$InputFiles = @($XmlFile | ForEach-Object { Resolve-InputFile $_ })

if (-not $SkipBuild) {
	if ($EiffelBuild -eq "Finalized") {
		& ec -batch -finalize -config benchmarks\xpact_benchmarks.ecf -target xpact_benchmarks
		if ($LASTEXITCODE -ne 0) {
			throw "Finalized benchmark target generation failed."
		}
		$FinalCodeDir = Join-Path $RepoRoot "EIFGENs\xpact_benchmarks\F_code"
		. (Join-Path $PSScriptRoot "import_msvc_environment.ps1")
		Push-Location $FinalCodeDir
		try {
			& finish_freezing
			if ($LASTEXITCODE -ne 0) {
				throw "Finalized benchmark C compilation failed."
			}
		} finally {
			Pop-Location
		}
	} else {
		& ec -batch -config benchmarks\xpact_benchmarks.ecf -target xpact_benchmarks
		if ($LASTEXITCODE -ne 0) {
			throw "Workbench benchmark target compilation failed."
		}
	}
}

$XpactExe = if ($EiffelBuild -eq "Finalized") {
	Join-Path $RepoRoot "EIFGENs\xpact_benchmarks\F_code\xpact_benchmarks.exe"
} else {
	Join-Path $RepoRoot "EIFGENs\xpact_benchmarks\W_code\xpact_benchmarks.exe"
}
if (-not (Test-Path -LiteralPath $XpactExe -PathType Leaf)) {
	throw "xpact benchmark executable not found: $XpactExe"
}

$Rows = New-Object System.Collections.Generic.List[object]
$Notes = New-Object System.Collections.Generic.List[string]
$Python = (Get-Command python -ErrorAction Stop).Source
$PythonVersion = (& $Python --version 2>&1 | Out-String).Trim()
$PyExpatVersion = (& $Python (Join-Path $RepoRoot "benchmarks\libexpat_py_benchmark.py") --version 2>&1 | Out-String).Trim()
$XpactVersion = if ($EiffelBuild -eq "Finalized") { "Phase 1 finalized" } else { "Phase 1 workbench" }
$XpactEngine = if ($EiffelBuild -eq "Finalized") { "xpact Eiffel finalized, assertions discarded" } else { "xpact Eiffel workbench, contracts enabled" }

$WindowsNativeExe = $null
$WindowsNativeRoot = Join-Path $RepoRoot "build\native-eiffel"
if (-not $SkipNativeXpactC) {
	try {
		$WindowsNativeLib = Join-Path $WindowsNativeRoot "xpact.lib"
		$WindowsNativeDll = Join-Path $WindowsNativeRoot "xpact.dll"
		if (-not $SkipBuild) {
			& powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "build_native_eiffel.ps1") -SkipSmoke
			if ($LASTEXITCODE -ne 0) {
				throw "Eiffel-backed Windows DLL build failed."
			}
		}
		if (-not (Test-Path -LiteralPath $WindowsNativeLib -PathType Leaf)) {
			throw "Windows xpact import library not found: $WindowsNativeLib"
		}
		if (-not (Test-Path -LiteralPath $WindowsNativeDll -PathType Leaf)) {
			throw "Windows xpact DLL not found: $WindowsNativeDll"
		}
		$WindowsNativeExe = Join-Path $OutputRoot "xpact_native_windows_c_benchmark.exe"
		$WindowsNativeSource = Join-Path $RepoRoot "benchmarks\xpact_native_c_benchmark.c"
		$WindowsCompileCommand = "cl /nologo /O2 /MT /I`"$RepoRoot\include`" `"$WindowsNativeSource`" `"$WindowsNativeLib`" /Fe:`"$WindowsNativeExe`" /link /NOLOGO"
		Invoke-VcCommand $WindowsCompileCommand
	} catch {
		Add-Note "Windows xpact native C ABI large-file benchmark skipped: $($_.Exception.Message)"
		$WindowsNativeExe = $null
	}
}

$Wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
$WslLibexpatExe = $null
if (-not $SkipWslC -and $null -ne $Wsl) {
	$WslProbe = & $Wsl.Source -- bash -lc "command -v gcc >/dev/null && printf available" 2>$null
	if ($LASTEXITCODE -eq 0 -and (($WslProbe | Out-String).Trim()) -eq "available") {
		$RepoRootWsl = ConvertTo-WslPath $RepoRoot $Wsl.Source
		$SourceWsl = ConvertTo-WslPath (Join-Path $RepoRoot "benchmarks\libexpat_c_benchmark.c") $Wsl.Source
		$WslLibexpatExeWin = Join-Path $OutputRoot "libexpat_large_xml_c_benchmark"
		$WslLibexpatExe = ConvertTo-WslPath $WslLibexpatExeWin $Wsl.Source
		$CompileCommand = "cd '$RepoRootWsl' && gcc -O2 '$SourceWsl' -lexpat -o '$WslLibexpatExe'"
		& $Wsl.Source -- bash -lc $CompileCommand
		if ($LASTEXITCODE -ne 0) {
			Add-Note "WSL2 gcc was visible, but compiling the direct C libexpat large-file benchmark failed."
			$WslLibexpatExe = $null
		}
	} else {
		Add-Note "No direct C libexpat large-file benchmark was run: WSL2 gcc was not visible to this process."
	}
} elseif ($SkipWslC) {
	Add-Note "Direct C libexpat large-file benchmark skipped by -SkipWslC."
} else {
	Add-Note "No direct C libexpat large-file benchmark was run: wsl.exe was not on PATH."
}

foreach ($File in $InputFiles) {
	$CorpusId = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
	$Rows.AddRange((Invoke-TimedCommand `
		-CorpusId $CorpusId `
		-FilePath $File.FullName `
		-FileBytes $File.Length `
		-Executable $XpactExe `
		-Arguments @("--iterations", "$Iterations", "--file", $File.FullName) `
		-Engine $XpactEngine `
		-Version $XpactVersion `
		-Notes "Whole pre-decompressed XML file loaded into Eiffel STRING_8; no-op event handler"))
	$Rows.AddRange((Invoke-TimedCommand `
		-CorpusId $CorpusId `
		-FilePath $File.FullName `
		-FileBytes $File.Length `
		-Executable $XpactExe `
		-Arguments @("--iterations", "$Iterations", "--suspend-gc", "--file", $File.FullName) `
		-Engine "$XpactEngine, GC suspended during parse" `
		-Version $XpactVersion `
		-Notes "Whole pre-decompressed XML file loaded into Eiffel STRING_8; no-op event handler; calls parse_without_garbage_collection"))
	$Rows.AddRange((Invoke-TimedCommand `
		-CorpusId $CorpusId `
		-FilePath $File.FullName `
		-FileBytes $File.Length `
		-Executable $Python `
		-Arguments @((Join-Path $RepoRoot "benchmarks\libexpat_py_benchmark.py"), "--iterations", "$Iterations", "--mode", "tokenizer", "--file", $File.FullName) `
		-Engine "libexpat via CPython pyexpat tokenizer" `
		-Version $PyExpatVersion `
		-Notes "Whole pre-decompressed XML file loaded by Python; no callbacks"))
	$Rows.AddRange((Invoke-TimedCommand `
		-CorpusId $CorpusId `
		-FilePath $File.FullName `
		-FileBytes $File.Length `
		-Executable $Python `
		-Arguments @((Join-Path $RepoRoot "benchmarks\libexpat_py_benchmark.py"), "--iterations", "$Iterations", "--mode", "callbacks", "--file", $File.FullName) `
		-Engine "libexpat via CPython pyexpat callbacks" `
		-Version $PyExpatVersion `
		-Notes "Whole pre-decompressed XML file loaded by Python; Python callbacks"))
	if ($null -ne $WindowsNativeExe) {
		$OldPath = $env:Path
		try {
			$env:Path = "$WindowsNativeRoot;$OldPath"
			$WindowsNativeVersion = (& $WindowsNativeExe --version | Out-String).Trim()
			$Rows.AddRange((Invoke-TimedCommand `
				-CorpusId $CorpusId `
				-FilePath $File.FullName `
				-FileBytes $File.Length `
				-Executable $WindowsNativeExe `
				-Arguments @("--iterations", "$Iterations", "--mode", "tokenizer", "--file", $File.FullName) `
				-Engine "xpact native C ABI tokenizer via Windows MSVC DLL" `
				-Version $WindowsNativeVersion `
				-Notes "Whole pre-decompressed XML file loaded by C; linked through include/xpact.h and Eiffel-backed xpact.dll; no callbacks"))
			$Rows.AddRange((Invoke-TimedCommand `
				-CorpusId $CorpusId `
				-FilePath $File.FullName `
				-FileBytes $File.Length `
				-Executable $WindowsNativeExe `
				-Arguments @("--iterations", "$Iterations", "--mode", "callbacks", "--file", $File.FullName) `
				-Engine "xpact native C ABI callbacks via Windows MSVC DLL" `
				-Version $WindowsNativeVersion `
				-Notes "Whole pre-decompressed XML file loaded by C; linked through include/xpact.h and Eiffel-backed xpact.dll; C callbacks"))
		} finally {
			$env:Path = $OldPath
		}
	}
	if ($null -ne $WslLibexpatExe) {
		$FileWsl = ConvertTo-WslPath $File.FullName $Wsl.Source
		$CExpatVersion = (& $Wsl.Source -- $WslLibexpatExe --version | Out-String).Trim()
		$WslGccVersion = (& $Wsl.Source -- bash -lc "gcc --version | head -n 1" | Out-String).Trim()
		$Rows.AddRange((Invoke-TimedCommand `
			-CorpusId $CorpusId `
			-FilePath $File.FullName `
			-FileBytes $File.Length `
			-Executable $Wsl.Source `
			-Arguments @("--", $WslLibexpatExe, "--iterations", "$Iterations", "--mode", "tokenizer", "--file", $FileWsl) `
			-Engine "libexpat C tokenizer via WSL2 gcc" `
			-Version $CExpatVersion `
			-Notes "$WslGccVersion; whole pre-decompressed XML file loaded by C; no callbacks; launched through wsl.exe"))
		$Rows.AddRange((Invoke-TimedCommand `
			-CorpusId $CorpusId `
			-FilePath $File.FullName `
			-FileBytes $File.Length `
			-Executable $Wsl.Source `
			-Arguments @("--", $WslLibexpatExe, "--iterations", "$Iterations", "--mode", "callbacks", "--file", $FileWsl) `
			-Engine "libexpat C callbacks via WSL2 gcc" `
			-Version $CExpatVersion `
			-Notes "$WslGccVersion; whole pre-decompressed XML file loaded by C; C callbacks; launched through wsl.exe"))
	}
}

$TsvPath = Join-Path $OutputRoot "large-xml-benchmark-results.tsv"
$Rows | Export-Csv -LiteralPath $TsvPath -NoTypeInformation -Delimiter "`t" -Encoding UTF8

$MedianRows = @()
$Rows | Group-Object CorpusId, Engine | ForEach-Object {
	$MedianRows += Get-MedianRow $_.Group
}

$Machine = "Unknown"
try {
	$Cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
	$Os = Get-CimInstance Win32_OperatingSystem
	$Machine = "$($Cpu.Name); $([math]::Round($Os.TotalVisibleMemorySize / 1MB, 1)) GiB RAM; $($Os.Caption)"
} catch {
	$Machine = "$env:PROCESSOR_IDENTIFIER; $env:OS"
}

$MarkdownPath = Join-Path $RepoRoot "docs\large-xml-benchmarks.md"

if (-not $NoPublishDocs) {
	$Markdown = New-Object System.Collections.Generic.List[string]
	$Markdown.Add("# Large XML Benchmarks")
	$Markdown.Add("")
	$Markdown.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
	$Markdown.Add("")
	$Markdown.Add("Machine: $Machine")
	$Markdown.Add("")
	$Markdown.Add("Runtime context:")
	$Markdown.Add("")
	$Markdown.Add("- Inputs are real XML files supplied by the caller and must already be decompressed.")
	$Markdown.Add("- Current first slice is a whole-file benchmark: each engine loads the complete XML file before parsing.")
	$Markdown.Add("- Maximum accepted file size for this run: $MaxFileBytes bytes.")
	$Markdown.Add("- Eiffel target: ``benchmarks\xpact_benchmarks.ecf`` built as ``$EiffelBuild``.")
	$Markdown.Add("- Python: ``$PythonVersion``.")
	$Markdown.Add("- CPython pyexpat baseline: ``$PyExpatVersion``.")
	foreach ($Note in $Notes) {
		$Markdown.Add("- $Note")
	}
	$Markdown.Add("")
	$Markdown.Add("| Corpus | Engine | Version | Iterations | Bytes/doc | Median elapsed ms | Docs/sec | MiB/sec | Notes |")
	$Markdown.Add("|---|---|---:|---:|---:|---:|---:|---:|---|")
	foreach ($Row in $MedianRows) {
		$Markdown.Add((Format-MarkdownRow $Row))
	}
	$Markdown.Add("")
	$Markdown.Add("Raw run data is written to ``build\large-xml-benchmarks\large-xml-benchmark-results.tsv``.")
	$Markdown.Add("")
	$Markdown.Add("Interpretation: this is a macro-benchmark companion to ``docs\benchmarks.md``. It intentionally uses caller-supplied real XML corpora and does not include download or decompression time. Because the current Eiffel parser consumes a complete ``STRING_8``, these rows are not a substitute for the future Phase 2 byte-buffer streaming benchmark.")
	$Markdown | Set-Content -LiteralPath $MarkdownPath -Encoding UTF8
	Write-Host "Large XML benchmark medians written to $MarkdownPath"
} else {
	Write-Host "Large XML benchmark doc publication skipped by -NoPublishDocs"
}
Write-Host "Raw large XML benchmark rows written to $TsvPath"
foreach ($Row in $MedianRows) {
	Write-Host "$(Format-MarkdownRow $Row)"
}

# Jenkins' PowerShell wrapper can observe a stale native command exit code
# after successful nonfatal probes.
$global:LASTEXITCODE = 0
