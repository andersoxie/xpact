[CmdletBinding()]
param(
	[ValidateSet("Xpact", "LibexpatWsl", "All")]
	[string] $Target = "Xpact",
	[ValidateSet("Direct", "Buffer", "All")]
	[string] $ParseMode = "All",
	[string[]] $XmlFile = @(),
	[int] $Repeat = 100,
	[string] $ChunkSizes = "1,2,3,4,5,7,8,16,31,64,127,1024,4096,whole",
	[string] $OutputDir = "build\chunked-crc",
	[switch] $SkipBuild,
	[switch] $AllowMismatches
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($Repeat -le 0) {
	throw "Repeat must be positive."
}

$RepoRoot = Split-Path -Parent $PSScriptRoot
$OutputRoot = Join-Path $RepoRoot $OutputDir
$Source = Join-Path $RepoRoot "tests\native\xpact_chunked_crc.c"
$TsvPath = Join-Path $OutputRoot "chunked-crc-results.tsv"
$Rows = New-Object System.Collections.Generic.List[string]
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

function ConvertTo-WslPath {
	param(
		[string] $WindowsPath,
		[string] $WslExecutable
	)
	$Normalized = $WindowsPath -replace "\\", "/"
	(& $WslExecutable -- wslpath -a $Normalized | Out-String).Trim()
}

function ConvertTo-BashLiteral {
	param([string] $Value)
	"'" + ($Value -replace "'", "'\''") + "'"
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
	$Output = cmd.exe /c "`"$VcVars`" >nul && $Command" 2>&1
	if ($LASTEXITCODE -ne 0) {
		throw "Visual C++ command failed: $Command`n$($Output | Out-String)"
	}
	foreach ($Line in $Output) {
		Write-Host $Line
	}
}

function Get-ParseModes {
	if ($ParseMode -eq "All") {
		@("direct", "buffer")
	} else {
		@($ParseMode.ToLowerInvariant())
	}
}

function Get-DocumentArguments {
	param(
		[string] $Path,
		[string] $WslExecutable
	)
	if ([string]::IsNullOrWhiteSpace($Path)) {
		@("--repeat", "$Repeat")
	} elseif ([string]::IsNullOrWhiteSpace($WslExecutable)) {
		@("--file", $Path)
	} else {
		@("--file", (ConvertTo-WslPath $Path $WslExecutable))
	}
}

function Add-HarnessOutput {
	param([string[]] $Output)
	foreach ($Line in $Output) {
		if ([string]::IsNullOrWhiteSpace($Line)) {
			continue
		}
		if ($Line.StartsWith("engine`t") -and $Rows.Count -gt 0) {
			continue
		}
		$Rows.Add($Line)
	}
}

function Save-Rows {
	if ($Rows.Count -gt 0) {
		$Rows | Set-Content -LiteralPath $TsvPath -Encoding UTF8
		Write-Host "Chunked CRC rows written to $TsvPath"
	}
}

function Invoke-Harness {
	param(
		[string] $Executable,
		[string] $Engine,
		[string] $Mode,
		[string] $DocumentPath,
		[string] $PathPrefix
	)
	$Arguments = @("--engine", $Engine, "--mode", $Mode, "--chunk-sizes", $ChunkSizes)
	$Arguments += Get-DocumentArguments -Path $DocumentPath -WslExecutable ""
	$OldPath = $env:Path
	try {
		if (-not [string]::IsNullOrWhiteSpace($PathPrefix)) {
			$env:Path = "$PathPrefix;$OldPath"
		}
		$Output = & $Executable @Arguments
		$ExitCode = $LASTEXITCODE
		Add-HarnessOutput $Output
		if ($ExitCode -ne 0) {
			Save-Rows
			if ($AllowMismatches) {
				Write-Warning "$Engine chunked CRC harness reported mismatches with exit code $ExitCode."
			} else {
				throw "$Engine chunked CRC harness failed with exit code $ExitCode."
			}
		}
	} finally {
		$env:Path = $OldPath
	}
}

function Invoke-WslHarness {
	param(
		[string] $WslExecutable,
		[string] $Executable,
		[string] $Engine,
		[string] $Mode,
		[string] $DocumentPath
	)
	$Arguments = @("--engine", $Engine, "--mode", $Mode, "--chunk-sizes", $ChunkSizes)
	$Arguments += Get-DocumentArguments -Path $DocumentPath -WslExecutable $WslExecutable
	$CommandParts = New-Object System.Collections.Generic.List[string]
	$CommandParts.Add((ConvertTo-BashLiteral $Executable))
	foreach ($Argument in $Arguments) {
		$CommandParts.Add((ConvertTo-BashLiteral $Argument))
	}
	$Command = $CommandParts -join " "
	$Output = & $WslExecutable -- bash -lc $Command
	$ExitCode = $LASTEXITCODE
	Add-HarnessOutput $Output
	if ($ExitCode -ne 0) {
		Save-Rows
		if ($AllowMismatches) {
			Write-Warning "$Engine chunked CRC harness reported mismatches with exit code $ExitCode."
		} else {
			throw "$Engine chunked CRC harness failed with exit code $ExitCode."
		}
	}
}

function Build-XpactHarness {
	if (-not $SkipBuild) {
		$BuildOutput = & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "build_native_eiffel.ps1") -SkipSmoke 2>&1
		if ($LASTEXITCODE -ne 0) {
			throw "Eiffel-backed Windows DLL build failed.`n$($BuildOutput | Out-String)"
		}
		foreach ($Line in $BuildOutput) {
			Write-Host $Line
		}
	}
	$NativeRoot = Join-Path $RepoRoot "build\native-eiffel"
	$ImportLib = Join-Path $NativeRoot "xpact.lib"
	$Dll = Join-Path $NativeRoot "xpact.dll"
	if (-not (Test-Path -LiteralPath $ImportLib -PathType Leaf)) {
		throw "xpact import library not found: $ImportLib"
	}
	if (-not (Test-Path -LiteralPath $Dll -PathType Leaf)) {
		throw "xpact DLL not found: $Dll"
	}
	$Exe = Join-Path $OutputRoot "xpact_chunked_crc.exe"
	$ObjectFile = Join-Path $OutputRoot "xpact_chunked_crc.obj"
	$Command = "cl /nologo /W4 /WX /O2 /MT /I`"$RepoRoot\include`" /Fo`"$ObjectFile`" `"$Source`" `"$ImportLib`" /Fe`"$Exe`" /link /NOLOGO"
	Invoke-VcCommand $Command
	[pscustomobject]@{
		Exe = $Exe
		NativeRoot = $NativeRoot
	}
}

function Build-WslLibexpatHarness {
	$Wsl = Get-Command wsl.exe -ErrorAction Stop
	$Probe = & $Wsl.Source -- bash -lc "command -v gcc >/dev/null && printf available" 2>$null
	if ($LASTEXITCODE -ne 0 -or (($Probe | Out-String).Trim()) -ne "available") {
		throw "WSL gcc is not available."
	}
	$RepoRootWsl = ConvertTo-WslPath $RepoRoot $Wsl.Source
	$SourceWsl = ConvertTo-WslPath $Source $Wsl.Source
	$ExeWin = Join-Path $OutputRoot "libexpat_chunked_crc"
	$ExeWsl = ConvertTo-WslPath $ExeWin $Wsl.Source
	$CompileCommand = "cd $(ConvertTo-BashLiteral $RepoRootWsl) && gcc -Wall -Wextra -Werror -O2 -DXPACT_USE_SYSTEM_EXPAT $(ConvertTo-BashLiteral $SourceWsl) -lexpat -o $(ConvertTo-BashLiteral $ExeWsl)"
	$CompileOutput = & $Wsl.Source -- bash -lc $CompileCommand 2>&1
	if ($LASTEXITCODE -ne 0) {
		throw "WSL libexpat harness build failed.`n$($CompileOutput | Out-String)"
	}
	foreach ($Line in $CompileOutput) {
		Write-Host $Line
	}
	[pscustomobject]@{
		Wsl = $Wsl.Source
		Exe = $ExeWsl
	}
}

function Compare-SemanticRows {
	if ($Rows.Count -le 1) {
		return
	}
	$Objects = $Rows | ConvertFrom-Csv -Delimiter "`t"
	$Mismatches = New-Object System.Collections.Generic.List[string]
	$ComparableGroups = @($Objects | Group-Object mode, document, bytes, chunk_size | Where-Object { @($_.Group | Select-Object -ExpandProperty engine -Unique).Count -gt 1 })
	foreach ($Group in $ComparableGroups) {
		$Reference = $Group.Group[0]
		foreach ($Row in $Group.Group) {
			if ($Row.status -ne $Reference.status -or $Row.error_code -ne $Reference.error_code -or $Row.semantic_crc -ne $Reference.semantic_crc) {
				$Mismatches.Add("chunk comparison mismatch for $($Group.Name): $($Reference.engine)=$($Reference.status)/$($Reference.error_code)/$($Reference.semantic_crc), $($Row.engine)=$($Row.status)/$($Row.error_code)/$($Row.semantic_crc)")
			}
		}
	}
	if ($Mismatches.Count -gt 0) {
		foreach ($Mismatch in $Mismatches) {
			if ($AllowMismatches) {
				Write-Warning $Mismatch
			} else {
				Write-Error $Mismatch -ErrorAction Continue
			}
		}
		Save-Rows
		if (-not $AllowMismatches) {
			throw "Chunked CRC semantic comparison failed."
		}
	}
	if ($ComparableGroups.Count -gt 0) {
		Write-Host "Semantic CRC comparison passed for $($ComparableGroups.Count) shared chunk rows."
	}
}

$DocumentPaths = if ($XmlFile.Count -gt 0) { $XmlFile } else { @("") }
$Modes = Get-ParseModes

if ($Target -eq "Xpact" -or $Target -eq "All") {
	$Xpact = Build-XpactHarness
	foreach ($Mode in $Modes) {
		foreach ($DocumentPath in $DocumentPaths) {
			Invoke-Harness -Executable $Xpact.Exe -Engine "xpact" -Mode $Mode -DocumentPath $DocumentPath -PathPrefix $Xpact.NativeRoot
		}
	}
}

if ($Target -eq "LibexpatWsl" -or $Target -eq "All") {
	$Libexpat = Build-WslLibexpatHarness
	foreach ($Mode in $Modes) {
		foreach ($DocumentPath in $DocumentPaths) {
			Invoke-WslHarness -WslExecutable $Libexpat.Wsl -Executable $Libexpat.Exe -Engine "libexpat-wsl" -Mode $Mode -DocumentPath $DocumentPath
		}
	}
}

Compare-SemanticRows

Save-Rows
