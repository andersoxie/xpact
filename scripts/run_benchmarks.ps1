[CmdletBinding()]
param(
	[int] $Iterations = 1000,
	[int] $Repetitions = 3,
	[string] $OutputDir = "build\benchmarks",
	[switch] $SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($Iterations -le 0) {
	throw "Iterations must be positive."
}
if ($Repetitions -le 0) {
	throw "Repetitions must be positive."
}

$RepoRoot = Split-Path -Parent $PSScriptRoot
$OutputRoot = Join-Path $RepoRoot $OutputDir
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

function Get-SampleDocumentBytes {
	$builder = [System.Text.StringBuilder]::new()
	[void] $builder.Append("<catalog>")
	foreach ($index in 1..100) {
		[void] $builder.Append("<item id=`"")
		[void] $builder.Append($index)
		[void] $builder.Append("`">value</item>")
	}
	[void] $builder.Append("</catalog>")
	[System.Text.Encoding]::UTF8.GetByteCount($builder.ToString())
}

function Invoke-TimedCommand {
	param(
		[string] $Name,
		[string] $Executable,
		[string[]] $Arguments,
		[string] $Engine,
		[string] $Version,
		[int] $IterationCount,
		[int] $DocumentBytes,
		[string] $Notes
	)
	$Rows = New-Object System.Collections.Generic.List[object]
	foreach ($rep in 1..$Repetitions) {
		$watch = [System.Diagnostics.Stopwatch]::StartNew()
		$output = & $Executable @Arguments 2>&1
		$exitCode = $LASTEXITCODE
		$watch.Stop()
		if ($exitCode -ne 0) {
			throw "$Name failed with exit code ${exitCode}: $($output | Out-String)"
		}
		$elapsedMs = $watch.Elapsed.TotalMilliseconds
		$elapsedSeconds = $watch.Elapsed.TotalSeconds
		$Rows.Add([pscustomobject]@{
			Benchmark = $Name
			Engine = $Engine
			Version = $Version
			Repetition = $rep
			Iterations = $IterationCount
			DocumentBytes = $DocumentBytes
			ElapsedMs = [math]::Round($elapsedMs, 3)
			DocsPerSecond = [math]::Round($IterationCount / $elapsedSeconds, 3)
			MiBPerSecond = [math]::Round((($IterationCount * $DocumentBytes) / 1MB) / $elapsedSeconds, 3)
			Notes = $Notes
		})
	}
	$Rows
}

function Get-MedianRow {
	param([object[]] $Rows)
	$sorted = @($Rows | Sort-Object ElapsedMs)
	$sorted[[int][math]::Floor(($sorted.Count - 1) / 2)]
}

function Format-MarkdownRow {
	param([object] $Row)
	"| $($Row.Benchmark) | $($Row.Engine) | $($Row.Version) | $($Row.Iterations) | $($Row.DocumentBytes) | $($Row.ElapsedMs) | $($Row.DocsPerSecond) | $($Row.MiBPerSecond) | $($Row.Notes) |"
}

if (-not $SkipBuild) {
	& ec -batch -config benchmarks\xpact_benchmarks.ecf -target xpact_benchmarks
	if ($LASTEXITCODE -ne 0) {
		throw "Benchmark target compilation failed."
	}
}

$XpactExe = Join-Path $RepoRoot "EIFGENs\xpact_benchmarks\W_code\xpact_benchmarks.exe"
if (-not (Test-Path -LiteralPath $XpactExe -PathType Leaf)) {
	throw "xpact benchmark executable not found: $XpactExe"
}

$Python = (Get-Command python -ErrorAction Stop).Source
$PythonVersion = (& $Python --version 2>&1 | Out-String).Trim()
$ExpatVersion = (& $Python (Join-Path $RepoRoot "benchmarks\libexpat_py_benchmark.py") --version 2>&1 | Out-String).Trim()
$DocumentBytes = Get-SampleDocumentBytes

$AllRows = New-Object System.Collections.Generic.List[object]
$AllRows.AddRange((Invoke-TimedCommand `
	-Name "catalog-100-items" `
	-Executable $XpactExe `
	-Arguments @("--iterations", "$Iterations") `
	-Engine "xpact Eiffel, contracts enabled" `
	-Version "Phase 1" `
	-IterationCount $Iterations `
	-DocumentBytes $DocumentBytes `
	-Notes "Parser object reused; no-op event handler"))
$AllRows.AddRange((Invoke-TimedCommand `
	-Name "catalog-100-items" `
	-Executable $Python `
	-Arguments @((Join-Path $RepoRoot "benchmarks\libexpat_py_benchmark.py"), "--iterations", "$Iterations", "--mode", "callbacks") `
	-Engine "libexpat via CPython pyexpat callbacks" `
	-Version $ExpatVersion `
	-IterationCount $Iterations `
	-DocumentBytes $DocumentBytes `
	-Notes "Parser created per document; Python callbacks"))
$AllRows.AddRange((Invoke-TimedCommand `
	-Name "catalog-100-items" `
	-Executable $Python `
	-Arguments @((Join-Path $RepoRoot "benchmarks\libexpat_py_benchmark.py"), "--iterations", "$Iterations", "--mode", "tokenizer") `
	-Engine "libexpat via CPython pyexpat tokenizer" `
	-Version $ExpatVersion `
	-IterationCount $Iterations `
	-DocumentBytes $DocumentBytes `
	-Notes "Parser created per document; no callbacks"))

$TsvPath = Join-Path $OutputRoot "benchmark-results.tsv"
$AllRows | Export-Csv -LiteralPath $TsvPath -NoTypeInformation -Delimiter "`t" -Encoding UTF8

$MedianRows = @()
$AllRows | Group-Object Engine | ForEach-Object {
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

$CompilerNote = "No direct C libexpat benchmark was run: cl, clang, gcc were not on PATH in this session."
$Markdown = New-Object System.Collections.Generic.List[string]
$Markdown.Add("# Benchmarks")
$Markdown.Add("")
$Markdown.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
$Markdown.Add("")
$Markdown.Add("Machine: $Machine")
$Markdown.Add("")
$Markdown.Add("Runtime context:")
$Markdown.Add("")
$Markdown.Add("- Eiffel target: ``benchmarks\xpact_benchmarks.ecf`` with assertions enabled.")
$Markdown.Add("- Python: ``$PythonVersion``.")
$Markdown.Add("- libexpat baseline available on this machine through CPython ``pyexpat``: ``$ExpatVersion``.")
$Markdown.Add("- $CompilerNote")
$Markdown.Add("")
$Markdown.Add("Workload: parse the same UTF-8 catalog document containing 100 ``<item>`` elements. Each table row reports the median of $Repetitions process-level runs.")
$Markdown.Add("")
$Markdown.Add("| Benchmark | Engine | Version | Iterations | Bytes/doc | Median elapsed ms | Docs/sec | MiB/sec | Notes |")
$Markdown.Add("|---|---|---:|---:|---:|---:|---:|---:|---|")
foreach ($Row in $MedianRows) {
	$Markdown.Add((Format-MarkdownRow $Row))
}
$Markdown.Add("")
$Markdown.Add("Raw run data is written to ``build\benchmarks\benchmark-results.tsv``.")
$Markdown.Add("")
$Markdown.Add("Interpretation: the libexpat rows are same-machine Expat baselines through CPython's binding, not a direct C executable. The callback row includes Python callback overhead; the tokenizer row shows the lower-overhead binding path available in this environment.")

$MarkdownPath = Join-Path $RepoRoot "docs\benchmarks.md"
$Markdown | Set-Content -LiteralPath $MarkdownPath -Encoding UTF8

Write-Host "Benchmark medians written to $MarkdownPath"
Write-Host "Raw benchmark rows written to $TsvPath"
foreach ($Row in $MedianRows) {
	Write-Host "$(Format-MarkdownRow $Row)"
}
