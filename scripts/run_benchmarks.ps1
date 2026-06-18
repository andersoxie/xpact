[CmdletBinding()]
param(
	[int] $Iterations = 1000,
	[int] $Repetitions = 3,
	[string] $OutputDir = "build\benchmarks",
	[ValidateSet("Finalized", "FinalizedAssertions", "Workbench")]
	[string[]] $EiffelBuild = @("Finalized", "FinalizedAssertions"),
	[switch] $SkipBuild,
	[switch] $SkipWslC,
	[switch] $SkipNativeXpactC
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

function New-StatusRow {
	param(
		[string] $Name,
		[string] $Engine,
		[string] $Version,
		[int] $IterationCount,
		[int] $DocumentBytes,
		[string] $Notes
	)
	[pscustomobject]@{
		Benchmark = $Name
		Engine = $Engine
		Version = $Version
		Repetition = 1
		Iterations = $IterationCount
		DocumentBytes = $DocumentBytes
		ElapsedMs = "not measured"
		DocsPerSecond = "not measured"
		MiBPerSecond = "not measured"
		Notes = $Notes
	}
}

function Add-CompilerNote {
	param([string] $Note)
	if ([string]::IsNullOrWhiteSpace($script:CompilerNote)) {
		$script:CompilerNote = $Note
	} else {
		$script:CompilerNote = "$script:CompilerNote $Note"
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

function Get-EiffelBuildSpec {
	param([string] $Build)
	switch ($Build) {
		"Finalized" {
			[pscustomobject]@{
				Name = "Finalized"
				Target = "xpact_benchmarks"
				Mode = "Finalized"
				CodeDirectory = "F_code"
				Engine = "xpact Eiffel finalized, assertions discarded"
				Version = "Phase 1 finalized"
				Notes = "Parser object reused; no-op event handler; finalized Eiffel C compilation"
			}
		}
		"FinalizedAssertions" {
			[pscustomobject]@{
				Name = "FinalizedAssertions"
				Target = "xpact_benchmarks_assertions"
				Mode = "Finalized"
				CodeDirectory = "F_code"
				Engine = "xpact Eiffel finalized, assertions enabled"
				Version = "Phase 1 finalized assertions"
				Notes = "Parser object reused; no-op event handler; finalized Eiffel C compilation; runtime assertions enabled"
			}
		}
		"Workbench" {
			[pscustomobject]@{
				Name = "Workbench"
				Target = "xpact_benchmarks_assertions"
				Mode = "Workbench"
				CodeDirectory = "W_code"
				Engine = "xpact Eiffel workbench, assertions enabled"
				Version = "Phase 1 workbench"
				Notes = "Parser object reused; no-op event handler; runtime assertions enabled"
			}
		}
		default {
			throw "Unsupported Eiffel build type: $Build"
		}
	}
}

function Get-SelectedEiffelBuildSpecs {
	$Selected = New-Object System.Collections.Generic.List[object]
	$SelectedNames = New-Object System.Collections.Generic.List[string]
	foreach ($Build in $EiffelBuild) {
		if (-not $SelectedNames.Contains($Build)) {
			$Selected.Add((Get-EiffelBuildSpec $Build))
			$SelectedNames.Add($Build)
		}
	}
	$Selected
}

function Invoke-EiffelBenchmarkBuild {
	param([object] $BuildSpec)
	$ConfigPath = Join-Path $RepoRoot "benchmarks\xpact_benchmarks.ecf"
	$CompileArgs = @("-batch", "-clean")
	if ($BuildSpec.Mode -eq "Finalized") {
		$CompileArgs += "-finalize"
	}
	$CompileArgs += @("-config", $ConfigPath, "-target", $BuildSpec.Target)

	& ec @CompileArgs
	if ($LASTEXITCODE -ne 0) {
		throw "$($BuildSpec.Name) benchmark target generation failed."
	}

	$CodeDir = Join-Path $RepoRoot "EIFGENs\$($BuildSpec.Target)\$($BuildSpec.CodeDirectory)"
	if (Test-Path -LiteralPath (Join-Path $CodeDir "Makefile.SH") -PathType Leaf) {
		. (Join-Path $PSScriptRoot "import_msvc_environment.ps1")
		Push-Location $CodeDir
		try {
			& finish_freezing
			if ($LASTEXITCODE -ne 0) {
				throw "$($BuildSpec.Name) benchmark C compilation failed."
			}
		} finally {
			Pop-Location
		}
	}
}

$SelectedEiffelBuilds = Get-SelectedEiffelBuildSpecs

if (-not $SkipBuild) {
	foreach ($BuildSpec in $SelectedEiffelBuilds) {
		Invoke-EiffelBenchmarkBuild $BuildSpec
	}
}

$Python = (Get-Command python -ErrorAction Stop).Source
$PythonVersion = (& $Python --version 2>&1 | Out-String).Trim()
$ExpatVersion = (& $Python (Join-Path $RepoRoot "benchmarks\libexpat_py_benchmark.py") --version 2>&1 | Out-String).Trim()
$DocumentBytes = Get-SampleDocumentBytes

$AllRows = New-Object System.Collections.Generic.List[object]
foreach ($BuildSpec in $SelectedEiffelBuilds) {
	$XpactExe = Join-Path $RepoRoot "EIFGENs\$($BuildSpec.Target)\$($BuildSpec.CodeDirectory)\xpact_benchmarks.exe"
	if (-not (Test-Path -LiteralPath $XpactExe -PathType Leaf)) {
		throw "xpact benchmark executable not found: $XpactExe"
	}
	$AllRows.AddRange((Invoke-TimedCommand `
		-Name "catalog-100-items" `
		-Executable $XpactExe `
		-Arguments @("--iterations", "$Iterations") `
		-Engine $BuildSpec.Engine `
		-Version $BuildSpec.Version `
		-IterationCount $Iterations `
		-DocumentBytes $DocumentBytes `
		-Notes $BuildSpec.Notes))
	$AllRows.AddRange((Invoke-TimedCommand `
		-Name "catalog-100-items" `
		-Executable $XpactExe `
		-Arguments @("--iterations", "$Iterations", "--suspend-gc") `
		-Engine "$($BuildSpec.Engine), GC suspended during parse" `
		-Version $BuildSpec.Version `
		-IterationCount $Iterations `
		-DocumentBytes $DocumentBytes `
		-Notes "$($BuildSpec.Notes); calls parse_without_garbage_collection"))
}
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

$CompilerNote = $null
if (-not $SkipNativeXpactC) {
	try {
		$WindowsNativeRoot = Join-Path $RepoRoot "build\native-eiffel"
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
		$WindowsNativeSource = Join-Path $RepoRoot "benchmarks\xpact_native_c_benchmark.c"
		$WindowsNativeExe = Join-Path $OutputRoot "xpact_native_windows_c_benchmark.exe"
		$WindowsCompileCommand = "cl /nologo /O2 /MT /I`"$RepoRoot\include`" `"$WindowsNativeSource`" `"$WindowsNativeLib`" /Fe:`"$WindowsNativeExe`" /link /NOLOGO"
		Invoke-VcCommand $WindowsCompileCommand
		$OldPath = $env:Path
		try {
			$env:Path = "$WindowsNativeRoot;$OldPath"
			$WindowsNativeVersion = (& $WindowsNativeExe --version | Out-String).Trim()
			$AllRows.AddRange((Invoke-TimedCommand `
				-Name "catalog-100-items" `
				-Executable $WindowsNativeExe `
				-Arguments @("--iterations", "$Iterations", "--mode", "callbacks") `
				-Engine "xpact native C ABI callbacks via Windows MSVC DLL" `
				-Version $WindowsNativeVersion `
				-IterationCount $Iterations `
				-DocumentBytes $DocumentBytes `
				-Notes "MSVC x64; linked through include/xpact.h and build\native-eiffel\xpact.lib; calls Eiffel-backed xpact.dll; C callbacks"))
			$AllRows.AddRange((Invoke-TimedCommand `
				-Name "catalog-100-items" `
				-Executable $WindowsNativeExe `
				-Arguments @("--iterations", "$Iterations", "--mode", "tokenizer") `
				-Engine "xpact native C ABI tokenizer via Windows MSVC DLL" `
				-Version $WindowsNativeVersion `
				-IterationCount $Iterations `
				-DocumentBytes $DocumentBytes `
				-Notes "MSVC x64; linked through include/xpact.h and build\native-eiffel\xpact.lib; calls Eiffel-backed xpact.dll; no callbacks"))
			$AllRows.AddRange((Invoke-TimedCommand `
				-Name "catalog-100-items" `
				-Executable $WindowsNativeExe `
				-Arguments @("--iterations", "$Iterations", "--mode", "callbacks", "--reuse-parser") `
				-Engine "xpact native C ABI callbacks via Windows MSVC DLL, parser reused" `
				-Version $WindowsNativeVersion `
				-IterationCount $Iterations `
				-DocumentBytes $DocumentBytes `
				-Notes "MSVC x64; linked through include/xpact.h and build\native-eiffel\xpact.lib; calls Eiffel-backed xpact.dll; C callbacks; XML_ParserReset between documents"))
			$AllRows.AddRange((Invoke-TimedCommand `
				-Name "catalog-100-items" `
				-Executable $WindowsNativeExe `
				-Arguments @("--iterations", "$Iterations", "--mode", "tokenizer", "--reuse-parser") `
				-Engine "xpact native C ABI tokenizer via Windows MSVC DLL, parser reused" `
				-Version $WindowsNativeVersion `
				-IterationCount $Iterations `
				-DocumentBytes $DocumentBytes `
				-Notes "MSVC x64; linked through include/xpact.h and build\native-eiffel\xpact.lib; calls Eiffel-backed xpact.dll; no callbacks; XML_ParserReset between documents"))
		} finally {
			$env:Path = $OldPath
		}
	} catch {
		Add-CompilerNote "Windows xpact native C ABI benchmark skipped: $($_.Exception.Message)"
	}
}

$Wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $SkipWslC -and $null -ne $Wsl) {
	$WslProbe = & $Wsl.Source -- bash -lc "command -v gcc >/dev/null && printf available" 2>$null
	if ($LASTEXITCODE -eq 0 -and (($WslProbe | Out-String).Trim()) -eq "available") {
		$RepoRootWsl = ConvertTo-WslPath $RepoRoot $Wsl.Source
		$SourceWsl = ConvertTo-WslPath (Join-Path $RepoRoot "benchmarks\libexpat_c_benchmark.c") $Wsl.Source
		$ExeWin = Join-Path $OutputRoot "libexpat_c_benchmark"
		$ExeWsl = ConvertTo-WslPath $ExeWin $Wsl.Source
		$CompileCommand = "cd '$RepoRootWsl' && gcc -O2 '$SourceWsl' -lexpat -o '$ExeWsl'"
		& $Wsl.Source -- bash -lc $CompileCommand
		if ($LASTEXITCODE -eq 0) {
			$WslGccVersion = (& $Wsl.Source -- bash -lc "gcc --version | head -n 1" | Out-String).Trim()
			$CExpatVersion = (& $Wsl.Source -- $ExeWsl --version | Out-String).Trim()
			$AllRows.AddRange((Invoke-TimedCommand `
				-Name "catalog-100-items" `
				-Executable $Wsl.Source `
				-Arguments @("--", $ExeWsl, "--iterations", "$Iterations", "--mode", "callbacks") `
				-Engine "libexpat C callbacks via WSL2 gcc" `
				-Version $CExpatVersion `
				-IterationCount $Iterations `
				-DocumentBytes $DocumentBytes `
				-Notes "$WslGccVersion; parser created per document; C callbacks; launched through wsl.exe"))
			$AllRows.AddRange((Invoke-TimedCommand `
				-Name "catalog-100-items" `
				-Executable $Wsl.Source `
				-Arguments @("--", $ExeWsl, "--iterations", "$Iterations", "--mode", "tokenizer") `
				-Engine "libexpat C tokenizer via WSL2 gcc" `
				-Version $CExpatVersion `
				-IterationCount $Iterations `
				-DocumentBytes $DocumentBytes `
				-Notes "$WslGccVersion; parser created per document; no callbacks; launched through wsl.exe"))
		} else {
			Add-CompilerNote "WSL2 gcc was visible, but compiling the direct C libexpat benchmark failed."
		}

		if (-not $SkipNativeXpactC) {
			$NativeBuildOutput = & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "build_native.ps1") -Target Wsl 2>&1
			if ($LASTEXITCODE -eq 0) {
				$XpactNativeSourceWsl = ConvertTo-WslPath (Join-Path $RepoRoot "benchmarks\xpact_native_c_benchmark.c") $Wsl.Source
				$XpactNativeExeWin = Join-Path $OutputRoot "xpact_native_c_benchmark"
				$XpactNativeExeWsl = ConvertTo-WslPath $XpactNativeExeWin $Wsl.Source
				$XpactCompileCommand = "cd '$RepoRootWsl' && gcc -O2 -Iinclude '$XpactNativeSourceWsl' build/native/libxpact.so -o '$XpactNativeExeWsl'"
				& $Wsl.Source -- bash -lc $XpactCompileCommand
				if ($LASTEXITCODE -eq 0) {
					$XpactNativeVersion = (& $Wsl.Source -- bash -lc "cd '$RepoRootWsl' && LD_LIBRARY_PATH=build/native '$XpactNativeExeWsl' --version" | Out-String).Trim()
					$ProbeCommand = "cd '$RepoRootWsl' && LD_LIBRARY_PATH=build/native '$XpactNativeExeWsl' --iterations 1 --mode callbacks"
					$PreviousErrorActionPreference = $ErrorActionPreference
					$ErrorActionPreference = "Continue"
					try {
						$ProbeOutput = & $Wsl.Source -- bash -lc $ProbeCommand 2>&1
						$ProbeExitCode = $LASTEXITCODE
					} finally {
						$ErrorActionPreference = $PreviousErrorActionPreference
					}
					if ($ProbeExitCode -eq 77) {
						$AllRows.Add((New-StatusRow `
							-Name "catalog-100-items" `
							-Engine "xpact native C ABI via WSL2 gcc" `
							-Version $XpactNativeVersion `
							-IterationCount $Iterations `
							-DocumentBytes $DocumentBytes `
							-Notes "Compiled and linked through include/xpact.h; XML_Parse reports XML_ERROR_NOT_STARTED because the Eiffel bridge is not connected yet"))
					} elseif ($ProbeExitCode -eq 0) {
						$NativeRunCallbacks = "cd '$RepoRootWsl' && LD_LIBRARY_PATH=build/native '$XpactNativeExeWsl' --iterations $Iterations --mode callbacks"
						$NativeRunTokenizer = "cd '$RepoRootWsl' && LD_LIBRARY_PATH=build/native '$XpactNativeExeWsl' --iterations $Iterations --mode tokenizer"
						$AllRows.AddRange((Invoke-TimedCommand `
							-Name "catalog-100-items" `
							-Executable $Wsl.Source `
							-Arguments @("--", "bash", "-lc", $NativeRunCallbacks) `
							-Engine "xpact native C ABI callbacks via WSL2 gcc" `
							-Version $XpactNativeVersion `
							-IterationCount $Iterations `
							-DocumentBytes $DocumentBytes `
							-Notes "$WslGccVersion; parser created per document through include/xpact.h; C callbacks; launched through wsl.exe"))
						$AllRows.AddRange((Invoke-TimedCommand `
							-Name "catalog-100-items" `
							-Executable $Wsl.Source `
							-Arguments @("--", "bash", "-lc", $NativeRunTokenizer) `
							-Engine "xpact native C ABI tokenizer via WSL2 gcc" `
							-Version $XpactNativeVersion `
							-IterationCount $Iterations `
							-DocumentBytes $DocumentBytes `
							-Notes "$WslGccVersion; parser created per document through include/xpact.h; no callbacks; launched through wsl.exe"))
					} else {
						Add-CompilerNote "WSL xpact native C ABI benchmark compiled, but the probe failed: $(($ProbeOutput | Out-String).Trim())"
					}
				} else {
					Add-CompilerNote "WSL2 gcc was visible, but compiling the WSL xpact native C ABI benchmark failed."
				}
			} else {
				Add-CompilerNote "WSL xpact native C ABI benchmark skipped: WSL native build failed. $(($NativeBuildOutput | Out-String).Trim())"
			}
		}
	} else {
		Add-CompilerNote "No direct C libexpat benchmark was run: WSL2 gcc was not visible to this process."
		if (-not $SkipNativeXpactC) {
			Add-CompilerNote "No WSL xpact native C ABI benchmark was run: WSL2 gcc was not visible to this process."
		}
	}
} elseif ($SkipWslC) {
	Add-CompilerNote "Direct C libexpat benchmark skipped by -SkipWslC."
	if (-not $SkipNativeXpactC) {
		Add-CompilerNote "WSL xpact native C ABI benchmark skipped because WSL C benchmarks were skipped."
	}
} else {
	Add-CompilerNote "No direct C libexpat benchmark was run: wsl.exe was not on PATH."
	if (-not $SkipNativeXpactC) {
		Add-CompilerNote "No WSL xpact native C ABI benchmark was run: wsl.exe was not on PATH."
	}
}

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

$Markdown = New-Object System.Collections.Generic.List[string]
$SelectedEiffelBuildNames = ($SelectedEiffelBuilds | ForEach-Object { $_.Name }) -join ", "
$Markdown.Add("# Benchmarks")
$Markdown.Add("")
$Markdown.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
$Markdown.Add("")
$Markdown.Add("Machine: $Machine")
$Markdown.Add("")
$Markdown.Add("Runtime context:")
$Markdown.Add("")
$Markdown.Add("- Eiffel benchmark build types: ``$SelectedEiffelBuildNames``.")
$Markdown.Add("- Eiffel benchmark targets: ``xpact_benchmarks`` (assertions disabled) and ``xpact_benchmarks_assertions`` (assertions enabled).")
$Markdown.Add('- Eiffel void safety: ``support="all" use="all"``.')
$Markdown.Add("- Python: ``$PythonVersion``.")
$Markdown.Add("- libexpat baseline available on this machine through CPython ``pyexpat``: ``$ExpatVersion``.")
if ($null -ne $CompilerNote -and -not [string]::IsNullOrWhiteSpace($CompilerNote)) {
	$Markdown.Add("- $CompilerNote")
}
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
$Markdown.Add("Interpretation: the ``pyexpat`` rows are same-machine Expat baselines through CPython's binding. When present, WSL2 C rows compile and link against Ubuntu libexpat directly, but elapsed times are measured from Windows at the process level and include ``wsl.exe`` launch overhead, so they are conservative for libexpat core throughput.")
$Markdown.Add("")
$Markdown.Add("Native ABI note: the Windows ``xpact native C ABI`` rows are generated from a C executable linked against ``include/xpact.h`` and ``build\native-eiffel\xpact.lib`` and run against the Eiffel-backed ``build\native-eiffel\xpact.dll``. Any WSL ``xpact native C ABI`` status row still targets the older bridge-only ``build\native\libxpact.so`` path and remains ``not measured`` until the Linux/WSL Eiffel-backed shared object is packaged.")
$Markdown.Add("")
$Markdown.Add("See ``docs/performance-analysis.md`` for the current interpretation of the xpact-vs-libexpat performance gap and optimization priorities.")

$MarkdownPath = Join-Path $RepoRoot "docs\benchmarks.md"
$Markdown | Set-Content -LiteralPath $MarkdownPath -Encoding UTF8

Write-Host "Benchmark medians written to $MarkdownPath"
Write-Host "Raw benchmark rows written to $TsvPath"
foreach ($Row in $MedianRows) {
	Write-Host "$(Format-MarkdownRow $Row)"
}
