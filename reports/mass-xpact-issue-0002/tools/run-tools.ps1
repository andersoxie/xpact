[CmdletBinding()]
param(
	# Folder that holds xpact.dll (or xpact_assertions.dll) and its .lib.
	[Parameter(Mandatory = $true)] [string] $DllDir,
	# Where the results go.
	[Parameter(Mandatory = $true)] [string] $OutputDir,
	[ValidateSet("All", "Timing", "Trace", "Crc")]
	[string] $Run = "All",
	[string] $TimingChunks = "1,16,256,4096,0"
)
# Tools of mass-xpact issue #2. Builds them once into build\mass-xpact-0002-tools, then:
# - Timing: chunk_time on two generated documents (rich and plain), one row per chunk size.
# - Trace:  trace on the W3C files (< 2 KB byte by byte, < 8 KB in 7-byte pieces and whole),
#           three handler sets; compare two output folders with "diff -r" or their SHA-256.
# - Crc:    tests\native\xpact_chunked_crc.c, direct and buffer modes.
$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Repo = (Resolve-Path (Join-Path $Here "..\..\..")).Path
$Tools = Join-Path $Repo "build\mass-xpact-0002-tools"
$Python = "C:\Users\masou\AppData\Roaming\uv\python\cpython-3.15.0-windows-x86_64-none\python.exe"
New-Item -ItemType Directory -Force $Tools, $OutputDir | Out-Null
$DllDir = (Resolve-Path $DllDir).Path
$OutputDir = (Resolve-Path $OutputDir).Path
$Lib = Get-ChildItem $DllDir -Filter "xpact*.lib" | Select-Object -First 1
if ($null -eq $Lib) { throw "No xpact .lib in $DllDir" }

if (-not (Test-Path "$Tools\trace.exe") -or -not (Test-Path "$Tools\chunk_time.exe") -or -not (Test-Path "$Tools\xpact_chunked_crc.exe")) {
	$env:Path = "C:\Program Files (x86)\Microsoft Visual Studio\Installer;$env:Path"
	. (Join-Path $Repo "scripts\import_msvc_environment.ps1") | Out-Null
	Push-Location $Tools
	try {
		cl /nologo /O2 /I"$Repo\include" "$Here\chunk_time.c" $Lib.FullName /Fe:chunk_time.exe | Out-Null
		cl /nologo /O2 /I"$Repo\include" "$Here\trace.c" $Lib.FullName /Fe:trace.exe | Out-Null
		cl /nologo /O2 /I"$Repo\include" "$Repo\tests\native\xpact_chunked_crc.c" $Lib.FullName /Fe:xpact_chunked_crc.exe | Out-Null
	} finally {
		Pop-Location
	}
}
if (-not (Test-Path "$Tools\doc-rich.xml")) {
	& $Python -I "$Here\gen.py" "$Tools\doc.xml" 400
}
# The tools link to xpact.dll; an assertions folder holds xpact_assertions.dll instead.
if (-not (Test-Path (Join-Path $DllDir "xpact.dll"))) {
	$Alt = Join-Path $Tools "dll-copy"
	New-Item -ItemType Directory -Force $Alt | Out-Null
	Copy-Item (Get-ChildItem $DllDir -Filter "xpact*.dll" | Select-Object -First 1).FullName (Join-Path $Alt "xpact.dll") -Force
	$DllDir = $Alt
}
$env:Path = "$DllDir;$env:Path"

if ($Run -in "All", "Timing") {
	$Rows = @("document`tchunk`tstatus`terror`tstarts`tends`ttext_bytes`tchecksum`tms")
	foreach ($Doc in "doc-rich.xml", "doc-plain.xml") {
		foreach ($Chunk in $TimingChunks.Split(",")) {
			$Rows += "$Doc`t" + (& "$Tools\chunk_time.exe" "$Tools\$Doc" $Chunk 1)
		}
	}
	$Rows | Set-Content -Encoding utf8 (Join-Path $OutputDir "timing.tsv")
	$Rows
}
if ($Run -in "All", "Trace") {
	$Conf = Join-Path $Repo "xmlconf"
	Get-ChildItem $Conf -Recurse -Filter *.xml | Where-Object { $_.Length -lt 2048 } | Sort-Object FullName | ForEach-Object { $_.FullName } | Set-Content -Encoding ascii "$Tools\files-2k.txt"
	Get-ChildItem $Conf -Recurse -Filter *.xml | Where-Object { $_.Length -lt 8192 } | Sort-Object FullName | ForEach-Object { $_.FullName } | Set-Content -Encoding ascii "$Tools\files-8k.txt"
	$Runs = @(
		@("events", "1", "files-2k.txt"), @("events", "7", "files-8k.txt"), @("events", "100000", "files-8k.txt"),
		@("default", "1", "files-2k.txt"), @("default", "7", "files-8k.txt"),
		@("suspend", "1", "files-2k.txt"), @("suspend", "7", "files-8k.txt"),
		@("abort", "1", "files-2k.txt"), @("abort", "7", "files-8k.txt")
	)
	foreach ($R in $Runs) {
		cmd /c "`"$Tools\trace.exe`" $($R[0]) $($R[1]) < `"$Tools\$($R[2])`" > `"$OutputDir\trace-$($R[0])-$($R[1]).txt`" 2>&1"
	}
	Get-FileHash "$OutputDir\trace-*.txt" -Algorithm SHA256 | ForEach-Object { "$($_.Hash.ToLower())  $(Split-Path -Leaf $_.Path)" } | Set-Content -Encoding ascii (Join-Path $OutputDir "trace-sha256.txt")
}
if ($Run -in "All", "Crc") {
	$Rows = @()
	foreach ($Mode in "direct", "buffer") {
		$Rows += cmd /c "`"$Tools\xpact_chunked_crc.exe`" --mode $Mode --repeat 1 --chunk-sizes 1,2,3,4,5,7,8,16,31,64,127,1024,4096,whole 2>nul"
		foreach ($Doc in "doc-rich.xml", "doc-plain.xml") {
			$Rows += cmd /c "`"$Tools\xpact_chunked_crc.exe`" --mode $Mode --repeat 1 --file `"$Tools\$Doc`" --document-id $Doc --chunk-sizes 64,127,1024,4096,whole 2>nul"
		}
	}
	$Rows | Set-Content -Encoding utf8 (Join-Path $OutputDir "chunked-crc.tsv")
}
